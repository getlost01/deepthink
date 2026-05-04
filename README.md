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

No additional installations required — all features use built-in Apple frameworks (NaturalLanguage, AppKit, SwiftData).

### CLI Usage

```bash
# Smart context retrieval (token-efficient)
deepthink context overview                        # compact system overview (~200 tokens)
deepthink context query "What's blocking v2?"     # auto-routed smart retrieval
deepthink context workspace "auth migration"      # relevant tasks/notes/reminders only
deepthink context knowledge "API design"           # BM25-scored knowledge chunks

# Ask AI with workspace context
deepthink ask "What tasks need attention?" --recall --project MyProject

# Run multi-step tasks with AI agents
deepthink run "Analyze the codebase and create a migration plan" --project MyProject

# Natural language workspace management
deepthink workspace "create a high-priority task for API migration due Friday"

# Task management
deepthink task list --status "In Progress" --project MyProject
deepthink task add "Review PR" --priority high --due 2026-05-10 --project MyProject
deepthink task done "Review PR"

# Note management
deepthink note list --project MyProject --pinned
deepthink note add "Meeting Notes" --content "..." --project MyProject

# Project management
deepthink project list
deepthink project add "MyProject" --summary "API migration" --color "#FF6B6B"

# Knowledge base
deepthink knowledge list
deepthink knowledge search "auth middleware" --source slack --limit 10
deepthink knowledge save MyProject "Decided to use JWT tokens" --type decision
deepthink knowledge load MyProject

# Search & Analysis
deepthink search "React server components"        # web search
deepthink analyze data.csv --question "What are the trends?"
```

## Features

| Feature | Description |
|---------|-------------|
| **Workspace** | Projects, notes, tasks with rich markdown editing and kanban board |
| **Knowledge Base** | Multi-source capture (web, files, clipboard, RSS, scripts, Obsidian vaults) with timeline view |
| **AI Chat** | Streaming chat with Claude, conversation history, edit branching, auto-compaction |
| **Hybrid RAG** | BM25 keyword + semantic vector search — AI finds relevant knowledge automatically |
| **AI Assistants** | Custom personas with knowledge scopes, model selection, and skill assignments |
| **Skills & Rules** | Slash-command skills with template variables, context-aware rules with structured triggers |
| **Global Quick Capture** | `Cmd+Shift+D` from anywhere — floating panel to capture notes, knowledge, or tasks instantly |
| **Obsidian Import** | One-click vault import with wiki-link conversion, tag extraction, and dedup |
| **Semantic Search** | Apple NLEmbedding vectors for meaning-based retrieval alongside keyword search |
| **MCP Integration** | 50-tool MCP server for external tool access (Claude CLI, Cursor, VS Code, etc.) |
| **Terminal** | Built-in terminal with multi-session tracking and AI output analysis |
| **Command Palette** | `Cmd+K` quick access to all commands, navigation, and skills |
| **Reminders** | Todo-style reminders with optional timed notifications |

## Feature Documentation

Detailed docs for each major feature:

| Document | Description |
|----------|-------------|
| [RAG Pipeline](docs/features/rag-pipeline.md) | How retrieval-augmented generation works end-to-end |
| [Semantic Search](docs/features/semantic-search.md) | NLEmbedding vectors, cosine similarity, hybrid fusion |
| [Agents, Skills & Rules](docs/features/agents-skills-rules.md) | Custom AI personas, slash commands, context-aware rules |
| [Knowledge Base](docs/features/knowledge-base.md) | Multi-source capture, storage, and organization |
| [Obsidian Import](docs/features/obsidian-import.md) | Vault import with syntax conversion and dedup |
| [Quick Capture](docs/features/quick-capture.md) | Global hotkey floating panel for instant capture |
| [Workspace](docs/features/workspace.md) | Projects, notes, tasks, backlinks, versioning |
| [Terminal](docs/features/terminal.md) | Multi-tab terminal with AI output analysis |
| [MCP Integration](docs/features/mcp-integration.md) | 50-tool MCP server, external tool access, catalog |
| [CLI](docs/features/cli.md) | Command-line interface, agent system, all commands |
| [Deep Search](docs/features/deep-search.md) | Global search with AI-powered analysis |
| [Command Palette](docs/features/command-palette.md) | Cmd+K quick launcher, fuzzy matching |
| [Data Collection](docs/features/data-collection.md) | Automated capture from URLs, RSS, folders, scripts |
| [Reminders](docs/features/reminders.md) | Scheduled reminders with notifications |
| [Architecture](docs/ARCHITECTURE.md) | Full system design, services, data flow |

## RAG Pipeline

Every AI conversation is automatically augmented with relevant knowledge. No manual context-pasting required.

```
User question
    ↓
┌──────────────┐     ┌──────────────┐
│ BM25 Search  │     │ Semantic     │
│ (keywords)   │     │ Search       │
│              │     │ (meaning)    │
└──────┬───────┘     └──────┬───────┘
       │                    │
       └────────┬───────────┘
                ↓
    Reciprocal Rank Fusion
    (merge best of both)
                ↓
    Token-budgeted context (~4K tokens)
    + Workspace context (~600 tokens)
    + Conversation history (~400 tokens)
                ↓
    Claude responds with grounded answer
```

**Keyword search** finds entries containing your exact words. **Semantic search** finds entries with similar meaning — "authentication concerns" matches entries about "login security" even without shared keywords.

Results merge via Reciprocal Rank Fusion (RRF) for best-of-both ranking.

See [RAG Pipeline docs](docs/features/rag-pipeline.md) for the full deep-dive.

## AI Chat

### Conversation Memory

Claude CLI runs stateless, so DeepThink manages its own conversation context:

| Length | Strategy |
|--------|----------|
| 1-4 messages | Full history |
| 5-8 messages | Older compacted + last 4 full |
| 8+ messages | Rolling summary (~300 tokens) + last 4 full |

A 20-message conversation uses ~1,500 tokens instead of ~10,000.

### Slash Commands

Type `/` in chat to see available skills. Skills are markdown files in `.claude/commands/` with template variables:

```
{{input}}, {{note_content}}, {{selected_text}}, {{project_name}},
{{note_title}}, {{note_tags}}, {{current_date}}, {{current_time}}
```

### Rules

Auto-triggered instructions with structured triggers:

| Trigger | Matches When |
|---------|-------------|
| `always` | Every query |
| `tag:meeting` | Note has "meeting" tag |
| `agent:Researcher` | Agent selected |
| `event:task.created` | Event fired |
| `content:code` | Content detected as code |

Rules show as toggleable pills in the chat toolbar. Disabled state persists across restarts.

### Knowledge Loop

Bidirectional integration:
- **Read**: every query searches knowledge base via hybrid RAG
- **Write**: insights auto-extract every 6 messages, or manually via "Save to Knowledge"

## Global Quick Capture

Press `Cmd+Shift+D` from any app on your Mac:

- **Note** — with optional project assignment
- **Knowledge** — with folder selection and tags
- **Task** — with optional project assignment

Floating panel with `Cmd+Enter` to save, `Escape` to dismiss. Requires Accessibility permission for the global hotkey (works inside the app without it).

## Obsidian Import

**Knowledge → Add → Import Obsidian Vault**

- Converts `[[wiki-links]]`, `![[embeds]]`, `> [!callouts]`, `%%comments%%`
- Extracts inline `#tags` to frontmatter
- Preserves folder structure
- Dedup against existing entries
- Progress bar for large vaults

## MCP Server

DeepThink ships an MCP server (`deepthink-mcp`) with 50 tools for workspace management via any MCP client.

### Configure

Add to your MCP client's config:

```json
{
  "mcpServers": {
    "deepthink": {
      "command": "deepthink-mcp",
      "args": []
    }
  }
}
```

### Tool Categories (50 total)

| Category | Tools | Description |
|----------|-------|-------------|
| Smart Context | 4 | Token-efficient retrieval, query routing |
| Workspace | 21 | Task/note/project/reminder CRUD |
| Knowledge Base | 8 | Save, load, search project knowledge |
| Memory | 5 | Short/long-term persistent memory |
| Agents | 4 | Agent management |
| Rules | 4 | Rule management |
| Skills | 4 | Skill management |

### Resources

| URI | Description |
|-----|-------------|
| `deepthink://tasks` | All tasks as JSON |
| `deepthink://notes` | All notes as JSON |
| `deepthink://projects` | All projects as JSON |
| `deepthink://reminders` | All reminders as JSON |
| `deepthink://overview` | Compact system overview |
| `deepthink://knowledge/stats` | Knowledge base overview |

## Data Storage

All data in `~/Documents/DeepThink/`:

```
DeepThink/
├── data/
│   ├── deepthink.store          # SwiftData SQLite (notes, tasks, projects, conversations)
│   ├── embeddings.json          # Semantic vectors (512-dim per entry)
│   └── embedding_hashes.json    # Content hashes for incremental indexing
├── .claude/
│   ├── commands/                # Skills (markdown)
│   ├── rules/                   # Rules (markdown)
│   ├── agents/                  # Agents (markdown)
│   └── settings.json            # MCP server config
├── knowledge/                   # Knowledge base (markdown + YAML frontmatter)
│   ├── general/                 # Default folder
│   ├── web/                     # Scraped web pages
│   ├── clipboard/               # Clipboard captures
│   ├── manual/                  # User-created entries
│   ├── obsidian/                # Obsidian vault imports
│   ├── integrations/            # External data
│   ├── projects/                # Per-project knowledge
│   └── archive/                 # Compressed entries
├── memory/                      # Persistent AI memory
├── sandbox/                     # Generated docs, analysis
├── logs/                        # App and terminal logs
└── workspace/                   # Exported notes/projects
```

### Index Storage

| Data | Location | Persistence |
|------|----------|-------------|
| BM25/TF-IDF index | RAM | Rebuilt on each `reload()` — fast, no disk |
| Semantic embeddings | `data/embeddings.json` | Persisted, incremental updates |
| Content hashes | `data/embedding_hashes.json` | Tracks what's already embedded |
| Conversation summaries | RAM | Regenerated as needed |
| Dedup fingerprints | RAM | Rebuilt with index |

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full system design.

```
┌──────────────────────────────────────────────────────────────┐
│                   DeepThink App (SwiftUI)                     │
│                                                              │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌────────────┐ │
│  │Workspace │  │ Knowledge │  │ AI Chat  │  │  Terminal   │ │
│  │Notes     │  │ Browser   │  │ Agents   │  │  Quick      │ │
│  │Tasks     │  │ Obsidian  │  │ Skills   │  │  Capture    │ │
│  │Projects  │  │ Import    │  │ Rules    │  │             │ │
│  └────┬─────┘  └─────┬─────┘  └────┬─────┘  └─────────────┘ │
│       │              │              │                        │
│  ┌────┴──────────────┴──────────────┴──────────────────────┐ │
│  │           Hybrid Search Engine                          │ │
│  │  BM25/TF-IDF (keywords) + NLEmbedding (meaning)       │ │
│  │  Reciprocal Rank Fusion · Token Budgets · Dedup        │ │
│  └──────────────────────┬─────────────────────────────────┘ │
│                         │                                    │
│  ┌──────────────────────┴─────────────────────────────────┐ │
│  │              Service Layer                              │ │
│  │  KnowledgeService · AgentFileService · ClaudeService   │ │
│  │  EmbeddingService · ContextEngine · MCPService         │ │
│  └──────────────────────┬─────────────────────────────────┘ │
│                         │                                    │
│  ┌──────────────────────┴─────────────────────────────────┐ │
│  │              Storage Layer                              │ │
│  │  SwiftData (notes, tasks) · Markdown (knowledge)       │ │
│  │  JSON (embeddings) · UserDefaults (preferences)        │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
              │                          │
    ┌─────────┴──────────┐    ┌──────────┴──────────┐
    │   Claude CLI        │    │   MCP Servers       │
    │   (~/.local/bin/)   │    │   (external tools)  │
    └────────────────────┘    └─────────────────────┘
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+D` | **Global Quick Capture** (works from any app) |
| `Cmd+K` | Command Palette |
| `Cmd+N` | New Note |
| `Cmd+T` | New Task |
| `Shift+Cmd+N` | New Project |
| `Shift+Cmd+R` | New Reminder |
| `Cmd+0` | Recent |
| `Cmd+1` | Workspace |
| `Cmd+2` | Knowledge |
| `Cmd+3` | AI Assistant |
| `Cmd+4` | Connections |
| `Cmd+5` | Reminders |
| `Cmd+6` | Terminal |
| `Shift+Cmd+1` | Workspace → Projects |
| `Shift+Cmd+2` | Workspace → Notes |
| `Shift+Cmd+3` | Workspace → Tasks |

## License

Private project.
