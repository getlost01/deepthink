#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# DeepThink — notarization + DMG packaging script
#
# Usage:
#   ./scripts/notarize.sh [--skip-notarize]
#
# Required environment variables (or set in a .env.notarize file):
#   APPLE_ID            your Apple developer account email
#   APPLE_TEAM_ID       10-char team ID (find at developer.apple.com/account)
#   APPLE_APP_PASSWORD  app-specific password (appleid.apple.com → Security)
#
# Prerequisites:
#   - Xcode command line tools
#   - create-dmg  (brew install create-dmg)
#   - The app must be code-signed with a Developer ID Application certificate
#     Set CODE_SIGN_IDENTITY in env or export it before running
#
# Outputs:
#   dist/DeepThink.dmg  — notarized, stapled DMG ready for distribution
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Config ──────────────────────────────────────────────────────────────────
APP_NAME="DeepThink"
BUNDLE_ID="com.deepthink.app"
SCHEME="DeepThink"
CONFIGURATION="Release"
ARCHIVE_PATH="$ROOT/build/${APP_NAME}.xcarchive"
EXPORT_PATH="$ROOT/build/export"
DMG_PATH="$ROOT/dist/${APP_NAME}.dmg"
APP_PATH="$EXPORT_PATH/${APP_NAME}.app"

SKIP_NOTARIZE=false
if [[ "${1:-}" == "--skip-notarize" ]]; then
  SKIP_NOTARIZE=true
fi

# Load secrets from .env.notarize if present
if [[ -f "$ROOT/.env.notarize" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/.env.notarize"
fi

# ── Build CLI first ──────────────────────────────────────────────────────────
echo "▸ Building CLI + MCP..."
cd "$ROOT/cli"
if command -v bun &>/dev/null; then
  bash build.sh
  echo "  CLI: $(du -h out/deepthink | cut -f1)"
  echo "  MCP: $(du -h out/deepthink-mcp | cut -f1)"
else
  echo "  warning: bun not found — CLI/MCP binaries will not be updated"
fi
cd "$ROOT"

# ── Archive ──────────────────────────────────────────────────────────────────
echo "▸ Archiving ${APP_NAME}..."
mkdir -p "$ROOT/build"
xcodebuild archive \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application}" \
  DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-}" \
  | xcpretty 2>/dev/null || true

# ── Export ──────────────────────────────────────────────────────────────────
echo "▸ Exporting..."
mkdir -p "$EXPORT_PATH"
cat > /tmp/export_options.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>${APPLE_TEAM_ID:-}</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>${CODE_SIGN_IDENTITY:-Developer ID Application}</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist /tmp/export_options.plist \
  -exportPath "$EXPORT_PATH"

# ── Notarize ─────────────────────────────────────────────────────────────────
if [[ "$SKIP_NOTARIZE" == false ]]; then
  echo "▸ Creating zip for notarization..."
  ditto -c -k --keepParent "$APP_PATH" /tmp/${APP_NAME}-notarize.zip

  echo "▸ Submitting to Apple notarization service..."
  xcrun notarytool submit /tmp/${APP_NAME}-notarize.zip \
    --apple-id "${APPLE_ID:?set APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}" \
    --password "${APPLE_APP_PASSWORD:?set APPLE_APP_PASSWORD}" \
    --wait

  echo "▸ Stapling notarization ticket..."
  xcrun stapler staple "$APP_PATH"
else
  echo "▸ Skipping notarization (--skip-notarize)"
fi

# ── Package DMG ──────────────────────────────────────────────────────────────
echo "▸ Creating DMG..."
mkdir -p "$ROOT/dist"
rm -f "$DMG_PATH"

if command -v create-dmg &>/dev/null; then
  create-dmg \
    --volname "${APP_NAME}" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 160 \
    --icon "${APP_NAME}.app" 180 170 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 480 170 \
    "$DMG_PATH" \
    "$EXPORT_PATH/"
else
  echo "  warning: create-dmg not found — creating plain DMG with hdiutil"
  hdiutil create -volname "$APP_NAME" -srcfolder "$EXPORT_PATH" -ov -format UDZO "$DMG_PATH"
fi

if [[ "$SKIP_NOTARIZE" == false ]]; then
  echo "▸ Notarizing DMG..."
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_APP_PASSWORD}" \
    --wait
  xcrun stapler staple "$DMG_PATH"
fi

echo ""
echo "✓ Done: $DMG_PATH"
