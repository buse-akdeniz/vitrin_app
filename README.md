# Vitrin App

Flutter tabanlı ikinci el kıyafet pazaryeri uygulaması.

## Kritik Ölçeklenebilirlik Gereksinimi (NFR)

Sistem, milyon ölçeğinde eşzamanlı kullanıcı yükünde kritik akışları (görsel yükleme, chat, teklif, favori, satış/satın alma) performans kaybı ve kesinti olmadan çalıştırmalıdır.

## Ölçülebilir Hedefler (SLO)

- API yanıt süresi: p95 < 300 ms
- Erişilebilirlik: >= 99.95%
- Hata oranı (5xx + timeout): < 0.1%
- Kritik akış başarı oranı (upload/chat/offer/checkout): >= 99.9%

## Uygulama Sırası

1. İlan yükleme ve görsel optimizasyonu
	- Presigned upload
	- S3 + CDN
	- Arka planda resize/compress
2. Ana sayfa ilan akışı performansı
	- Sayfalama/cursor
	- Cache + hızlı filtreleme
3. Chat ayrıştırma
	- WebSocket tabanlı bağımsız servis

## Not

Bu repo Flutter istemci uygulamasıdır. Üretim ölçeği hedeflerinin tam karşılanması için backend ve altyapı (S3/CDN, arama motoru, queue, websocket servisleri, izleme) birlikte uygulanmalıdır.

## Başlatılan Faz-1 Artefaktları

- Mimari ve API sözleşmesi: [docs/s3_cdn_image_pipeline.md](docs/s3_cdn_image_pipeline.md)
- Backend görev listesi: [docs/backend_upload_todo.md](docs/backend_upload_todo.md)
- Prod go-live checklist: [docs/prod_upload_go_live_checklist.md](docs/prod_upload_go_live_checklist.md)
- Presign/complete backend servisi: [backend/src/server.js](backend/src/server.js)
- Lambda worker örneği: [infra/aws/lambda/image_optimizer.py](infra/aws/lambda/image_optimizer.py)
- S3 `products/raw/` event wiring: [infra/aws/cloudformation/s3_lambda_notification.yaml](infra/aws/cloudformation/s3_lambda_notification.yaml)
