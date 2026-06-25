# Vitrin Upload API (S3 Presign + Complete)

Bu servis, Flutter istemcisinin doğrudan S3'e görsel yükleyebilmesi için gerekli endpointleri sağlar.

## Endpointler

- `POST /api/uploads/presign`
- `POST /api/uploads/complete`

Davranış:

- `folder` sadece `products` kabul eder
- `complete` için `key` formatı doğrulanır (`products/raw/YYYY/MM/<uuid>.<ext>`)
- endpointler rate-limit ile korunur

## Kurulum

1. `cp .env.example .env`
2. `npm install`
3. `npm run dev`

## Railway Deploy (Monorepo)

Bu repoda backend klasörü `backend/` altındadır. Railway'de yanlışlıkla farklı entrypoint (`index.js`) çalışmaması için kökte:

- [railway.json](../railway.json)
- [nixpacks.toml](../nixpacks.toml)

dosyaları eklidir.

Zorunlu env örneği:

- [backend/.env.railway.example](.env.railway.example)

En az şu değişkenler set edilmelidir:

- `AWS_REGION`
- `S3_RAW_BUCKET`
- `CDN_BASE_URL`
- `UPLOAD_API_TOKEN`

## İstek Örnekleri

### Presign

```bash
curl -X POST http://localhost:3000/api/uploads/presign \
  -H 'Content-Type: application/json' \
  -d '{
    "fileName":"dress.jpg",
    "contentType":"image/jpeg",
    "fileSize":1234567,
    "folder":"products"
  }'
```

### Complete

```bash
curl -X POST http://localhost:3000/api/uploads/complete \
  -H 'Content-Type: application/json' \
  -d '{
    "key":"products/raw/2026/05/uuid.jpg",
    "folder":"products"
  }'
```

## Not

Bu servis örnek amaçlıdır. Üretimde auth, rate-limit, logging, metrics ve IAM hardening zorunludur.
