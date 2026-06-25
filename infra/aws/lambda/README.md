# Lambda Image Optimizer

Bu klasör, S3 event ile tetiklenen görsel optimize worker’ını içerir.

## Ortam Değişkenleri

- `PROCESSED_BUCKET`: çıktının yazılacağı bucket adı
- `WEBP_QUALITY`: varsayılan `80`

## Event Kaynağı

- S3 `ObjectCreated:*`
- Kaynak prefix önerisi: `products/raw/`

## Çıktılar

- `products/original/...`
- `products/small/...webp`
- `products/medium/...webp`
- `products/large/...webp`

## Dağıtım Notu

Lambda runtime için `Pillow` paketini layer veya container image ile deploy edin.
