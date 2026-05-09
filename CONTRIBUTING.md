# Contributing to DeepThink

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| macOS | 14.0+ | — |
| Xcode | 16+ | App Store |
| XcodeGen | latest | `brew install xcodegen` |
| Bun | latest | `brew install oven-sh/bun/bun` |
| Claude CLI | latest | [docs.anthropic.com](https://docs.anthropic.com/claude/docs/claude-cli) |
| lefthook | latest | `brew install lefthook` |
| SwiftLint | latest | `brew install swiftlint` (optional — build warns if missing) |
| SwiftFormat | latest | `brew install swiftformat` (optional — build warns if missing) |

## Build from Source

```bash
git clone https://github.com/aagam-headout/deepthink
cd deepthink

# 1. Install git hooks
lefthook install

# 2. Build CLI tools (produces deepthink + deepthink-mcp binaries)
cd cli && bun install && bun run build:all && cd ..

# 2. Generate Xcode project
xcodegen generate

# 3. Open in Xcode and run
open DeepThink.xcodeproj
```

The app auto-installs the CLI binaries to `~/.local/bin/` on first launch.

## Project Structure

```text
deepthink/
├── DeepThink/                  # Swift app
│   ├── Views/                  # SwiftUI views (by feature)
│   ├── Services/               # Business logic singletons
│   ├── Models/                 # SwiftData models
│   ├── Utilities/              # Helpers, constants, extensions
│   └── Views/Shared/           # Design system + reusable components
├── cli/                        # Bun/TypeScript CLI
│   └── src/
│       ├── index.ts            # Entry point + command routing
│       ├── mcp-server.ts       # MCP server (45 tools)
│       ├── core/               # Context engine + embedding
│       ├── agents/             # Planner, executor, writer agents
│       └── tools/              # Tool implementations
├── docs/                       # Documentation
│   ├── ARCHITECTURE.md
│   ├── storage.md
│   ├── shortcuts.md
│   └── features/              # Per-feature docs
├── project.yml                 # XcodeGen config (source of truth for Xcode project)
└── DeepThink.xcodeproj         # Generated — do not edit directly
```

## Development Setup

### Environment Variables

```bash
export ANTHROPIC_API_KEY=your_key_here        # required for AI features
export DEEPTHINK_SEARCH_API=your_serper_key   # optional: web search
```

### CLI Development

```bash
cd cli
bun install
bun run dev          # watch mode (if available)
bun run build:all    # build both deepthink + deepthink-mcp binaries
```

### Swift App Development

Open `DeepThink.xcodeproj` in Xcode. Regenerate after changing `project.yml`:

```bash
xcodegen generate
```

**Code Signing:** Xcode will prompt for your Apple account on first build. Use "Automatically manage signing" with your personal team for local development — no distribution certificate needed.

## Design System

All UI must use `DeepThink/Views/Shared/DesignSystem.swift`:

- Colors: `DS.Colors.*`
- Typography: `DS.Font.*`
- Spacing: `DS.Spacing.*`
- Every clickable element needs `.buttonStyle(.plainPointer)` or equivalent

See [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) for full reference.

## Code Style

- Swift 6 strict concurrency — no data races
- No comments unless the *why* is non-obvious
- Keep views small — extract private subviews in the same file
- Services are `@Observable` singletons via `.shared`
- Prefer editing existing files over creating new ones

## Submitting Changes

1. Fork the repo, create a branch from `main`
2. Make your changes
3. Test: build the app and exercise the affected feature manually
4. Open a PR with a clear description of what changed and why

For large changes, open an issue first to discuss the approach.

## Adding MCP Tools

New tools go in `cli/src/mcp-server.ts`. Each tool needs:
- A unique name (snake_case)
- Input schema via Zod
- Handler function
- Entry in the tool category table in [docs/features/mcp-integration.md](docs/features/mcp-integration.md)

Rebuild after changes: `cd cli && bun run build:all`.
