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
deepthink context query "What's blocking v2?"     # hybrid retrieval (BM25 + semantic)
deepthink context query "auth flow" --bm25        # keyword-only (skip semantic)
deepthink context semantic "authentication"        # pure semantic vector search
deepthink context workspace "auth migration"      # relevant tasks/notes/reminders only
deepthink context knowledge "API design"           # BM25-scored knowledge chunks

# Ask AI with workspace context
deepthink ask "What tasks need attention?" --recall --project MyProject

# Run multi-step tasks with AI agents
deepthink run "Analyze the codebase and create a migration plan" --project MyProject

# ReAct agent — multi-tool reasoning loop
deepthink react "Find all overdue tasks and draft a summary note"

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

# Proactive insights (overdue, stale, blocked tasks)
deepthink insight scan
deepthink insight list

# Research pipeline (web + local knowledge synthesis)
deepthink research "gRPC vs REST tradeoffs" --deep --project MyProject

# Scheduled background jobs
deepthink schedule run          # run due jobs
deepthink schedule run --force  # force all jobs now
deepthink schedule status       # show last run + next due

# Search & Analysis
deepthink search "React server components"        # web search
deepthink analyze data.csv --question "What are the trends?"
```

## Features

| Feature | Description |
|---------|-------------|
| **Workspace** | Projects, notes, tasks with rich markdown editing and kanban board |
| **Knowledge Base** | Multi-source capture (web, files, clipboard, RSS, scripts, Obsidian vaults) organized into buckets |
| **AI Chat** | Streaming chat with Claude, conversation history, edit branching, auto-compaction |
| **Hybrid RAG** | BM25 keyword + semantic vector search — AI finds relevant knowledge automatically |
| **AI Assistants** | Custom personas with knowledge scopes, model selection, and skill assignments |
| **Skills & Rules** | Slash-command skills with template variables, context-aware rules with structured triggers |
| **Global Quick Capture** | `Cmd+Shift+D` from anywhere — floating panel to capture notes, knowledge, or tasks instantly |
| **Obsidian Import** | One-click vault import with wiki-link conversion, tag extraction, and dedup |
| **Semantic Search** | Apple NLEmbedding vectors for meaning-based retrieval alongside keyword search |
| **MCP Integration** | 45-tool MCP server for external tool access (Claude CLI, Cursor, VS Code, etc.) with global registration |
| **Terminal** | Built-in terminal with multi-session tracking and AI output analysis |
| **Command Palette** | `Cmd+K` quick access to all commands, navigation, and skills |
| **Reminders** | Todo-style reminders with optional timed notifications |
| **Task Notifications** | macOS notifications for due and overdue tasks at 9am daily |
| **Proactive Insights** | AI scans workspace every 4h — flags overdue, stale, blocked tasks and project inactivity |
| **Agent Memory** | Per-agent persistent memory (observations, corrections, facts) across CLI sessions |
| **ReAct Agent** | Multi-tool reasoning loop — reads/writes workspace, searches web, saves to knowledge |
| **Research Pipeline** | Multi-step research: generates questions, searches web + local knowledge, synthesizes findings |
| **Scheduler** | Background jobs: daily brief (20h), stale task scan (weekly), insight scan (4h) |

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
| [MCP Integration](docs/features/mcp-integration.md) | 45-tool MCP server, external tool access, global registration |
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
- **Knowledge** — with bucket selection and tags
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

DeepThink ships an MCP server (`deepthink-mcp`) with 45 tools for workspace management via any MCP client.

### Configure

**Option A — Global (via app):** Settings → Claude → Register Global MCP. Runs `claude mcp add --scope user deepthink -- deepthink-mcp` automatically.

**Option B — Manual config:** Add to your MCP client's config:

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

Works with Claude CLI, Cursor, VS Code, and any MCP-compatible client.

### Tool Categories (45 total)

| Category | Tools | Description |
|----------|-------|-------------|
| Smart Context | 4 | `smart_query`, `knowledge_context`, `workspace_context`, `deepthink_overview` |
| Workspace | 21 | Task/note/project/reminder CRUD + `workspace_summary` |
| Knowledge Base | 8 | `knowledge_stats`, search, save/load projects, integrations, capture |
| Agents | 4 | `agent_list/get/create/delete` |
| Rules | 4 | `rule_list/get/create/delete` |
| Skills | 4 | `skill_list/get/create/delete` |

### Resources (8 total)

| URI | Description |
|-----|-------------|
| `deepthink://tasks` | All tasks as JSON |
| `deepthink://notes` | All notes as JSON |
| `deepthink://projects` | All projects as JSON |
| `deepthink://reminders` | All reminders as JSON |
| `deepthink://overview` | Compact system overview (~200 tokens) |
| `deepthink://knowledge/stats` | Knowledge base overview |
| `deepthink://knowledge/projects` | All knowledge projects |
| `deepthink://knowledge/integrations` | All integration sources and channels |

## Data Storage

All data in `~/DeepThink/`:

```
DeepThink/
├── data/
│   ├── deepthink.store          # SwiftData SQLite (notes, tasks, projects, conversations)
│   ├── vectors.db               # Chunks + embeddings (Float32 BLOB), shared by app and CLI
│   ├── insights.json            # Saved proactive insights (InsightAgent output)
│   ├── schedule-state.json      # Scheduler last-run timestamps
│   └── agent-memory/            # Per-agent persistent memory (observations, corrections, facts)
├── knowledge/                   # Knowledge base (markdown + YAML frontmatter)
│   ├── general/                 # Default bucket
│   ├── folders/                 # User-created buckets
│   ├── web/                     # Scraped web pages
│   ├── clipboard/               # Clipboard captures
│   ├── manual/                  # User-created entries
│   ├── imports/                 # Imported content (Obsidian, files)
│   ├── integrations/            # External data sources
│   ├── projects/                # Per-project knowledge
│   ├── research/                # Research captures
│   ├── scripts/                 # Script-collected data
│   ├── archive/                 # Compressed entries
│   └── index.json               # Knowledge index
├── memory/                      # Persistent AI memory
├── sandbox/                     # Generated docs, analysis
├── tools/                       # Tool outputs
├── logs/                        # App and terminal logs
└── workspace/                   # Exported notes/projects
```

Skills, rules, and agents live in `~/DeepThink/.claude/` (auto-created by the app):

```
~/DeepThink/.claude/
├── commands/    # Skills (markdown)
├── rules/       # Rules (markdown)
└── agents/      # Agents (markdown)
```

### Index Storage

| Data | Location | Persistence |
|------|----------|-------------|
| BM25/TF-IDF index | RAM | Cached across calls; rebuilt only when knowledge content changes (version-gated) |
| Chunks + embeddings | `data/vectors.db` | SQLite WAL, Float32 BLOB, shared by app and CLI |
| Content hashes | RAM + `data/vectors.db` | Process-level cache avoids redundant DB queries; persisted per-chunk for restart recovery |
| Knowledge entries | RAM (30s TTL) | Disk re-read at most once per 30 seconds |
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
| `Cmd+4` | Integration |
| `Cmd+5` | Reminders |
| `Cmd+6` | Terminal |
| `Shift+Cmd+1` | Workspace → Projects |
| `Shift+Cmd+2` | Workspace → Notes |
| `Shift+Cmd+3` | Workspace → Tasks |

## License

Private project.
