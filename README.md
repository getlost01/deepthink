# DeepThink

AI-powered knowledge workspace for macOS. Organize projects, capture knowledge from anywhere, and chat with AI that actually knows your work.

Built with SwiftUI + SwiftData (native macOS app) and a Bun/TypeScript CLI. All data stays local — no cloud sync.

## Features

| Feature | Description |
|---------|-------------|
| **Workspace** | Projects, notes, tasks with rich markdown editing and kanban board |
| **Knowledge Base** | Multi-source capture (web, files, clipboard, RSS, scripts, Obsidian) organized into buckets |
| **AI Chat** | Streaming chat with Claude, conversation history, edit branching, auto-compaction |
| **Hybrid RAG** | BM25 keyword + semantic vector search — AI finds relevant knowledge automatically |
| **AI Agents** | Custom personas with knowledge scopes, model selection, and skill assignments |
| **Skills & Rules** | Slash-command skills with template variables, context-aware rules with structured triggers |
| **Quick Capture** | `Cmd+Shift+D` from any app — floating panel to capture notes, knowledge, or tasks |
| **MCP Server** | 47-tool MCP server for Claude Code, Cursor, VS Code, and any MCP-compatible client |
| **Terminal** | Built-in multi-tab terminal with AI output analysis |
| **Command Palette** | `Cmd+K` quick access to all commands, navigation, and skills |
| **Obsidian Import** | One-click vault import with wiki-link conversion and dedup |
| **Data Collection** | Automated capture from URLs, RSS feeds, folders, and custom scripts |
| **Proactive Insights** | AI scans workspace every 4h — flags overdue, stale, and blocked items |

## Quick Start

**Prerequisites:** macOS 14+, Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), [Bun](https://bun.sh), [Claude CLI](https://docs.anthropic.com/claude/docs/claude-cli)

```bash
git clone https://github.com/aagam-headout/deepthink
cd deepthink

# Build CLI tools
cd cli && bun install && bun run build:all && cd ..

# Generate Xcode project and open
xcodegen generate && open DeepThink.xcodeproj
```

Set your API key before running:

```bash
export ANTHROPIC_API_KEY=your_key_here
```

The app auto-installs CLI binaries (`deepthink`, `deepthink-mcp`) to `~/.local/bin/` on first launch.

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed build instructions, code style, and how to submit changes.

## Documentation

| | |
|-|-|
| [App Features](docs/app/README.md) | Workspace, knowledge, AI chat, terminal, quick capture |
| [CLI](docs/cli/README.md) | All `deepthink` commands, agent system, MCP server |
| [Architecture](docs/ARCHITECTURE.md) | System design, service layer, data flow |
| [RAG Pipeline](docs/rag-pipeline.md) | Hybrid BM25 + semantic retrieval |
| [MCP Integration](docs/mcp-integration.md) | 45-tool MCP server, external client setup |
| [Storage](docs/storage.md) | Data directory layout, database schema |
| [Shortcuts](docs/shortcuts.md) | Keyboard shortcuts reference |
| [Contributing](CONTRIBUTING.md) | Build guide, code style, PR workflow |
| [Security](SECURITY.md) | Reporting vulnerabilities |

## License

[MIT](LICENSE)
