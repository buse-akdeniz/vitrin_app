# S3 + CDN + Arka Plan Görsel Optimizasyonu

Bu doküman, üretim için görsel yükleme hattının ilk fazını tanımlar.

## Hedef

- Mobil istemci dosyayı **ana API sunucusuna değil** doğrudan obje depolamaya yükler.
- Yüklenen orijinal görsel arka planda otomatik optimize edilir.
- Uygulama görselleri CDN üzerinden servis eder.

## Mimari (Faz-1)

1. Flutter istemci -> `POST /uploads/presign`
2. API -> S3 presigned `PUT` URL döner
3. Flutter -> dosyayı doğrudan S3 `raw` bucket'a yükler
4. Flutter -> `POST /uploads/complete`
5. API -> ürün kaydında görsel anahtarını/URL’yi saklar
6. S3 Event -> Lambda `image_optimizer`
7. Lambda -> small/medium/large + web optimize format üretir, `processed` bucket’a yazar
8. CloudFront -> `processed` bucket’ı cache’leyip son kullanıcıya dağıtır

## API Sözleşmesi

### 1) Presign

`POST /uploads/presign`

İstek:

```json
{
  "fileName": "image_123.jpg",
  "contentType": "image/jpeg",
  "fileSize": 2456789,
  "folder": "products"
}
```

Yanıt:

```json
{
  "success": true,
  "uploadUrl": "https://...signed-url...",
  "key": "products/raw/2026/05/uuid.jpg",
  "headers": {
    "Content-Type": "image/jpeg"
  },
  "cdnBaseUrl": "https://cdn.example.com"
}
```

### 2) Complete

`POST /uploads/complete`

İstek:

```json
{
  "key": "products/raw/2026/05/uuid.jpg",
  "folder": "products"
}
```

Yanıt:

```json
{
  "success": true,
  "imageUrl": "https://cdn.example.com/products/medium/2026/05/uuid.webp",
  "imageVariants": {
    "small": "https://cdn.example.com/products/small/2026/05/uuid.webp",
    "medium": "https://cdn.example.com/products/medium/2026/05/uuid.webp",
    "large": "https://cdn.example.com/products/large/2026/05/uuid.webp",
    "original": "https://cdn.example.com/products/original/2026/05/uuid.jpg"
  }
}
```

## Bucket Stratejisi

- `vitrin-images-raw` (private)
- `vitrin-images-processed` (private, sadece CloudFront OAC erişir)

Önerilen path:

- `products/raw/YYYY/MM/<uuid>.jpg`
- `products/original/YYYY/MM/<uuid>.jpg`
- `products/small/YYYY/MM/<uuid>.webp`
- `products/medium/YYYY/MM/<uuid>.webp`
- `products/large/YYYY/MM/<uuid>.webp`

## Boyut Politikası

- `small`: genişlik 320
- `medium`: genişlik 768
- `large`: genişlik 1280
- Oran korunur, EXIF orientation düzeltilir
- Çıktı formatı: WebP (kalite 78-82)

## Güvenlik

- Presigned URL süresi: 2-5 dk
- `content-type` whitelist
- max dosya boyutu (örn. 15 MB)
- kullanıcı başına hız limiti (rate limit)
- bucket public access kapalı

## Operasyonel İzleme

- Lambda success/error metriği
- Görsel işleme süreleri (p95)
- S3 put/get hata oranı
- CloudFront cache hit ratio

## Flutter Ayarları

Aşağıdaki `--dart-define` parametrelerini CI/CD’de verin:

- `API_BASE_URL`
- `UPLOAD_PRESIGN_PATH` (default: `/uploads/presign`)
- `UPLOAD_COMPLETE_PATH` (default: `/uploads/complete`)
- `UPLOAD_REQUEST_TIMEOUT_SECONDS` (default: `25`)

## Faz-1 Done Kriteri

- [ ] Mobil uygulama presigned upload ile dosyayı S3’e basıyor
- [ ] Lambda small/medium/large varyant üretiyor
- [ ] Ürün listesi CDN URL ile görsel açıyor
- [ ] p95 upload prepare < 300 ms
- [ ] upload başarısı >= 99.9%
