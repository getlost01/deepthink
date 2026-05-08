# DeepThink

A local-first AI workspace for macOS. Projects, notes, tasks, and a knowledge base — combined with Claude AI that has full context of everything you're working on. All data stays on your machine.

> **Download:** [Latest Release →](https://github.com/aagam-headout/deepthink/releases/latest) — zip of the app (unsigned); first open: **Right-click → Open** · macOS 14+

---

## What it does

| | |
|--|--|
| **Workspace** | Projects, rich markdown notes with backlinks and version history, kanban task board, and timed reminders |
| **Knowledge Base** | Capture from any source — URLs, files, clipboard, RSS feeds, Obsidian vaults, or custom scripts. Organized into buckets, searchable instantly |
| **Hybrid RAG** | Every query runs BM25 keyword + semantic vector search (Apple NLEmbedding). AI gets the right context automatically — you never have to paste things in |
| **AI Chat** | Streaming Claude with full workspace context, conversation history, edit branching, and auto-compaction for long sessions |
| **AI Agents** | Custom personas with their own knowledge scopes, model selection, and skill assignments |
| **Skills** | Slash-command automations (`/summarize`, `/standup`, etc.) with template variables and context injection |
| **Rules** | Context-aware instructions that activate automatically — e.g. "when I'm in Project X, always reply concisely" |
| **MCP Server** | 47-tool MCP server that gives Claude Code, Cursor, VS Code, and any MCP-compatible client direct access to your workspace |
| **Terminal** | Built-in multi-tab terminal with AI output analysis |
| **Quick Capture** | Option+Space from any app — floating panel to save notes, knowledge, or tasks without switching windows |
| **Command Palette** | Cmd+K — navigate anywhere, run skills, and find anything |
| **Context Graph** | Force-directed graph of semantic and wiki-link connections across your workspace |

---

## Installing

### Option A — Download from GitHub Releases (zip, unsigned)

1. Download **`DeepThink-macOS.zip`** (or the release zip) from [Releases](https://github.com/aagam-headout/deepthink/releases/latest)
2. Unzip and drag **DeepThink.app** to Applications
3. First launch: **Right-click → Open** (macOS may show an unidentified developer warning)
4. Launch DeepThink — the app installs the CLI and MCP server automatically on first launch
5. Install Claude CLI from [claude.ai/code](https://claude.ai/code) and run `claude login`

That's it. The AI chat is ready.

### Option B — Build from source

**Prerequisites**

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [Bun](https://bun.sh) — `curl -fsSL https://bun.sh/install | bash`
- [Claude CLI](https://claude.ai/code) — install and run `claude login`

**Build**

```bash
git clone https://github.com/aagam-headout/deepthink
cd deepthink

# Build CLI + MCP binaries
cd cli && bash build.sh && cd ..

# Generate Xcode project
xcodegen generate

# Open and run in Xcode
open DeepThink.xcodeproj
```

Hit **Run** (⌘R) in Xcode. On first launch the app copies the CLI binaries to `~/.local/bin/` and registers the MCP server with Claude.

---

## Using the CLI

After first launch, `deepthink` is available in your terminal:

```bash
deepthink status              # workspace overview
deepthink ask "what's due this week?"
deepthink note "meeting with design team"
deepthink task "fix login bug" --project api
deepthink knowledge capture https://some-article.com
deepthink search "vector embeddings"
deepthink context             # current workspace context
```

Full command reference: [docs/cli/README.md](docs/cli/README.md)

---

## MCP Server

DeepThink ships a full MCP server (`deepthink-mcp`) automatically registered at:

```
~/.local/bin/deepthink-mcp
```

**Use with Claude Code:**
```bash
claude mcp add deepthink -- ~/.local/bin/deepthink-mcp
```

**Use with Cursor / VS Code:**
```json
{
  "mcpServers": {
    "deepthink": {
      "command": "/Users/yourname/.local/bin/deepthink-mcp"
    }
  }
}
```

The MCP server exposes your tasks, notes, projects, reminders, and knowledge base as resources and tools — so any MCP-compatible AI client can read and write your workspace.

---

## Architecture

```
DeepThink/
├── DeepThinkApp.swift         # app entry point, service startup, onboarding
├── Models/                    # SwiftData models (Note, Task, Project, Reminder, ...)
├── Services/                  # 23 @Observable singletons
│   ├── ClaudeService          # Claude CLI subprocess + streaming JSON
│   ├── ContextEngine          # RAG retrieval, workspace context packaging
│   ├── KnowledgeService       # knowledge entry CRUD + file layout
│   ├── VectorStore            # SQLite vector index (Apple NLEmbedding)
│   ├── MCPService             # MCP subprocess management + config
│   ├── InstallationManager    # first-launch CLI/MCP install + PATH setup
│   └── ...
├── Views/                     # SwiftUI views organized by feature
│   ├── Shared/                # design system, reusable components
│   ├── Workspace/             # projects, notes, tasks
│   ├── Knowledge/             # knowledge browser, Obsidian import
│   ├── Chat/                  # AI chat, history, bubbles
│   ├── Settings/              # Claude, general, backup settings
│   └── ...
└── Utilities/                 # constants, extensions, error types

cli/
├── src/index.ts               # CLI entrypoint (Bun)
├── src/mcp-server.ts          # MCP server (47 tools, stdio transport)
├── src/agents/                # research, schedule, insight agents
├── src/tools/                 # workspace, knowledge, config tools
└── src/core/                  # db access (reads SwiftData store readonly)

~/DeepThink/                   # user data directory
├── data/deepthink.store       # SwiftData SQLite database
├── data/vectors.db            # vector embeddings (SQLite)
├── knowledge/                 # knowledge entries as markdown files
└── logs/                      # app + CLI logs
```

All data lives in `~/DeepThink/`. No iCloud, no backend.

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| App | Swift 5 / SwiftUI / AppKit / macOS 14+ |
| Persistence | SwiftData + SQLite (vectors) |
| Embeddings | Apple NaturalLanguage framework (`NLEmbedding`) |
| Terminal | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) |
| Updates | [Sparkle](https://github.com/sparkle-project/Sparkle) 2 |
| Editor | TipTap (ProseMirror) compiled to a WKWebView bundle |
| CLI / MCP | Bun + TypeScript, compiled to single binaries |
| AI | Anthropic Claude CLI (streaming JSON, local subprocess) |

---

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

**Quick contributor setup:**

```bash
git clone https://github.com/aagam-headout/deepthink
cd deepthink
cd cli && bash build.sh && cd ..
xcodegen generate
open DeepThink.xcodeproj
```

Code style is enforced by SwiftFormat (`.swiftformat`) and SwiftLint (`.swiftlint.yml`), both run as Xcode pre-build scripts. Install them with:

```bash
brew install swiftformat swiftlint
```

The design system is in `DeepThink/Views/Shared/DesignSystem.swift`. All new UI must use `DS.*` tokens — no raw colors, fonts, or spacing values. See [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) for the full reference.

**Open issues and good first issues:** [github.com/aagam-headout/deepthink/issues](https://github.com/aagam-headout/deepthink/issues)

---

## Documentation

| | |
|-|-|
| [App Features](docs/app/README.md) | Workspace, knowledge, AI chat, terminal, quick capture |
| [CLI Reference](docs/cli/README.md) | All `deepthink` commands, agent system |
| [MCP Integration](docs/mcp-integration.md) | MCP server tools, external client setup |
| [Architecture](docs/ARCHITECTURE.md) | System design, service layer, data flow |
| [RAG Pipeline](docs/rag-pipeline.md) | Hybrid BM25 + semantic retrieval |
| [Storage](docs/storage.md) | Data directory layout, database schema |
| [Keyboard Shortcuts](docs/shortcuts.md) | Full shortcuts reference |
| [Contributing](CONTRIBUTING.md) | Build guide, code style, PR workflow |
| [Security](SECURITY.md) | Reporting vulnerabilities |

---

## License

[MIT](LICENSE)
