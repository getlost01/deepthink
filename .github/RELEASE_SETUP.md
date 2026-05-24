# Release & distribution

Releases are automated via GitHub Actions when you push a version tag.

## Quick release (recommended)

1. Bump versions in `project.yml`, `cli/package.json`, and `homebrew/deepthink.rb` (version only; SHA is updated by CI).
2. Add release notes at `docs/releases/vX.Y.Z.md` (optional but recommended).
3. Commit and push to `main`.
4. Tag and push:

```bash
git tag -a v1.0.2 -m "DeepThink 1.0.2"
git push origin v1.0.2
```

The **Release** workflow will:

- Verify tag matches `project.yml` and `cli/package.json`
- Build CLI + MCP and bundle them into the app
- Build Release macOS app, ad-hoc sign, zip as `DeepThink-X.Y.Z.zip`
- Publish GitHub Release (notes from `docs/releases/vX.Y.Z.md` when present)
- Update `getlost01/homebrew-deepthink` cask (stable tags only)

## Required secret

| Secret | Purpose |
|--------|---------|
| `TAP_TOKEN` | Fine-grained PAT with **Contents: Read and write** on `getlost01/homebrew-deepthink` |

Without `TAP_TOKEN`, the GitHub release still publishes; the Homebrew job fails with a clear error.

Create the token at GitHub → Settings → Developer settings → Fine-grained tokens → Repository access: `homebrew-deepthink` only.

## Manual re-run

Actions → **Release** → **Run workflow** → enter tag (e.g. `v1.0.1`) to rebuild and republish that tag.

## Local dry run

```bash
bash scripts/release/verify-version.sh v1.0.1
bash scripts/release/build-macos-app.sh
bash scripts/release/package-zip.sh v1.0.1
```

## User install

```bash
brew tap getlost01/deepthink
brew update
brew upgrade --cask deepthink
```

Always run `brew update` before upgrade so the tap picks up new cask versions.

## Optional: notarized DMG

For Apple-notarized distribution, run `scripts/notarize.sh` locally and attach the DMG to the release manually. CI ships unsigned/ad-hoc-signed builds suitable for Homebrew + direct zip download.
