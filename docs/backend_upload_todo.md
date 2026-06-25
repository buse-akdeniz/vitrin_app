# Backend Upload Hattı TODO (Faz-1)

## Endpointler

- [x] `POST /uploads/presign` (örnek implementasyon: [backend/src/server.js](../backend/src/server.js))
- [x] `POST /uploads/complete` (örnek implementasyon: [backend/src/server.js](../backend/src/server.js))

## Presign Kuralları

- [ ] Auth zorunlu
- [ ] `contentType` whitelist: image/jpeg,image/png,image/webp,image/heic
- [ ] max boyut: 15MB
- [ ] url ttl: 300 saniye

## Complete Kuralları

- [x] Auth zorunlu (opsiyonel token ile aktif)
- [ ] Kullanıcının kendi key alanı doğrulanır
- [x] Dönen payload `imageUrl` + `imageVariants` içerir

## Ürün Tablosu

- [ ] `image_url` (ana görsel)
- [ ] `image_variants` (json)
- [ ] `image_status` (processing|ready|failed)

## Operasyon

- [ ] CloudWatch alarm: Lambda error > 1%
- [ ] DLQ (SQS) bağla
- [ ] Reprocess endpoint/script

## S3 Event -> Lambda Bağlantısı

- [x] `products/raw/` prefix'i için CloudFormation şablonu eklendi: [infra/aws/cloudformation/s3_lambda_notification.yaml](../infra/aws/cloudformation/s3_lambda_notification.yaml)
