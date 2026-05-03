# DeepThink

AI-powered knowledge workspace for macOS. Organize projects, capture knowledge from anywhere, and chat with AI that actually knows your work.

Built with SwiftUI + SwiftData (native macOS) and a Bun/TypeScript CLI.

## Quick Start

### Prerequisites

- macOS 14.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- [Bun](https://bun.sh) (`brew install oven-sh/bun/bun`)
- Claude CLI (`claude` at `~/.local/bin/claude`) — required for all AI features

### Build & Run

```bash
# Generate Xcode project
xcodegen generate

# Build CLI tools
cd cli && bun install && bun run build:all && cd ..

# Build and run app
xcodebuild -project DeepThink.xcodeproj -scheme DeepThink -destination 'platform=macOS' build

# Or open in Xcode
open DeepThink.xcodeproj
```

The app auto-installs CLI binaries (`deepthink`, `deepthink-mcp`) to `~/.local/bin/` on launch.

### CLI Usage

```bash
# Ask AI with workspace context
deepthink ask "What tasks need attention?"

# Run with MCP tools
deepthink run "Create a task called Review PR"

# Manage knowledge
deepthink knowledge list
deepthink knowledge add --url "https://example.com/article"

# Manage agents
deepthink agents list
deepthink agents chat researcher "What do we know about X?"
```

## Features

| Feature | Description |
|---------|-------------|
| **Workspace** | Projects, notes, and tasks with rich markdown editing |
| **Knowledge Base** | Save web pages, files, clipboard, scripts, RSS feeds — all searchable |
| **AI Chat** | Chat with Claude using your knowledge as context |
| **AI Assistants** | Custom AI personas with specialized expertise and knowledge scopes |
| **Automations** | Reusable AI skills (one-click actions) and rules (auto-triggered instructions) |
| **Connections** | MCP server integration — give AI access to external tools |
| **Smart RAG** | TF-IDF indexed retrieval with chunking and token budgeting |
| **Terminal** | Built-in terminal with AI-powered output analysis |
| **Command Palette** | Quick access to everything via `Cmd+K` |

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full system design.

### High-Level Overview

```
┌─────────────────────────────────────────────────────────┐
│                    DeepThink App (SwiftUI)               │
│                                                          │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌────────┐ │
│  │Workspace │  │ Knowledge │  │ AI Chat  │  │Terminal│ │
│  │Notes     │  │ Browser   │  │ Agents   │  │Sessions│ │
│  │Tasks     │  │ Search    │  │ Skills   │  │        │ │
│  │Projects  │  │ Timeline  │  │ Rules    │  │        │ │
│  └────┬─────┘  └─────┬─────┘  └────┬─────┘  └────────┘ │
│       │              │              │                    │
│  ┌────┴──────────────┴──────────────┴──────────────────┐ │
│  │              Context Engine (TF-IDF + RAG)           │ │
│  │  Chunking · Token Budgets · Dedup · Summaries       │ │
│  └──────────────────────┬──────────────────────────────┘ │
│                         │                                │
│  ┌──────────────────────┴──────────────────────────────┐ │
│  │              Service Layer                           │ │
│  │  KnowledgeService · AgentFileService · ClaudeService│ │
│  │  DataCollectorService · MCPService · BacklinkService│ │
│  └──────────────────────┬──────────────────────────────┘ │
│                         │                                │
│  ┌──────────────────────┴──────────────────────────────┐ │
│  │              Storage Layer                           │ │
│  │  SwiftData (notes, tasks) · Markdown (knowledge)    │ │
│  │  ~/Documents/DeepThink/                             │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
              │                          │
    ┌─────────┴──────────┐    ┌──────────┴──────────┐
    │   Claude CLI        │    │   MCP Servers       │
    │   (~/.local/bin/)   │    │   (external tools)  │
    └────────────────────┘    └─────────────────────┘
```

## Data Storage

All data lives in `~/Documents/DeepThink/`:

```
DeepThink/
├── data/                  # SwiftData database (notes, tasks, projects, conversations)
├── .claude/               # Shared config (CLI + App)
│   ├── commands/          # Skills as slash commands (markdown)
│   ├── rules/             # AI behavior rules (markdown)
│   ├── agents/            # Custom AI assistants (markdown)
│   ├── settings.json      # MCP server config
│   └── cache/             # Temp configs, catalog cache
├── knowledge/             # Knowledge base (markdown + YAML frontmatter)
│   ├── web/               # Scraped web pages
│   ├── clipboard/         # Clipboard captures
│   ├── manual/            # User-created entries
│   ├── folders/           # Watched folder imports
│   ├── imports/           # File imports
│   ├── scripts/           # Script output captures
│   ├── integrations/      # MCP-sourced data
│   ├── projects/          # Per-project knowledge
│   └── archive/           # Old/compressed entries
├── memory/                # Persistent memory
├── sandbox/               # Generated docs, analysis, insights
├── logs/                  # App and terminal logs
└── workspace/             # Exported notes and projects
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+K` | Command Palette |
| `Cmd+N` | New Note |
| `Cmd+T` | New Task |
| `Shift+Cmd+N` | New Project |
| `Cmd+1` | Workspace |
| `Cmd+2` | AI Chat |
| `Cmd+3` | Knowledge |
| `Cmd+4` | Connections |
| `Cmd+5` | AI Assistants |
| `Cmd+6` | Terminal |

## License

Private project.
