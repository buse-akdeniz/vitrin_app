# S3 + CDN + Arka Plan Görsel Optimizasyonu — Prod Go-Live Checklist

Bu doküman, upload hattını "kod hazır" seviyesinden "prod aktif" seviyesine taşımak için zorunlu adımları içerir.

## Son Durum (1 Haziran 2026)

- [x] Lambda kaynak kodu hazır (`image_optimizer.py`)
- [x] Lambda dependency dosyası hazır (`requirements.txt`)
- [x] Lambda paketleme scripti hazır (`build_zip.sh`)
- [x] Lambda zip artefact yerelde üretildi (`infra/aws/lambda/VitrinImageOptimizer.zip`)
- [x] AWS CLI yerelde kuruldu
- [x] AWS credentials/profile tanımlandı ve erişim doğrulandı
- [x] AWS tarafı temel alarm/izleme bağlantıları kuruldu
- [x] CloudFront + OAC oluşturuldu (domain: `d130hg8g3tdei3.cloudfront.net`)
- [x] Presign -> S3 upload -> complete smoke testi geçti
- [x] Lambda `small/medium/large` varyant üretimi doğrulandı

### Sıradaki Net Adımlar (Deploy)

1. Lambda oluştur/güncelle
	- Runtime: Python 3.12
	- Handler: `lambda_function.lambda_handler`
	- Env: `PROCESSED_BUCKET=vitrin-images-processed`, `WEBP_QUALITY=80`
	- Otomasyon scripti: `infra/aws/lambda/deploy_lambda.sh`
2. IAM role ata
	- Raw bucket `GetObject`
	- Processed bucket `PutObject`
3. S3 event tanımla
	- Source: raw bucket
	- Event: `ObjectCreated:*`
	- Prefix: `products/raw/`
	- Target: `image_optimizer` Lambda
4. CloudWatch
	- Log retention (örn. 14 gün)
	- Error rate alarmı
5. Smoke test
	- Presign -> upload -> complete -> processed bucket'ta `small/medium/large`

## 0) Hedef Tanımı (Done)

Aşağıdakiler sağlandığında madde tamam kabul edilir:

- Mobil istemci presigned URL ile dosyayı doğrudan S3 raw bucket'a yükler.
- S3 event Lambda'yı tetikler, `small/medium/large` varyant üretir.
- Uygulama görselleri CloudFront CDN URL'leriyle açar.
- Uçtan uca akış hata oranı `< 0.1%` ve başarı oranı `>= 99.9%`.

---

## 1) AWS Kaynakları

- [x] `vitrin-images-raw` bucket (private)
- [x] `vitrin-images-processed` bucket (private)
- [x] CloudFront Distribution (origin: processed bucket, OAC aktif)
- [x] Lambda `image_optimizer` deploy
- [x] S3 raw -> Lambda event (`products/raw/` prefix)
- [x] CloudWatch log retention + alarm

Referans şablon: [infra/aws/cloudformation/s3_lambda_notification.yaml](../infra/aws/cloudformation/s3_lambda_notification.yaml)

---

## 2) IAM ve Güvenlik

- [ ] Upload API rolü sadece `raw bucket` için `PutObject` yetkisine sahip
- [x] Lambda rolü: raw bucket read + processed bucket write
- [x] Bucket public access block açık
- [x] CloudFront dışında processed bucket doğrudan erişilemez
- [x] Presign TTL: `<= 300s` (backend env ile ayarlı)
- [x] Content-Type whitelist aktif
- [x] Max dosya boyutu limiti aktif (örn. 15MB)
- [x] Rate limit aktif (IP/kullanıcı bazlı, upload endpoint)

---

## 3) Backend Konfigürasyonu

Dosyalar:
- [backend/.env.example](../backend/.env.example)
- [backend/src/server.js](../backend/src/server.js)

Prod env değerleri:

- [ ] `AWS_REGION`
- [ ] `S3_RAW_BUCKET`
- [ ] `CDN_BASE_URL`
- [ ] `PRESIGN_EXPIRES_SECONDS=300`
- [ ] `MAX_FILE_SIZE_BYTES=15728640`
- [ ] `UPLOAD_API_TOKEN` (boş bırakılmamalı)
- [x] `VERIFY_OBJECT_ON_COMPLETE=true` (örnek env dosyasında aktif)

Endpoint smoke:

- [x] `POST /api/uploads/presign` -> 200 + `uploadUrl,key`
- [x] `POST /api/uploads/complete` -> 200 + `imageUrl,imageVariants`

---

## 4) Flutter Konfigürasyonu

- [ ] `--dart-define=API_BASE_URL=https://<api-domain>/api`
- [ ] `--dart-define=UPLOAD_PRESIGN_PATH=/uploads/presign`
- [ ] `--dart-define=UPLOAD_COMPLETE_PATH=/uploads/complete`
- [ ] `--dart-define=UPLOAD_REQUEST_TIMEOUT_SECONDS=25`

Doğrulama:

- [ ] Foto yükleme sonrası ürün listesinde CDN URL ile görsel açılıyor
- [ ] Varyant alanları (`image_variants` / `imageVariants`) düzgün okunuyor

---

## 5) Uçtan Uca Test Senaryosu (Zorunlu)

1. Mobilde yeni ilan aç
2. Presign alındığını doğrula
3. Dosyanın raw bucket'a düştüğünü doğrula
4. Lambda tetiklendi mi kontrol et
5. Processed bucket'ta `small/medium/large` üretildi mi kontrol et
6. `complete` yanıtında `imageUrl` ve `imageVariants` geliyor mu kontrol et
7. Ana sayfa + ürün detayında görsel CDN'den açılıyor mu kontrol et

- [ ] E2E senaryo geçti

---

## 6) Operasyonel Alarm ve İzleme

- [x] Lambda error rate alarmı (>=1%)
- [x] Lambda duration p95 alarmı
- [ ] API 5xx alarmı
- [ ] Upload başarı oranı paneli
- [ ] CloudFront 4xx/5xx paneli
- [ ] S3 put/get error paneli

---

## 7) Performans ve Dayanıklılık

- [ ] 1k eşzamanlı upload testi
- [ ] 10k dalga testi
- [ ] 30 dakika soak testi
- [ ] Fail senaryosu: Lambda down -> retry/DLQ doğrulandı
- [ ] Fail senaryosu: S3 throttling -> graceful hata mesajı doğrulandı

---

## 8) Go/No-Go Kararı

Go-live öncesi tüm kritik maddeler:

- [ ] 1,2,3,4,5 bölümleri tamamen ✅
- [ ] Kritik alarm/paneller ✅
- [ ] Rollback planı ✅
- [ ] On-call sorumlusu atanmış ✅

No-Go koşulları:

- E2E başarısız
- `complete` response tutarsız
- Lambda error rate yüksek
- CDN görselleri stabilize değil
