import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { randomUUID } from 'crypto';
import { S3Client, HeadObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { z } from 'zod';

const app = express();
app.disable('x-powered-by');

const {
  PORT = '3000',
  AWS_REGION = 'eu-central-1',
  S3_RAW_BUCKET,
  CDN_BASE_URL,
  PRESIGN_EXPIRES_SECONDS = '300',
  MAX_FILE_SIZE_BYTES = '15728640',
  UPLOAD_API_TOKEN = '',
  VERIFY_OBJECT_ON_COMPLETE = 'false',
  UPLOAD_RATE_LIMIT_WINDOW_MS = '60000',
  UPLOAD_RATE_LIMIT_MAX = '30',
  CORS_ORIGINS = '',
  AI_PROVIDER = 'openai',
  AI_MODEL = 'gpt-4o-mini',
  OPENAI_API_KEY = '',
  ANTHROPIC_API_KEY = '',
  AI_TIMEOUT_MS = '20000',
} = process.env;

function buildCorsOrigins() {
  const raw = String(CORS_ORIGINS || '').trim();
  if (!raw) return null; // allow all (dev)
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

const corsOrigins = buildCorsOrigins();
app.use(
  cors({
    origin: corsOrigins ?? true,
    credentials: false,
    maxAge: 86400,
  }),
);
app.use(express.json({ limit: '1mb' }));

app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const end = process.hrtime.bigint();
    const ms = Number(end - start) / 1e6;
    // eslint-disable-next-line no-console
    console.log(
      JSON.stringify({
        ts: new Date().toISOString(),
        requestId: req.requestId,
        method: req.method,
        path: req.originalUrl,
        status: res.statusCode,
        latency_ms: Math.round(ms * 100) / 100,
      }),
    );
  });
  next();
});

if (!S3_RAW_BUCKET || !CDN_BASE_URL) {
  // eslint-disable-next-line no-console
  console.warn('S3_RAW_BUCKET veya CDN_BASE_URL eksik. .env dosyasını kontrol edin.');
}

const s3 = new S3Client({ region: AWS_REGION });
const ALLOWED_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
]);
const ALLOWED_FOLDERS = new Set(['products']);

const uploadLimiter = rateLimit({
  windowMs: Number(UPLOAD_RATE_LIMIT_WINDOW_MS),
  max: Number(UPLOAD_RATE_LIMIT_MAX),
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Çok fazla upload isteği. Lütfen kısa süre sonra tekrar deneyin.',
  },
});

const aiLimiter = rateLimit({
  windowMs: 60_000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Çok fazla istek. Lütfen kısa süre sonra tekrar deneyin.',
  },
});

function requireUploadAuth(req, res, next) {
  if (!UPLOAD_API_TOKEN) return next();
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  if (token !== UPLOAD_API_TOKEN) {
    return res.status(401).json({ success: false, message: 'Unauthorized' });
  }
  return next();
}

function withRequestId(req, res, next) {
  const existing = String(req.headers['x-request-id'] || '').trim();
  const id = existing || randomUUID();
  req.requestId = id;
  res.setHeader('x-request-id', id);
  return next();
}

app.use(withRequestId);

app.use((req, res, next) => {
  res.setHeader('x-content-type-options', 'nosniff');
  res.setHeader('referrer-policy', 'no-referrer');
  res.setHeader('cross-origin-resource-policy', 'same-site');
  res.setHeader('cross-origin-opener-policy', 'same-origin');
  res.setHeader('cross-origin-embedder-policy', 'require-corp');
  res.setHeader('x-frame-options', 'DENY');
  res.setHeader(
    'content-security-policy',
    "default-src 'none'; frame-ancestors 'none'; base-uri 'none'",
  );
  next();
});

function currentYearMonth() {
  const now = new Date();
  const yyyy = now.getUTCFullYear();
  const mm = String(now.getUTCMonth() + 1).padStart(2, '0');
  return { yyyy, mm };
}

function fileExt(fileName) {
  const parts = String(fileName || '').split('.');
  return parts.length > 1 ? parts.pop().toLowerCase() : 'jpg';
}

function extFromContentType(contentType) {
  switch (String(contentType || '').toLowerCase()) {
    case 'image/jpeg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    case 'image/heic':
      return 'heic';
    default:
      return null;
  }
}

function sanitizeFolder(folder) {
  const raw = String(folder || '').trim().toLowerCase();
  return ALLOWED_FOLDERS.has(raw) ? raw : null;
}

function isValidRawKey(key, expectedFolder) {
  const raw = String(key || '').trim();
  if (!raw) return false;
  const pattern = new RegExp(
    `^${expectedFolder}/raw/\\d{4}/\\d{2}/[a-f0-9-]{36}\\.(jpg|jpeg|png|webp|heic)$`,
    'i',
  );
  return pattern.test(raw);
}

function toProcessedKey(rawKey, variant, ext = 'webp') {
  const replaced = rawKey.replace('/raw/', `/${variant}/`);
  return `${replaced.replace(/\.[^.]+$/, '')}.${ext}`;
}

app.get('/health', (_, res) => {
  res.json({
    ok: true,
    time: new Date().toISOString(),
    config: {
      region: AWS_REGION,
      hasS3Bucket: Boolean(S3_RAW_BUCKET),
      hasCdnBaseUrl: Boolean(CDN_BASE_URL),
      presignExpiresSeconds: Number(PRESIGN_EXPIRES_SECONDS),
      maxFileSizeBytes: Number(MAX_FILE_SIZE_BYTES),
      verifyObjectOnComplete: String(VERIFY_OBJECT_ON_COMPLETE).toLowerCase() === 'true',
      rateLimit: {
        windowMs: Number(UPLOAD_RATE_LIMIT_WINDOW_MS),
        max: Number(UPLOAD_RATE_LIMIT_MAX),
      },
      cors: {
        allowAll: corsOrigins == null,
        origins: corsOrigins ?? [],
      },
      authEnabled: Boolean(UPLOAD_API_TOKEN),
      ai: {
        provider: AI_PROVIDER,
        model: AI_MODEL,
        enabled: Boolean((AI_PROVIDER === 'openai' && OPENAI_API_KEY) || (AI_PROVIDER === 'anthropic' && ANTHROPIC_API_KEY)),
      },
    },
  });
});

const ChatRequestSchema = z.object({
  message: z.string().trim().min(1).max(1500),
  history: z
    .array(
      z.object({
        role: z.enum(['user', 'assistant', 'system']).default('user'),
        text: z.string().max(4000).default(''),
      }),
    )
    .max(30)
    .default([]),
});

const SupportChatSchema = ChatRequestSchema.extend({
  orderNo: z.string().trim().max(64).optional(),
});

const StylistChatSchema = ChatRequestSchema.extend({
  occasion: z.string().trim().max(64).optional(),
  weather: z.string().trim().max(64).optional(),
});

function normalizeHistory(history) {
  const safe = [];
  for (const item of history || []) {
    const role = item?.role === 'assistant' || item?.role === 'system' ? item.role : 'user';
    const text = String(item?.text || '').trim();
    if (!text) continue;
    safe.push({ role, text: text.slice(0, 4000) });
  }
  return safe.slice(-30);
}

function suggestionsFromReply(reply) {
  // Lightweight heuristics (keep Flutter UI populated).
  const base = [
    'Bir örnek daha sorabilir miyim?',
    'Bunu adım adım anlatır mısın?',
    'Alternatif çözüm öner',
    'Özetle ve aksiyon listesi çıkar',
  ];
  if (!reply || reply.length < 10) return base;
  return base;
}

async function callOpenAI({ system, messages, timeoutMs }) {
  if (!OPENAI_API_KEY) throw new Error('OPENAI_API_KEY_missing');
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: AI_MODEL,
        temperature: 0.6,
        messages: [
          { role: 'system', content: system },
          ...messages.map((m) => ({ role: m.role, content: m.text })),
        ],
      }),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new Error(`openai_error_${res.status}:${text.slice(0, 300)}`);
    }
    const data = await res.json();
    const reply = data?.choices?.[0]?.message?.content ?? '';
    return String(reply).trim();
  } finally {
    clearTimeout(t);
  }
}

async function callAnthropic({ system, messages, timeoutMs }) {
  if (!ANTHROPIC_API_KEY) throw new Error('ANTHROPIC_API_KEY_missing');
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: AI_MODEL,
        max_tokens: 600,
        temperature: 0.6,
        system,
        messages: messages
          .filter((m) => m.role !== 'system')
          .map((m) => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.text })),
      }),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new Error(`anthropic_error_${res.status}:${text.slice(0, 300)}`);
    }
    const data = await res.json();
    const parts = data?.content ?? [];
    const text = Array.isArray(parts)
      ? parts.filter((p) => p?.type === 'text').map((p) => p.text).join('\n')
      : '';
    return String(text).trim();
  } finally {
    clearTimeout(t);
  }
}

async function callAI({ system, messages, timeoutMs }) {
  const provider = String(AI_PROVIDER || 'openai').toLowerCase();
  if (provider === 'anthropic') {
    return await callAnthropic({ system, messages, timeoutMs });
  }
  return await callOpenAI({ system, messages, timeoutMs });
}

app.post('/api/support/chat', requireUploadAuth, aiLimiter, async (req, res) => {
  try {
    const parsed = SupportChatSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ success: false, message: 'Geçersiz istek', requestId: req.requestId });
    }
    const { message, history, orderNo } = parsed.data;
    const normalizedHistory = normalizeHistory(history);
    const system = [
      'Sen Vitrin uygulamasının Türkçe müşteri destek asistanısın.',
      'Kısa, net ve çözüm odaklı cevap ver.',
      'Gizli bilgi isteme (kart, şifre, SMS kodu).',
      'Eğer bilgi eksikse en fazla 2 net soru sor.',
      orderNo ? `Sipariş No: ${orderNo}` : null,
    ]
      .filter(Boolean)
      .join('\n');

    const reply = await callAI({
      system,
      messages: [...normalizedHistory, { role: 'user', text: message }],
      timeoutMs: Number(AI_TIMEOUT_MS) || 20000,
    });

    return res.json({
      success: true,
      reply: reply || 'Şu an yanıt üretilemedi. Lütfen tekrar deneyin.',
      suggestions: suggestionsFromReply(reply),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'AI yanıtı alınamadı',
      requestId: req.requestId,
      error: error?.message || 'unknown_error',
    });
  }
});

app.post('/api/stylist/chat', requireUploadAuth, aiLimiter, async (req, res) => {
  try {
    const parsed = StylistChatSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ success: false, message: 'Geçersiz istek', requestId: req.requestId });
    }
    const { message, history, occasion, weather } = parsed.data;
    const normalizedHistory = normalizeHistory(history);
    const system = [
      'Sen Vitrin uygulamasının Türkçe AI stil asistanısın.',
      'Kısa, uygulanabilir kombin önerileri ver.',
      '2-4 alternatif üret; her birinde üst/alt/ayakkabı/aksesuar öner.',
      'Eğer bilgi eksikse 1-2 soru sor.',
      occasion ? `Ortam: ${occasion}` : null,
      weather ? `Hava: ${weather}` : null,
    ]
      .filter(Boolean)
      .join('\n');

    const reply = await callAI({
      system,
      messages: [...normalizedHistory, { role: 'user', text: message }],
      timeoutMs: Number(AI_TIMEOUT_MS) || 20000,
    });

    return res.json({
      success: true,
      reply: reply || 'Şu an yanıt üretilemedi. Lütfen tekrar deneyin.',
      suggestions: suggestionsFromReply(reply),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'AI yanıtı alınamadı',
      requestId: req.requestId,
      error: error?.message || 'unknown_error',
    });
  }
});

app.post('/api/uploads/presign', requireUploadAuth, uploadLimiter, async (req, res) => {
  try {
    const { fileName, contentType, fileSize, folder = 'products' } = req.body || {};
    const safeFolder = sanitizeFolder(folder);

    if (!fileName || !contentType || !fileSize) {
      return res.status(400).json({
        success: false,
        message: 'fileName, contentType ve fileSize zorunlu',
      });
    }

    if (!safeFolder) {
      return res.status(400).json({ success: false, message: 'folder geçersiz' });
    }

    if (typeof fileName !== 'string' || fileName.length > 255) {
      return res.status(400).json({ success: false, message: 'fileName geçersiz' });
    }

    if (!Number.isFinite(Number(fileSize)) || Number(fileSize) <= 0) {
      return res.status(400).json({ success: false, message: 'fileSize geçersiz' });
    }

    if (!ALLOWED_TYPES.has(String(contentType).toLowerCase())) {
      return res.status(400).json({ success: false, message: 'contentType geçersiz' });
    }

    if (Number(fileSize) > Number(MAX_FILE_SIZE_BYTES)) {
      return res.status(413).json({ success: false, message: 'Dosya boyutu limiti aşıldı' });
    }

    if (!S3_RAW_BUCKET) {
      return res.status(500).json({ success: false, message: 'S3_RAW_BUCKET tanımlı değil' });
    }

    const { yyyy, mm } = currentYearMonth();
    const ext = extFromContentType(contentType) || fileExt(fileName);
    const key = `${safeFolder}/raw/${yyyy}/${mm}/${randomUUID()}.${ext}`;

    const command = new PutObjectCommand({
      Bucket: S3_RAW_BUCKET,
      Key: key,
      ContentType: contentType,
      CacheControl: 'private, max-age=0, no-cache',
    });

    const uploadUrl = await getSignedUrl(s3, command, {
      expiresIn: Number(PRESIGN_EXPIRES_SECONDS),
    });

    return res.json({
      success: true,
      uploadUrl,
      key,
      headers: { 'Content-Type': contentType },
      cdnBaseUrl: CDN_BASE_URL,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Presign başarısız',
      requestId: req.requestId,
      error: error?.message || 'unknown_error',
    });
  }
});

app.post('/api/uploads/complete', requireUploadAuth, uploadLimiter, async (req, res) => {
  try {
    const { key, folder = 'products' } = req.body || {};
    const safeFolder = sanitizeFolder(folder);
    if (!safeFolder) {
      return res.status(400).json({ success: false, message: 'folder geçersiz' });
    }

    if (!isValidRawKey(key, safeFolder)) {
      return res.status(400).json({ success: false, message: 'Geçerli key zorunlu' });
    }

    if (!CDN_BASE_URL) {
      return res.status(500).json({ success: false, message: 'CDN_BASE_URL tanımlı değil' });
    }

    if (String(VERIFY_OBJECT_ON_COMPLETE).toLowerCase() === 'true') {
      if (!S3_RAW_BUCKET) {
        return res.status(500).json({ success: false, message: 'S3_RAW_BUCKET tanımlı değil' });
      }
      await s3.send(new HeadObjectCommand({ Bucket: S3_RAW_BUCKET, Key: key }));
    }

    const cleanBase = CDN_BASE_URL.replace(/\/$/, '');
    const imageVariants = {
      small: `${cleanBase}/${toProcessedKey(key, 'small')}`,
      medium: `${cleanBase}/${toProcessedKey(key, 'medium')}`,
      large: `${cleanBase}/${toProcessedKey(key, 'large')}`,
      original: `${cleanBase}/${toProcessedKey(key, 'original', fileExt(key))}`,
    };

    return res.json({
      success: true,
      key,
      folder: safeFolder,
      imageUrl: imageVariants.medium,
      imageVariants,
      image_status: 'processing',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Upload complete başarısız',
      requestId: req.requestId,
      error: error?.message || 'unknown_error',
    });
  }
});

app.post('/api/products/mock-response', (req, res) => {
  const base = (CDN_BASE_URL || 'https://cdn.example.com').replace(/\/$/, '');
  return res.json({
    success: true,
    product: {
      id: 1,
      title: 'Örnek Ürün',
      image_url: `${base}/products/medium/2026/05/example.webp`,
      image_variants: {
        small: `${base}/products/small/2026/05/example.webp`,
        medium: `${base}/products/medium/2026/05/example.webp`,
        large: `${base}/products/large/2026/05/example.webp`,
        original: `${base}/products/original/2026/05/example.jpg`,
      },
      imageVariants: {
        small: `${base}/products/small/2026/05/example.webp`,
        medium: `${base}/products/medium/2026/05/example.webp`,
        large: `${base}/products/large/2026/05/example.webp`,
        original: `${base}/products/original/2026/05/example.jpg`,
      },
      image_status: 'ready',
    },
  });
});

app.use((_, res) => res.status(404).json({ success: false, message: 'Not Found' }));

app.listen(Number(PORT), () => {
  // eslint-disable-next-line no-console
  console.log(`Upload API ready on :${PORT} (cors=${corsOrigins ? 'restricted' : 'any'})`);
});
