#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
SHA256="${2:-}"
TAP_REPO="${TAP_REPO:-getlost01/homebrew-deepthink}"
TAP_BRANCH="${TAP_BRANCH:-main}"

if [[ -z "$VERSION" || -z "$SHA256" ]]; then
  echo "Usage: update-homebrew-cask.sh <version> <sha256>"
  exit 1
fi

if [[ -z "${TAP_TOKEN:-}" ]]; then
  echo "::error::TAP_TOKEN is not set. Add a fine-grained PAT with Contents: Read and write on getlost01/homebrew-deepthink as repository secret TAP_TOKEN."
  exit 1
fi

TAP_DIR="$(mktemp -d)"
trap 'rm -rf "$TAP_DIR"' EXIT

git config --global user.name "github-actions[bot]"
git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"

git clone --depth=1 --branch "$TAP_BRANCH" \
  "https://x-access-token:${TAP_TOKEN}@github.com/${TAP_REPO}.git" \
  "$TAP_DIR"

cp "$ROOT/homebrew/deepthink.rb" "$TAP_DIR/Casks/deepthink.rb"

if [[ "$(uname -s)" == "Darwin" ]]; then
  sed -i '' \
    -e "s/version \"[^\"]*\"/version \"${VERSION}\"/" \
    -e "s/sha256 \"[^\"]*\"/sha256 \"${SHA256}\"/" \
    "$TAP_DIR/Casks/deepthink.rb"
else
  sed -i \
    -e "s/version \"[^\"]*\"/version \"${VERSION}\"/" \
    -e "s/sha256 \"[^\"]*\"/sha256 \"${SHA256}\"/" \
    "$TAP_DIR/Casks/deepthink.rb"
fi

if ! grep -q "version \"${VERSION}\"" "$TAP_DIR/Casks/deepthink.rb"; then
  echo "::error::Failed to set cask version in deepthink.rb"
  exit 1
fi

if ! grep -q "sha256 \"${SHA256}\"" "$TAP_DIR/Casks/deepthink.rb"; then
  echo "::error::Failed to set cask sha256 in deepthink.rb"
  exit 1
fi

cd "$TAP_DIR"
git add Casks/deepthink.rb

if git diff --cached --quiet; then
  echo "Homebrew cask already at version ${VERSION} with matching sha256 — nothing to push."
  exit 0
fi

git commit -m "chore: release v${VERSION}"
git push origin "$TAP_BRANCH"

echo "Homebrew cask updated: ${TAP_REPO}@${TAP_BRANCH} → v${VERSION}"
