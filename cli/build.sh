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

echo "Building CLI binary..."
bun build src/index.ts --compile --outfile out/deepthink

echo "Building MCP server binary..."
bun build src/mcp-server.ts --compile --outfile out/deepthink-mcp

echo "Binary sizes:"
echo "  CLI: $(du -h out/deepthink | cut -f1)"
echo "  MCP: $(du -h out/deepthink-mcp | cut -f1)"
echo ""
echo "Build complete:"
echo "  CLI: $SCRIPT_DIR/out/deepthink"
echo "  MCP: $SCRIPT_DIR/out/deepthink-mcp"
echo ""
echo "Test: ./out/deepthink status"
