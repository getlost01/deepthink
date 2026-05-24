#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TAG="${1:-${GITHUB_REF_NAME:-}}"
if [[ -z "$TAG" ]]; then
  echo "Usage: package-zip.sh <tag>   e.g. v1.0.1"
  exit 1
fi

VERSION="${TAG#v}"
DERIVED_DATA="${DERIVED_DATA:-build/derivedData}"
APP_PATH="$DERIVED_DATA/Build/Products/Release/DeepThink.app"
ZIP_NAME="DeepThink-${VERSION}.zip"
DIST_DIR="${DIST_DIR:-dist}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "::error::App not found at $APP_PATH — run build-macos-app.sh first"
  exit 1
fi

BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
if [[ "$BUNDLE_VERSION" != "$VERSION" ]]; then
  echo "::error::App CFBundleShortVersionString ($BUNDLE_VERSION) != tag version ($VERSION)"
  exit 1
fi

mkdir -p "$DIST_DIR"
ditto -c -k --keepParent "$APP_PATH" "$DIST_DIR/$ZIP_NAME"

SHA256="$(shasum -a 256 "$DIST_DIR/$ZIP_NAME" | awk '{print $1}')"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "ZIP_NAME=$ZIP_NAME"
    echo "VERSION=$VERSION"
    echo "SHA256=$SHA256"
  } >> "$GITHUB_ENV"
fi

echo "ZIP_NAME=$ZIP_NAME"
echo "VERSION=$VERSION"
echo "SHA256=$SHA256"
echo "Packaged: $DIST_DIR/$ZIP_NAME"
