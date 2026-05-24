#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TAG="${1:-${GITHUB_REF_NAME:-}}"
if [[ -z "$TAG" ]]; then
  echo "Usage: verify-version.sh <tag>   e.g. v1.0.1"
  exit 1
fi

VERSION="${TAG#v}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  echo "Invalid tag format: $TAG (expected vMAJOR.MINOR.PATCH)"
  exit 1
fi

MARKETING="$(grep 'MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
PKG="$(grep '"version"' cli/package.json | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"

echo "Tag version:        $VERSION"
echo "project.yml:        $MARKETING"
echo "cli/package.json:   $PKG"

if [[ "$VERSION" != "$MARKETING" ]]; then
  echo "::error::Tag $TAG does not match MARKETING_VERSION in project.yml ($MARKETING)"
  exit 1
fi

if [[ "$VERSION" != "$PKG" ]]; then
  echo "::error::Tag $TAG does not match cli/package.json version ($PKG)"
  exit 1
fi

echo "Version check passed."
