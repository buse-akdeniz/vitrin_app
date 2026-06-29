#!/usr/bin/env bash
# Build Flutter release with production dart-define values.
# Usage:
#   export API_BASE_URL=https://your-api.up.railway.app/api
#   ./scripts/flutter_prod_build.sh apk
# Or:
#   ./scripts/flutter_prod_build.sh apk config/flutter.prod.env

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-apk}"
ENV_FILE="${2:-}"

if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi

: "${API_BASE_URL:?Set API_BASE_URL (e.g. https://your-api.up.railway.app/api)}"

PRESIGN_PATH="${UPLOAD_PRESIGN_PATH:-/uploads/presign}"
COMPLETE_PATH="${UPLOAD_COMPLETE_PATH:-/uploads/complete}"
TIMEOUT_SEC="${UPLOAD_REQUEST_TIMEOUT_SECONDS:-25}"
CHAT_WS="${CHAT_PREFER_WEBSOCKET:-true}"

DEFINES=(
  "--dart-define=API_BASE_URL=${API_BASE_URL}"
  "--dart-define=UPLOAD_PRESIGN_PATH=${PRESIGN_PATH}"
  "--dart-define=UPLOAD_COMPLETE_PATH=${COMPLETE_PATH}"
  "--dart-define=UPLOAD_REQUEST_TIMEOUT_SECONDS=${TIMEOUT_SEC}"
  "--dart-define=CHAT_PREFER_WEBSOCKET=${CHAT_WS}"
)

echo "Building ${TARGET} with API_BASE_URL=${API_BASE_URL}"

case "$TARGET" in
  apk)
    flutter build apk --release "${DEFINES[@]}"
    echo "Output: build/app/outputs/flutter-apk/app-release.apk"
    ;;
  appbundle|aab)
    flutter build appbundle --release "${DEFINES[@]}"
    echo "Output: build/app/outputs/bundle/release/app-release.aab"
    ;;
  ios)
    flutter build ios --release "${DEFINES[@]}"
    echo "Open ios/Runner.xcworkspace in Xcode to archive."
    ;;
  *)
    echo "Unknown target: $TARGET (use apk | appbundle | ios)" >&2
    exit 1
    ;;
esac
