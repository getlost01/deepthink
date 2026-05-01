#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== DeepThink CLI Build ==="

if ! command -v bun &>/dev/null; then
    echo "Error: bun not found. Install via: curl -fsSL https://bun.sh/install | bash"
    exit 1
fi

echo "Installing dependencies..."
bun install

mkdir -p out

echo "Building standalone binary..."
bun build src/index.ts --compile --outfile out/deepthink

echo "Binary size: $(du -h out/deepthink | cut -f1)"
echo ""
echo "Build complete: $SCRIPT_DIR/out/deepthink"
echo "Test: ./out/deepthink status"
