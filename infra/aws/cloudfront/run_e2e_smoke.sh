#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/busenurakdeniz/vitrin_app"
BACK="$ROOT/backend"
LOG="$ROOT/e2e_smoke.log"
: > "$LOG"

python3 - <<'PY'
from PIL import Image
img = Image.new('RGB', (64, 64), (220, 20, 60))
img.save('/Users/busenurakdeniz/vitrin_app/e2e_test.jpg', 'JPEG')
PY

cd "$BACK"
PORT=3000 \
AWS_REGION=eu-central-1 \
S3_RAW_BUCKET=vitrin-original-photos-707605821946-eu-central-1-an \
CDN_BASE_URL=https://d130hg8g3tdei3.cloudfront.net \
UPLOAD_API_TOKEN=smoketest \
VERIFY_OBJECT_ON_COMPLETE=true \
node src/server.js > "$ROOT/e2e_server.log" 2>&1 &
SERVER_PID=$!

sleep 2

PRESIGN=$(curl -sS -X POST http://127.0.0.1:3000/api/uploads/presign \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer smoketest' \
  -d '{"fileName":"e2e_test.jpg","contentType":"image/jpeg","fileSize":1024,"folder":"products"}')

echo "PRESIGN=$PRESIGN" >> "$LOG"

UPLOAD_URL=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['uploadUrl'])" "$PRESIGN")
KEY=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['key'])" "$PRESIGN")

curl -sS -X PUT "$UPLOAD_URL" -H 'Content-Type: image/jpeg' --data-binary @"$ROOT/e2e_test.jpg" > /dev/null

COMPLETE=$(curl -sS -X POST http://127.0.0.1:3000/api/uploads/complete \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer smoketest' \
  -d "{\"key\":\"$KEY\",\"folder\":\"products\"}")

echo "COMPLETE=$COMPLETE" >> "$LOG"
echo "KEY=$KEY" >> "$LOG"

kill "$SERVER_PID" || true

cat "$LOG"
