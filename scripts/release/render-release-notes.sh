#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
SHA256="${2:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: render-release-notes.sh <version> [sha256]"
  exit 1
fi

NOTES_FILE="docs/releases/v${VERSION}.md"
if [[ -f "$NOTES_FILE" ]]; then
  cat "$NOTES_FILE"
  if [[ -n "$SHA256" ]] && ! grep -q "$SHA256" "$NOTES_FILE"; then
    echo ""
    echo "---"
    echo "**SHA256:** \`$SHA256\`"
  fi
  exit 0
fi

cat <<EOF
## DeepThink ${VERSION}

### Install via Homebrew
\`\`\`bash
brew tap getlost01/deepthink
brew update
brew upgrade --cask deepthink
\`\`\`

### Manual install
Download \`DeepThink-${VERSION}.zip\`, unzip, drag to \`/Applications\`.
Then run once to clear quarantine:
\`\`\`bash
xattr -rd com.apple.quarantine /Applications/DeepThink.app
\`\`\`
EOF

if [[ -n "$SHA256" ]]; then
  echo ""
  echo "---"
  echo "**SHA256:** \`$SHA256\`"
fi
