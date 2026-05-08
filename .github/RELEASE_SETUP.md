# Release Setup

Releases are **manual** right now: build unsigned on your Mac, zip **DeepThink.app**, upload to GitHub Releases. No CI secrets or notarization workflow.

---

## Unsigned release (GitHub Releases)

Use when you **do not** use Apple Developer signing for distribution. Gatekeeper may block until the user chooses **Right-click → Open**.

### Build on your Mac

```bash
cd cli && bash build.sh && cd ..
xcodegen generate
mkdir -p build
xcodebuild archive \
  -scheme DeepThink -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath build/DeepThink.xcarchive \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO \
  | xcpretty 2>/dev/null || cat
```

Zip the app:

```bash
APP="build/DeepThink.xcarchive/Products/Applications/DeepThink.app"
ditto -c -k --sequesterRsrc --keepParent "$APP" DeepThink-macOS.zip
```

### Publish

GitHub → **Releases** → **Draft a new release** → tag (e.g. `v1.0.0`) → attach **DeepThink-macOS.zip** → in the notes say first launch: **Right-click the app → Open**.

---

## Optional: notarized DMG (local only)

With an Apple Developer account you can run **`scripts/notarize.sh`** on your machine (not via GitHub Actions). That produces a stapled DMG you can attach to a release the same way.
