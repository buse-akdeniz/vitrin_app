#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
ZIP_PATH="${ZIP_PATH:-$ROOT_DIR/infra/aws/lambda/VitrinImageOptimizer.zip}"
REGION="${AWS_REGION:-eu-central-1}"
FUNCTION_NAME="${FUNCTION_NAME:-vitrin-image-optimizer}"
ROLE_ARN="${ROLE_ARN:-}"
RAW_BUCKET="${RAW_BUCKET:-}"
PROCESSED_BUCKET="${PROCESSED_BUCKET:-}"
WEBP_QUALITY="${WEBP_QUALITY:-80}"
MEMORY_SIZE="${MEMORY_SIZE:-1024}"
TIMEOUT="${TIMEOUT:-30}"

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI bulunamadı." >&2
  exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "ERROR: Lambda zip bulunamadı: $ZIP_PATH" >&2
  exit 1
fi

if [[ -z "$ROLE_ARN" || -z "$RAW_BUCKET" || -z "$PROCESSED_BUCKET" ]]; then
  echo "ERROR: ROLE_ARN, RAW_BUCKET ve PROCESSED_BUCKET zorunlu." >&2
  exit 1
fi

echo "[1/5] AWS kimlik doğrulama kontrolü..."
aws sts get-caller-identity --region "$REGION" >/dev/null

echo "[2/5] Lambda oluştur/güncelle: $FUNCTION_NAME"
if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" >/dev/null 2>&1; then
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$ZIP_PATH" \
    --region "$REGION" >/dev/null

  aws lambda wait function-updated \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION"

  aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.12 \
    --handler lambda_function.lambda_handler \
    --memory-size "$MEMORY_SIZE" \
    --timeout "$TIMEOUT" \
    --environment "Variables={PROCESSED_BUCKET=$PROCESSED_BUCKET,WEBP_QUALITY=$WEBP_QUALITY}" \
    --region "$REGION" >/dev/null
else
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.12 \
    --handler lambda_function.lambda_handler \
    --role "$ROLE_ARN" \
    --memory-size "$MEMORY_SIZE" \
    --timeout "$TIMEOUT" \
    --environment "Variables={PROCESSED_BUCKET=$PROCESSED_BUCKET,WEBP_QUALITY=$WEBP_QUALITY}" \
    --zip-file "fileb://$ZIP_PATH" \
    --region "$REGION" >/dev/null
fi

aws lambda wait function-updated \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION"

LAMBDA_ARN="$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" --query 'Configuration.FunctionArn' --output text)"

echo "[3/5] S3 -> Lambda invoke izni"
aws lambda remove-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "AllowExecutionFromS3RawBucket" \
  --region "$REGION" >/dev/null 2>&1 || true

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "AllowExecutionFromS3RawBucket" \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::$RAW_BUCKET" \
  --region "$REGION" >/dev/null

echo "[4/5] Raw bucket notification konfigürasyonu"
TMP_JSON="$(mktemp)"
cat > "$TMP_JSON" <<JSON
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "products-raw-image-optimizer",
      "LambdaFunctionArn": "$LAMBDA_ARN",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            { "Name": "prefix", "Value": "products/raw/" }
          ]
        }
      }
    }
  ]
}
JSON

aws s3api put-bucket-notification-configuration \
  --bucket "$RAW_BUCKET" \
  --notification-configuration "file://$TMP_JSON" \
  --region "$REGION" >/dev/null

rm -f "$TMP_JSON"

echo "[5/5] Özet"
echo "Lambda ARN      : $LAMBDA_ARN"
echo "Raw bucket      : $RAW_BUCKET"
echo "Processed bucket: $PROCESSED_BUCKET"
echo "Tamamlandı."
