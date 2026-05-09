# DeepThink

**Local-first AI workspace for macOS** — projects, notes, tasks, and a personal knowledge base with **Claude** and **hybrid RAG**. Your data stays on your machine. **MIT licensed** and open to contributions.

DeepThink is one **native SwiftUI** surface for juggling **projects**, **notes**, **tasks**, and **reminders** next to capture-friendly **knowledge**—plus **⌘K** navigation, and a built-in **terminal**. The same workspace backs the **`deepthink` CLI** and the shipped **MCP server**, so terminals and MCP-capable editors can read and update what the app manages. Persistence lives under **`~/DeepThink/`** (SwiftData plus on-disk markdown and embeddings); conversational AI routes through Anthropic's **Claude CLI** (`claude login`) alongside local hybrid retrieval (**BM25** + semantic search).

DeepThink is under active development—contributions are welcome and help shape it into a more robust workspace ↔ knowledge tool.

[![CI](https://github.com/aagam-headout/deepthink/actions/workflows/ci.yml/badge.svg)](https://github.com/aagam-headout/deepthink/actions/workflows/ci.yml?query=branch%3Amain)
[![Latest release](https://img.shields.io/github/v/release/aagam-headout/deepthink?logo=github)](https://github.com/aagam-headout/deepthink/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-7cb342)](LICENSE)
[![Contributing](https://img.shields.io/badge/contributing-CONTRIBUTING-0366d6)](CONTRIBUTING.md)

> **Download:** [Latest release →](https://github.com/aagam-headout/deepthink/releases/latest) (unsigned `.zip`; first launch: **Right-click → Open**) · macOS **14+**

<p align="center">
  <img src="web-app/public/images/settings.png" alt="DeepThink settings" width="720" />
</p>

<details>
<summary><strong>More screenshots(Full Flow)</strong></summary>

<p align="center"><img src="web-app/public/images/recent.png" alt="Recent activity" width="640" /></p>
<p align="center"><img src="web-app/public/images/workspace.png" alt="Workspace" width="640" /></p>
<p align="center"><img src="web-app/public/images/knowledge.png" alt="Knowledge base" width="640" /></p>
<p align="center"><img src="web-app/public/images/context-graph.png" alt="Context graph" width="640" /></p>
<p align="center"><img src="web-app/public/images/ai-assistant.png" alt="AI assistant" width="640" /></p>
<p align="center"><img src="web-app/public/images/reminders.png" alt="Reminders" width="640" /></p>
<p align="center"><img src="web-app/public/images/integrations.png" alt="Integrations" width="640" /></p>
<p align="center"><img src="web-app/public/images/terminal.png" alt="Built-in terminal" width="640" /></p>

</details>

---

## Features at a glance

### Workspace & productivity

| | |
|--|--|
| **Projects** | Group notes, tasks, and context by project |
| **Notes** | Rich markdown, wiki-style **backlinks**, **version history** |
| **Tasks** | **Kanban** board, priorities, story points, due dates |
| **Reminders** | Timed reminders with **native macOS notifications** |

### Knowledge base & capture

| | |
|--|--|
| **Capture** | URLs, files, clipboard, RSS, **Obsidian** vault import, scripts |
| **Organization** | **Buckets**, tags, dedup-aware storage |
| **Search** | Instant search across workspace + knowledge |

### AI & context (no copy-paste churn)

| | |
|--|--|
| **Hybrid RAG** | **BM25** keyword + **semantic** vector search (Apple **NLEmbedding**) so the assistant sees the *right* context |
| **AI chat** | Streaming Claude with full workspace awareness, history, branch edits, session compaction |
| **Agents** | Custom personas: knowledge scope, models, assigned skills |
| **Skills** | Slash commands (`/summarize`, `/standup`, …) with templates & context injection |
| **Rules** | Auto-triggered instructions (e.g. per-project tone or format) |

### Editors & integrations

| | |
|--|--|
| **Built-in terminal** | Multi-tab terminal with **AI output analysis** |
| **MCP server** | Full MCP server ([integration guide](docs/mcp-integration.md)) — **Claude Code**, **Cursor**, **VS Code**, any MCP client can read/write your workspace |
| **CLI** | `deepthink` in the terminal (`ask`, notes, tasks, knowledge, hybrid `context`) — see [CLI docs](docs/cli/README.md) |

### Fast navigation & discovery

| | |
|--|--|
| **Command palette** | **⌘K** — jump anywhere, run skills, fuzzy-find entities |
| **Quick capture** | In-app floating panel for notes, knowledge, or tasks (open via menu or Quick Search) |
| **Context graph** | Force-directed view of **semantic** + **wiki-link** connections |

---

## Table of contents

- [Features at a glance](#features-at-a-glance)
- [Installing](#installing)
- [Using the CLI](#using-the-cli)
- [MCP server](#mcp-server)
- [Architecture](#architecture)
- [Tech stack](#tech-stack)
- [Contributing](#contributing)
- [Documentation](#documentation)
- [License](#license)

---

## Installing

### Option A — Download from GitHub Releases (zip, unsigned)

1. Download **`DeepThink-macOS.zip`** (or the release zip) from [Releases](https://github.com/aagam-headout/deepthink/releases/latest)
2. Unzip and drag **DeepThink.app** to Applications
3. First launch: **Right-click → Open** (macOS may warn about unidentified developer)
4. If macOS still blocks opening, clear quarantine in Terminal:

App still in Downloads

```bash
xattr -cr ~/Downloads/DeepThink.app
```

App already in Applications

```bash
xattr -cr /Applications/DeepThink.app
```

5. Launch DeepThink — the app installs the **CLI** and **MCP** server automatically on first launch
6. Install Claude CLI from [claude.ai/code](https://claude.ai/code) and run `claude login`

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

DeepThink ships a full MCP server (`deepthink-mcp`), installed to:

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

The MCP server exposes tasks, notes, projects, reminders, and the knowledge base as resources and tools for any MCP-compatible client.

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
├── src/mcp-server.ts          # MCP server (stdio transport; tools in src/tools/*)
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

Contributions are welcome. DeepThink is **open source (MIT)**. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

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

The design system is in `DeepThink/Views/Shared/DesignSystem.swift`. All new UI must use `DS.*` tokens — no raw colors, fonts, or spacing values. See [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).

**Issues & good first issues:** [github.com/aagam-headout/deepthink/issues](https://github.com/aagam-headout/deepthink/issues)

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
