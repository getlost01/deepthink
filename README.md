# DeepThink

**Local-first workspace and AI memory layer for macOS** — native app with notes, tasks, projects, and a knowledge graph, plus a 51-tool MCP server and CLI that plug any AI agent into your corpus. Your data stays under `~/DeepThink/`. **MIT licensed.**

[![CI](https://github.com/getlost01/deepthink/actions/workflows/ci.yml/badge.svg)](https://github.com/getlost01/deepthink/actions/workflows/ci.yml?query=branch%3Amain)
[![Latest release](https://img.shields.io/github/v/release/getlost01/deepthink?logo=github)](https://github.com/getlost01/deepthink/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-7cb342)](LICENSE)
[![Contributing](https://img.shields.io/badge/contributing-CONTRIBUTING-0366d6)](CONTRIBUTING.md)

```bash
brew tap getlost01/deepthink && brew install --cask deepthink
```

> macOS 14+ · [Download zip →](https://github.com/getlost01/deepthink/releases/latest)

<p align="center">
  <img src="web-app/public/images/settings.png" alt="DeepThink — settings and workspace overview" width="720" />
</p>

<details>
<summary><strong>More screenshots</strong></summary>

<p align="center"><img src="web-app/public/images/workspace.png" alt="Workspace — projects, notes, tasks" width="640" /></p>
<p align="center"><img src="web-app/public/images/knowledge.png" alt="Knowledge base" width="640" /></p>
<p align="center"><img src="web-app/public/images/context-graph.png" alt="Context graph — semantic and wiki-link connections" width="640" /></p>
<p align="center"><img src="web-app/public/images/ai-assistant.png" alt="AI assistant" width="640" /></p>
<p align="center"><img src="web-app/public/images/reminders.png" alt="Reminders" width="640" /></p>
<p align="center"><img src="web-app/public/images/integrations.png" alt="Integrations panel" width="640" /></p>
<p align="center"><img src="web-app/public/images/terminal.png" alt="Built-in terminal" width="640" /></p>
<p align="center"><img src="web-app/public/images/recent.png" alt="Recent activity" width="640" /></p>

</details>

---

## What you can do with DeepThink

| Scenario | How DeepThink helps |
|---|---|
| **Give Cursor, Claude Code, or Windsurf a persistent memory** | Connect the MCP server once — agents call `knowledge_context` or `smart_query` instead of starting cold every session |
| **Capture anything and find it later** | Ingest URLs, files, Obsidian vaults, RSS feeds, and clipboard clips — all indexed with on-device hybrid search |
| **Manage projects with AI-aware tasks** | Kanban board with priorities, story points, and due dates — queryable by any agent through MCP or the CLI |
| **Build custom AI agents and skills** | Create personas with scoped knowledge, assign slash commands (`/standup`, `/summarize`), and auto-inject rules per project |
| **Write notes that link to everything** | Rich markdown, wiki-style backlinks, version history, and a force-directed context graph that maps how ideas connect |
| **Automate your workflow from the terminal** | CLI hooks, cron jobs, git hooks — model-agnostic, no Claude required |

---

## Feature highlights

### Workspace & productivity

| | |
|--|--|
| **Projects** | Group notes, tasks, and context — shared across the app, MCP, and CLI |
| **Notes** | Rich markdown editor, wiki backlinks, version history |
| **Tasks** | Kanban board with priorities, story points, and due dates |
| **Reminders** | Timed alerts with native macOS notifications |

### Knowledge base & capture

| | |
|--|--|
| **Capture** | URLs, files, clipboard, RSS feeds, Obsidian vault import, and custom scripts |
| **Hybrid RAG** | BM25 keyword + Apple NLEmbedding semantic search fused via RRF — fully on-device, no cloud index |
| **Context graph** | Force-directed view of semantic + wiki-link connections across your entire knowledge base |
| **Buckets & tags** | Organize, deduplicate, and namespace your corpus |

### AI chat, agents & skills

| | |
|--|--|
| **AI chat** | Streaming Claude with full workspace awareness, branch edits, and session compaction |
| **Agents** | Custom personas with scoped knowledge, model selection, and assigned skills |
| **Skills** | Slash commands (`/standup`, `/summarize`, custom) with template and context injection |
| **Rules** | Auto-injected instructions per project or globally — consistent tone and format without manual prompting |

> AI chat, agents, skills, and rules run via the local **Claude CLI** (requires `claude login`). The MCP server and CLI are fully model-agnostic.

### MCP server & CLI — any agent, no Claude required

| | |
|--|--|
| **51 MCP tools** | `smart_query`, `unified_search`, `workspace_*`, `knowledge_*`, and more — with a `readonly` flag on every tool |
| **Works with any agent** | Claude Code, Cursor, VS Code Copilot, Windsurf, Continue, shell scripts, cron jobs |
| **CLI** | `deepthink ask`, `note`, `task`, `search`, `context` — scriptable workspace access from any terminal |
| **Live sync** | CLI and MCP writes sync to the running app in real time via Darwin notification |

### macOS app

| | |
|--|--|
| **⌘K command palette** | Jump anywhere, run skills, and fuzzy-find any entity across your workspace |
| **Built-in terminal** | Multi-tab terminal with AI output analysis |
| **Quick capture** | Floating panel for notes, knowledge, or tasks — open from the menu or Quick Search |
| **TipTap editor** | Rich text with Markdown, embeds, and wiki backlinks |

---

## Table of contents

- [What you can do](#what-you-can-do-with-deepthink)
- [Feature highlights](#feature-highlights)
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

### Option A — Homebrew (recommended)

```bash
brew tap getlost01/deepthink
brew install --cask deepthink
```

First launch: **Right-click → Open**, or clear quarantine manually:

```bash
xattr -rd com.apple.quarantine /Applications/DeepThink.app
```

### Option B — Download from GitHub Releases

1. Download **`DeepThink-macOS.zip`** from [Releases](https://github.com/getlost01/deepthink/releases/latest)
2. Unzip and drag **DeepThink.app** to Applications
3. First launch: **Right-click → Open**
4. If macOS still blocks, clear quarantine:

```bash
# App in Applications
xattr -cr /Applications/DeepThink.app
# App still in Downloads
xattr -cr ~/Downloads/DeepThink.app
```

5. Launch DeepThink — the CLI and MCP server install automatically on first launch
6. Install Claude CLI from [claude.ai/code](https://claude.ai/code) and run `claude login` to enable in-app AI

### Option C — Build from source

**Prerequisites:** macOS 14+, Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), [Bun](https://bun.sh), [Claude CLI](https://claude.ai/code)

```bash
git clone https://github.com/getlost01/deepthink
cd deepthink

# Build CLI + MCP binaries
cd cli && bash build.sh && cd ..

# Generate and open Xcode project
xcodegen generate
open DeepThink.xcodeproj
```

Hit **Run** (⌘R) in Xcode. On first launch the app copies the CLI binaries to `~/.local/bin/` and registers the MCP server with Claude.

---

## Using the CLI

After first launch, `deepthink` is available in your terminal:

```bash
deepthink status                                  # workspace overview
deepthink ask "what's due this week?"
deepthink note "meeting with design team"
deepthink task "fix login bug" --project api
deepthink knowledge capture https://some-article.com
deepthink search "vector embeddings"
deepthink context                                 # current workspace context for any agent
```

Full command reference: [docs/cli/README.md](docs/cli/README.md)

---

## MCP Server

DeepThink ships a full MCP server (`deepthink-mcp`) installed to `~/.local/bin/deepthink-mcp`.

**Use with Claude Code:**

```bash
claude mcp add deepthink -- ~/.local/bin/deepthink-mcp
```

**Use with Cursor / VS Code / Windsurf:**

```json
{
  "mcpServers": {
    "deepthink": {
      "command": "/Users/yourname/.local/bin/deepthink-mcp"
    }
  }
}
```

The MCP server works with **any MCP-compatible AI agent** — Claude is not required. 51 tools across `smart_query`, `unified_search`, `workspace_*`, and `knowledge_*` namespaces, each carrying a `readonly` flag so agents can distinguish safe reads from mutations.

Full tool reference: [docs/mcp-integration.md](docs/mcp-integration.md)

---

## Architecture

```text
DeepThink/
├── DeepThinkApp.swift         # app entry point, service startup, onboarding
├── Models/                    # SwiftData models (Note, Task, Project, Reminder, …)
├── Services/                  # 26 @Observable singletons
│   ├── ClaudeService          # Claude CLI subprocess + streaming JSON
│   ├── ContextEngine          # RAG retrieval, workspace context packaging
│   ├── KnowledgeService       # knowledge entry CRUD + file layout
│   ├── VectorStore            # SQLite vector index (Apple NLEmbedding)
│   ├── MCPService             # MCP subprocess management + config
│   ├── InstallationManager    # first-launch CLI/MCP install + PATH setup
│   └── …
├── Views/                     # SwiftUI views organized by feature
│   ├── Shared/                # design system, reusable components
│   ├── Workspace/             # projects, notes, tasks
│   ├── Knowledge/             # knowledge browser, Obsidian import
│   ├── Chat/                  # AI chat, history, bubbles
│   ├── Settings/              # Claude, general, backup settings
│   └── …
└── Utilities/                 # constants, extensions, error types

cli/
├── src/index.ts               # CLI entrypoint (Bun)
├── src/mcp-server.ts          # MCP server (stdio transport; 51 tools in src/tools/*)
├── src/agents/                # 13 autonomous agents (research, planner, react, writer, …)
├── src/memory/                # agent memory manager + compressor
├── src/tools/                 # workspace, knowledge, config, analytics, search tools
└── src/core/                  # db, embedding, vector-store, context-engine, llm

~/DeepThink/                   # all user data — no iCloud, no backend
├── data/deepthink.store       # SwiftData SQLite database
├── data/vectors.db            # vector embeddings (SQLite)
├── knowledge/                 # knowledge entries as markdown files
└── logs/                      # app + CLI logs
```

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| App | Swift 5 / SwiftUI / AppKit / macOS 14+ |
| Persistence | SwiftData + SQLite (WAL mode) |
| Embeddings | Apple NaturalLanguage framework (`NLEmbedding`) — fully on-device |
| Terminal | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) |
| Updates | [Sparkle](https://github.com/sparkle-project/Sparkle) 2 |
| Editor | TipTap (ProseMirror) compiled to a WKWebView bundle |
| CLI / MCP | Bun + TypeScript, compiled to single binaries |
| AI | Anthropic Claude CLI (streaming JSON, local subprocess) |

---

## Contributing

DeepThink is **open source (MIT)**. Read [CONTRIBUTING.md](CONTRIBUTING.md) first.

```bash
git clone https://github.com/getlost01/deepthink
cd deepthink
cd cli && bash build.sh && cd ..
xcodegen generate
open DeepThink.xcodeproj
```

Code style: **SwiftFormat** (`.swiftformat`) and **SwiftLint** (`.swiftlint.yml`) run as Xcode pre-build scripts.

```bash
brew install swiftformat swiftlint
```

All new UI must use `DS.*` tokens from `DeepThink/Views/Shared/DesignSystem.swift` — no raw colors, fonts, or spacing values. See [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).

**Issues & good first issues:** [github.com/getlost01/deepthink/issues](https://github.com/getlost01/deepthink/issues)

---

## Documentation

| | |
|-|-|
| [App Features](docs/app/README.md) | Workspace, knowledge, AI chat, terminal, quick capture |
| [CLI Reference](docs/cli/README.md) | All `deepthink` commands, agent system |
| [MCP Integration](docs/mcp-integration.md) | 51 MCP tools, external client setup |
| [Architecture](docs/ARCHITECTURE.md) | System design, service layer, data flow |
| [RAG Pipeline](docs/rag-pipeline.md) | Hybrid BM25 + semantic retrieval |
| [Storage](docs/storage.md) | Data directory layout, database schema |
| [Keyboard Shortcuts](docs/shortcuts.md) | Full shortcuts reference |
| [Contributing](CONTRIBUTING.md) | Build guide, code style, PR workflow |
| [Security](SECURITY.md) | Reporting vulnerabilities |

---

## License

[MIT](LICENSE)
