#!/usr/bin/env bash
set -euo pipefail

KEY="$(grep '^KEY=' /Users/busenurakdeniz/vitrin_app/e2e_smoke.log | tail -1 | cut -d= -f2-)"
BUCKET="vitrin-optimized-photos-707605821946-eu-central-1-an"

sleep 8

for v in small medium large; do
  TARGET="$(echo "$KEY" | sed "s#/raw/#/$v/#" | sed -E 's/\.[^.]+$/.webp/')"
  echo "checking $TARGET"
  aws s3api head-object --bucket "$BUCKET" --key "$TARGET" --output json

done
