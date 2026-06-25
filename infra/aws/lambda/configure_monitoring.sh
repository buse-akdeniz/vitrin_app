#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-eu-central-1}"
FUNCTION_NAME="${FUNCTION_NAME:-VitrinImageOptimizer}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-14}"
ERROR_RATE_THRESHOLD="${ERROR_RATE_THRESHOLD:-1}"
DURATION_P95_THRESHOLD_MS="${DURATION_P95_THRESHOLD_MS:-15000}"
PERIOD_SECONDS="${PERIOD_SECONDS:-300}"
EVALUATION_PERIODS="${EVALUATION_PERIODS:-1}"
ALARM_ACTIONS="${ALARM_ACTIONS:-}"
OK_ACTIONS="${OK_ACTIONS:-}"
LOG_GROUP_NAME="/aws/lambda/${FUNCTION_NAME}"
ERROR_ALARM_NAME="${FUNCTION_NAME}-ErrorRateHigh"
DURATION_ALARM_NAME="${FUNCTION_NAME}-DurationP95High"

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI bulunamadı." >&2
  exit 1
fi

echo "[1/3] Log retention ayarlanıyor: ${LOG_GROUP_NAME} -> ${LOG_RETENTION_DAYS} gün"
aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP_NAME" \
  --retention-in-days "$LOG_RETENTION_DAYS" \
  --region "$REGION"

COMMON_ARGS=(
  --region "$REGION"
  --evaluation-periods "$EVALUATION_PERIODS"
  --datapoints-to-alarm "$EVALUATION_PERIODS"
  --treat-missing-data notBreaching
  --comparison-operator GreaterThanOrEqualToThreshold
)

if [[ -n "$ALARM_ACTIONS" ]]; then
  COMMON_ARGS+=(--alarm-actions "$ALARM_ACTIONS")
fi

if [[ -n "$OK_ACTIONS" ]]; then
  COMMON_ARGS+=(--ok-actions "$OK_ACTIONS")
fi

echo "[2/3] Error rate alarm oluşturuluyor: ${ERROR_ALARM_NAME}"
aws cloudwatch put-metric-alarm \
  --alarm-name "$ERROR_ALARM_NAME" \
  --alarm-description "Lambda error rate >= ${ERROR_RATE_THRESHOLD}% for ${FUNCTION_NAME}" \
  --threshold "$ERROR_RATE_THRESHOLD" \
  --metrics "[{\"Id\":\"errors\",\"MetricStat\":{\"Metric\":{\"Namespace\":\"AWS/Lambda\",\"MetricName\":\"Errors\",\"Dimensions\":[{\"Name\":\"FunctionName\",\"Value\":\"${FUNCTION_NAME}\"}]},\"Period\":${PERIOD_SECONDS},\"Stat\":\"Sum\"},\"ReturnData\":false},{\"Id\":\"invocations\",\"MetricStat\":{\"Metric\":{\"Namespace\":\"AWS/Lambda\",\"MetricName\":\"Invocations\",\"Dimensions\":[{\"Name\":\"FunctionName\",\"Value\":\"${FUNCTION_NAME}\"}]},\"Period\":${PERIOD_SECONDS},\"Stat\":\"Sum\"},\"ReturnData\":false},{\"Id\":\"error_rate\",\"Expression\":\"IF(invocations>0,100*errors/invocations,0)\",\"Label\":\"ErrorRatePercent\",\"ReturnData\":true}]" \
  "${COMMON_ARGS[@]}"

echo "[3/3] Duration p95 alarm oluşturuluyor: ${DURATION_ALARM_NAME}"
aws cloudwatch put-metric-alarm \
  --alarm-name "$DURATION_ALARM_NAME" \
  --alarm-description "Lambda duration p95 >= ${DURATION_P95_THRESHOLD_MS}ms for ${FUNCTION_NAME}" \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value="$FUNCTION_NAME" \
  --extended-statistic p95 \
  --period "$PERIOD_SECONDS" \
  --threshold "$DURATION_P95_THRESHOLD_MS" \
  "${COMMON_ARGS[@]}"

echo "Tamamlandı: retention + error rate + duration p95"
