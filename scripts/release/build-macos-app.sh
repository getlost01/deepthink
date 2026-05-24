#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

DERIVED_DATA="${DERIVED_DATA:-build/derivedData}"
APP_PATH="$DERIVED_DATA/Build/Products/Release/DeepThink.app"

echo "=== Build CLI + MCP ==="
(cd cli && bash build.sh)

echo "=== Generate Xcode project ==="
xcodegen generate

echo "=== Build DeepThink (Release, unsigned) ==="
mkdir -p build
xcodebuild build \
  -project DeepThink.xcodeproj \
  -scheme DeepThink \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

if [[ ! -d "$APP_PATH" ]]; then
  echo "::error::App bundle not found at $APP_PATH"
  exit 1
fi

RESOURCES="$APP_PATH/Contents/Resources"
for binary in deepthink-cli deepthink-mcp; do
  if [[ ! -f "$RESOURCES/$binary" ]]; then
    echo "::error::Missing bundled binary: $RESOURCES/$binary"
    exit 1
  fi
done

echo "=== Ad-hoc sign ==="
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

echo "Build complete: $APP_PATH"
