#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD_DIR="$ROOT_DIR/.lambda_build"
OUT_ZIP="$ROOT_DIR/infra/aws/lambda/VitrinImageOptimizer.zip"

cd "$ROOT_DIR"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cp "$ROOT_DIR/infra/aws/lambda/image_optimizer.py" "$BUILD_DIR/lambda_function.py"

python3 -m pip install --upgrade pip
python3 -m pip install \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.12 \
  --only-binary=:all: \
  --target "$BUILD_DIR" \
  -r "$ROOT_DIR/infra/aws/lambda/requirements.txt"

(
  cd "$BUILD_DIR"
  rm -f "$OUT_ZIP"
  zip -r "$OUT_ZIP" . >/dev/null
)

echo "Created: $OUT_ZIP"
