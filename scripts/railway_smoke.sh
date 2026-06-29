#!/usr/bin/env bash
# Smoke test a deployed Vitrin API.
# Usage: API_BASE_URL=https://your-api.up.railway.app/api ./scripts/railway_smoke.sh

set -euo pipefail

BASE="${API_BASE_URL:?Set API_BASE_URL (with /api suffix)}"
BASE="${BASE%/}"

echo "==> Health"
curl -fsS "${BASE%/api}/health" | python3 -m json.tool | head -20

echo "==> Register + login"
EMAIL="smoke-$(date +%s)@vitrin.dev"
curl -fsS -X POST "$BASE/register" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"secret1234\"}" | python3 -m json.tool

TOKEN=$(curl -fsS -X POST "$BASE/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"secret1234\"}" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

echo "==> Feed"
curl -fsS "$BASE/products/feed?limit=5" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("products", len(d.get("products",[])))'

echo "==> Create product"
curl -fsS -X POST "$BASE/products" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Smoke Test Ürün","price":199,"category":"Test"}' | python3 -m json.tool | head -15

echo "OK — smoke test passed for $BASE"
