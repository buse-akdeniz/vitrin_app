# Vitrin — Railway Production Deploy

Bu rehber, monorepo içindeki `backend/` servisini Railway'e deploy etmek ve Flutter mobil istemciyi prod API'ye bağlamak içindir.

## 1) Railway projesi

1. [railway.app](https://railway.app) → New Project → Deploy from GitHub → `vitrin_app` reposunu seçin.
2. Kök dizinde `railway.json` ve `nixpacks.toml` zaten yapılandırılmıştır.
3. Health check: `GET /health`

## 2) Environment variables

Railway → Service → Variables. Şablon:

`backend/.env.railway.example`

Zorunlu:

| Değişken | Örnek |
|----------|--------|
| `AWS_REGION` | `eu-central-1` |
| `S3_RAW_BUCKET` | `vitrin-original-photos-...` |
| `CDN_BASE_URL` | `https://d130hg8g3tdei3.cloudfront.net` |
| `UPLOAD_API_TOKEN` | uzun rastgele secret |
| `AUTH_SALT` | uzun rastgele secret |
| `VERIFY_OBJECT_ON_COMPLETE` | `true` |

AWS kimlik bilgileri Railway'de şu yollardan biriyle verilir:

- Service → Variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- veya IAM role (Railway AWS entegrasyonu varsa)

Opsiyonel:

- `OPENAI_API_KEY` — AI asistan için
- `DATA_DIR=/app/backend/data` — kalıcı veri (volume ile)
- `CORS_ORIGINS` — web istemci için

## 3) Kalıcı veri (Volume)

Marketplace verisi `backend/data/db.json` içinde tutulur. Redeploy'da silinmemesi için:

1. Railway → Service → Volumes → Add Volume
2. Mount path: `/app/backend/data`
3. Variable: `DATA_DIR=/app/backend/data`

## 4) Deploy doğrulama

Deploy sonrası public domain alın (ör. `https://vitrin-api.up.railway.app`).

```bash
export API_BASE_URL=https://YOUR-DOMAIN.up.railway.app/api
./scripts/railway_smoke.sh
```

Upload testi için AWS S3 + CDN pipeline'ının aktif olduğundan emin olun (`docs/prod_upload_go_live_checklist.md`).

## 5) Flutter prod build

```bash
cp config/flutter.prod.example.env config/flutter.prod.env
# config/flutter.prod.env içinde API_BASE_URL'i Railway domain'inizle güncelleyin

chmod +x scripts/flutter_prod_build.sh
./scripts/flutter_prod_build.sh apk config/flutter.prod.env
```

iOS:

```bash
./scripts/flutter_prod_build.sh ios config/flutter.prod.env
```

## 6) Chat WebSocket (prod)

Mobil istemci varsayılan olarak WebSocket dener:

- `ws://HOST/ws/chat` (HTTP API ile aynı host, `/api` olmadan)
- Başarısız olursa HTTP fallback: `POST /api/support/chat`

Railway tek serviste HTTP + WS upgrade destekler; ek port gerekmez.

## 7) Go-live kontrol listesi

- [ ] `/health` → `ok: true`, `hasS3Bucket`, `hasCdnBaseUrl`
- [ ] `railway_smoke.sh` geçiyor
- [ ] Telefonda kayıt → ürün ekle → görsel upload → feed'de görünüyor
- [ ] Teklif / sipariş akışı test edildi
- [ ] Volume mount (prod veri kalıcılığı)

## Rollback

Railway → Deployments → önceki başarılı deployment → Redeploy.
