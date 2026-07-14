import fs from 'fs';
import path from 'path';
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND_DIR = path.resolve(__dirname, '..');
const ROOT_DIR = path.resolve(BACKEND_DIR, '..');

function argValue(name, fallback = '') {
  const prefix = `--${name}=`;
  const hit = process.argv.find((a) => a.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

const mode = (argValue('mode', 'local') || 'local').toLowerCase();
const port = Number.parseInt(argValue('port', '4110'), 10);
const runId = Date.now();
const localDataDir = path.join(BACKEND_DIR, 'data', `smoke-${runId}`);

let baseUrl = process.env.API_BASE_URL || `http://127.0.0.1:${port}/api`;
let serverProc = null;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function check(ok, label, details = '') {
  if (ok) {
    console.log(`✅ ${label}${details ? ` - ${details}` : ''}`);
    return;
  }
  throw new Error(`❌ ${label}${details ? ` - ${details}` : ''}`);
}

async function requestJson(method, url, { token, body, headers = {} } = {}) {
  const finalHeaders = {
    'Content-Type': 'application/json',
    ...headers,
  };
  if (token) finalHeaders.Authorization = `Bearer ${token}`;

  const response = await fetch(url, {
    method,
    headers: finalHeaders,
    body: body == null ? undefined : JSON.stringify(body),
  });

  const text = await response.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }

  return { status: response.status, json, text };
}

async function waitForHealth(url, timeoutMs = 15_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url);
      if (res.ok) return true;
    } catch {
      // retry
    }
    await sleep(350);
  }
  return false;
}

function startLocalServer() {
  fs.mkdirSync(localDataDir, { recursive: true });
  const outLog = path.join(ROOT_DIR, 'backend_smoke_server.log');
  const errLog = path.join(ROOT_DIR, 'backend_smoke_server.err.log');
  const out = fs.openSync(outLog, 'a');
  const err = fs.openSync(errLog, 'a');

  serverProc = spawn('node', ['src/server.js'], {
    cwd: BACKEND_DIR,
    env: {
      ...process.env,
      PORT: String(port),
      AWS_REGION: process.env.AWS_REGION || 'eu-central-1',
      S3_RAW_BUCKET: process.env.S3_RAW_BUCKET || 'test-bucket',
      CDN_BASE_URL: process.env.CDN_BASE_URL || 'https://cdn.example.test',
      UPLOAD_API_TOKEN: process.env.UPLOAD_API_TOKEN || 'smoketest',
      VERIFY_OBJECT_ON_COMPLETE: 'false',
      DATA_DIR: localDataDir,
      AUTH_SALT: process.env.AUTH_SALT || 'smoke-salt',
      AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID || 'smoke',
      AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY || 'smoke',
    },
    stdio: ['ignore', out, err],
  });
}

async function runFlow() {
  const healthUrl = baseUrl.replace(/\/api\/?$/, '/health');
  const healthReady = await waitForHealth(healthUrl);
  check(healthReady, 'Health endpoint hazır', healthUrl);

  const uniq = `${Date.now()}_${Math.floor(Math.random() * 10000)}`;
  const marker = `smoke_${uniq}`;
  const sellerEmail = `seller_${uniq}@example.com`;
  const buyerEmail = `buyer_${uniq}@example.com`;
  const password = '123456';

  // 1) Auth akışı
  const regSeller = await requestJson('POST', `${baseUrl}/register`, {
    body: { email: sellerEmail, password },
  });
  check(regSeller.status === 200 && regSeller.json?.success === true, 'Seller register');

  const regBuyer = await requestJson('POST', `${baseUrl}/register`, {
    body: { email: buyerEmail, password },
  });
  check(regBuyer.status === 200 && regBuyer.json?.success === true, 'Buyer register');

  const loginSeller = await requestJson('POST', `${baseUrl}/login`, {
    body: { email: sellerEmail, password },
  });
  const sellerToken = loginSeller.json?.token;
  check(loginSeller.status === 200 && !!sellerToken, 'Seller login');

  const loginBuyer = await requestJson('POST', `${baseUrl}/login`, {
    body: { email: buyerEmail, password },
  });
  const buyerToken = loginBuyer.json?.token;
  check(loginBuyer.status === 200 && !!buyerToken, 'Buyer login');

  const unauthorizedProfile = await requestJson('GET', `${baseUrl}/profile`);
  check(unauthorizedProfile.status === 401, 'Unauthorized profile hatası');

  // 2) İlan oluşturma + akış stabilizasyonu
  const p0 = await requestJson('POST', `${baseUrl}/products`, {
    token: sellerToken,
    body: {
      title: `Krem Blazer ${marker}`,
      price: 650,
      category: 'ceket',
      brand: 'Mango',
      size: 'M',
      gender: 'Kadın',
      condition: 'Yeni Gibi',
      shippingType: 'seller',
      packageSize: 'small',
      imageUrl: 'https://cdn.example.test/products/medium/demo-0.webp',
      description: 'Launch boost test ürünü',
      launchBoost: true,
      launchBoostHours: 72,
    },
  });
  check(p0.status === 200 && p0.json?.success === true, 'Launch boost ürün oluşturma');

  const p1 = await requestJson('POST', `${baseUrl}/products`, {
    token: sellerToken,
    body: {
      title: `Siyah Bluz ${marker}`,
      price: 450,
      category: 'bluz',
      brand: 'Zara',
      size: 'M',
      gender: 'Kadın',
      condition: 'Yeni Gibi',
      shippingType: 'seller',
      packageSize: 'small',
      imageUrl: 'https://cdn.example.test/products/medium/demo-1.webp',
      description: 'Temiz ürün',
      urgentSale: true,
      urgentHours: 24,
    },
  });
  check(p1.status === 200 && p1.json?.success === true, 'Urgent ürün oluşturma');

  const p2 = await requestJson('POST', `${baseUrl}/products`, {
    token: sellerToken,
    body: {
      title: `Mavi Jean ${marker}`,
      price: 500,
      category: 'pantolon',
      brand: 'Levis',
      size: 'M',
      gender: 'Kadın',
      condition: 'İyi',
      shippingType: 'seller',
      packageSize: 'medium',
      imageUrl: 'https://cdn.example.test/products/medium/demo-2.webp',
      description: 'Rahat kalıp',
    },
  });
  check(p2.status === 200 && p2.json?.success === true, 'Tamamlayıcı ürün oluşturma');

  const p3 = await requestJson('POST', `${baseUrl}/products`, {
    token: sellerToken,
    body: {
      title: `Beyaz Sneaker ${marker}`,
      price: 700,
      category: 'ayakkabı',
      brand: 'Nike',
      size: '39',
      gender: 'Kadın',
      condition: 'Yeni',
      shippingType: 'seller',
      packageSize: 'medium',
      imageUrl: 'https://cdn.example.test/products/medium/demo-3.webp',
      description: 'Günlük kullanım',
    },
  });
  check(p3.status === 200 && p3.json?.success === true, '3. ürün oluşturma');

  const firstProductId = Number(p0.json?.product?.id || 0);
  check(firstProductId > 0, 'İlk ürün id alındı');

  const feed = await requestJson('GET', `${baseUrl}/products?smartMode=1&limit=10&q=${encodeURIComponent(marker)}`);
  const feedProducts = feed.json?.products ?? [];
  check(feed.status === 200 && Array.isArray(feedProducts) && feedProducts.length >= 3, 'Feed listesi döndü');
  check(String(feedProducts[0]?.title || '').startsWith('Krem Blazer'), 'Launch boost ilan feed başında');

  // 3) Ücret hesap + öneri
  const feeOk = await requestJson('GET', `${baseUrl}/fees/quote?amount=1000&shippingType=seller`);
  check(feeOk.status === 200 && feeOk.json?.success === true, 'Ücret quote başarılı');

  const feeBad = await requestJson('GET', `${baseUrl}/fees/quote?amount=-1`);
  check(feeBad.status === 400, 'Ücret quote hata senaryosu');

  const reco = await requestJson(
    'GET',
    `${baseUrl}/products/${firstProductId}/outfit-recommendations?limit=6`,
  );
  const recos = reco.json?.recommendations ?? [];
  check(reco.status === 200 && Array.isArray(recos) && recos.length >= 1, 'Kombin önerileri döndü');

  const reco404 = await requestJson('GET', `${baseUrl}/products/999999/outfit-recommendations`);
  check(reco404.status === 404, 'Kombin önerisi 404 senaryosu');

  // 4) Teklif akışı
  const offer = await requestJson('POST', `${baseUrl}/offers`, {
    token: buyerToken,
    body: {
      productId: firstProductId,
      amount: 410,
    },
  });
  check(offer.status === 200 && offer.json?.success === true, 'Teklif oluşturma');

  const offerId = Number(offer.json?.offer?.id || 0);
  check(offerId > 0, 'Teklif id alındı');

  const counter = await requestJson('POST', `${baseUrl}/offers/${offerId}/respond`, {
    token: sellerToken,
    body: {
      action: 'counter',
      counterAmount: 430,
    },
  });
  check(counter.status === 200 && counter.json?.success === true, 'Satıcı karşı teklif');

  const acceptCounter = await requestJson('POST', `${baseUrl}/offers/${offerId}/respond`, {
    token: buyerToken,
    body: {
      action: 'accept',
    },
  });
  check(acceptCounter.status === 200 && acceptCounter.json?.success === true, 'Alıcı karşı teklifi kabul');

  const buyerOrders = await requestJson('GET', `${baseUrl}/buyer/orders`, {
    token: buyerToken,
  });
  check(
    buyerOrders.status === 200 && Array.isArray(buyerOrders.json?.orders) && buyerOrders.json.orders.length >= 1,
    'Sipariş oluşumu doğrulandı',
  );

  const ownOffer = await requestJson('POST', `${baseUrl}/offers`, {
    token: sellerToken,
    body: {
      productId: firstProductId,
      amount: 500,
    },
  });
  check(ownOffer.status === 400, 'Kendi ürüne teklif hata senaryosu');

  // 5) Upload uçları (lokal/staging)
  const authForUpload = process.env.UPLOAD_API_TOKEN || 'smoketest';
  const presign = await requestJson('POST', `${baseUrl}/uploads/presign`, {
    token: authForUpload,
    body: {
      fileName: 'urun.jpg',
      contentType: 'image/jpeg',
      fileSize: 1024,
      folder: 'products',
    },
  });
  check(
    presign.status === 200 && presign.json?.success === true && !!presign.json?.key,
    'Upload presign başarılı',
  );

  const presignTooLarge = await requestJson('POST', `${baseUrl}/uploads/presign`, {
    token: authForUpload,
    body: {
      fileName: 'big.jpg',
      contentType: 'image/jpeg',
      fileSize: 999999999,
      folder: 'products',
    },
  });
  check(presignTooLarge.status === 413, 'Upload boyut limiti hatası');

  const completeBadKey = await requestJson('POST', `${baseUrl}/uploads/complete`, {
    token: authForUpload,
    body: {
      key: 'products/raw/not-valid.jpg',
      folder: 'products',
    },
  });
  check(completeBadKey.status === 400, 'Upload complete geçersiz key hatası');

  const completeOk = await requestJson('POST', `${baseUrl}/uploads/complete`, {
    token: authForUpload,
    body: {
      key: presign.json.key,
      folder: 'products',
    },
  });
  check(
    completeOk.status === 200 && completeOk.json?.success === true && !!completeOk.json?.imageVariants?.medium,
    'Upload complete başarılı',
  );
}

async function main() {
  if (!['local', 'staging'].includes(mode)) {
    throw new Error(`mode geçersiz: ${mode}. Beklenen: local | staging`);
  }

  console.log(`\n▶ Stabilization smoke başladı (mode=${mode})`);

  if (mode === 'local') {
    startLocalServer();
    baseUrl = `http://127.0.0.1:${port}/api`;
  } else {
    if (!process.env.API_BASE_URL) {
      throw new Error('staging modunda API_BASE_URL zorunlu');
    }
    baseUrl = process.env.API_BASE_URL;
  }

  try {
    await runFlow();
    console.log('\n🎉 Tüm sıralı lokal/staging stabilizasyon kontrolleri başarılı.');
  } finally {
    if (serverProc) {
      serverProc.kill('SIGTERM');
      await sleep(250);
    }
    if (mode === 'local') {
      fs.rmSync(localDataDir, { recursive: true, force: true });
    }
  }
}

main().catch((err) => {
  console.error('\nSmoke başarısız:', err?.message || err);
  process.exit(1);
});
