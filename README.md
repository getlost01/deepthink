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

## MCP Server

DeepThink ships an MCP server (`deepthink-mcp`) that lets any MCP-compatible client — Claude CLI, Claude Desktop, Cursor, Windsurf, VS Code, etc. — manage your full workspace through natural language: tasks, notes, projects, knowledge base, memory, agents, rules, and skills.

### Install

```bash
# Build the MCP binary (requires Bun)
cd cli && bun install && bun run build:mcp && cd ..

# Symlink globally
mkdir -p ~/.local/bin
ln -sf "$(pwd)/cli/out/deepthink-mcp" ~/.local/bin/deepthink-mcp
```

### Configure

Add to your MCP client's config file:

**Claude CLI** (`~/.claude.json`):

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

**Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "deepthink": {
      "command": "/Users/YOUR_USERNAME/.local/bin/deepthink-mcp",
      "args": []
    }
  }
}
```

**Cursor / VS Code** (`.cursor/mcp.json` or `.vscode/mcp.json`):

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

### Available Tools (41 total)

**Workspace** (16 tools)

| Tool | Description |
|------|-------------|
| `workspace_list_tasks` | List tasks (filter by status, priority, project) |
| `workspace_get_task` | Get task by ID or name |
| `workspace_create_task` | Create task with title, status, priority, points, due date, project |
| `workspace_update_task` | Update any task fields |
| `workspace_delete_task` | Delete a task |
| `workspace_list_notes` | List notes (filter by project, pinned) |
| `workspace_get_note` | Get note by ID or title |
| `workspace_create_note` | Create note with markdown content |
| `workspace_update_note` | Update note fields |
| `workspace_delete_note` | Delete a note |
| `workspace_list_projects` | List all projects with counts |
| `workspace_get_project` | Get project by ID or name |
| `workspace_create_project` | Create project with name, summary, color |
| `workspace_update_project` | Update project fields |
| `workspace_delete_project` | Delete project (items become unassigned) |
| `workspace_summary` | Full workspace overview: counts, recent items, status breakdown |

**Knowledge Base** (8 tools)

| Tool | Description |
|------|-------------|
| `knowledge_stats` | Knowledge base overview: project count, integrations, archives |
| `knowledge_list_projects` | List all knowledge projects |
| `knowledge_load_project` | Load project knowledge: context, decisions, artifacts |
| `knowledge_save_project` | Save knowledge to a project (context, decision, or artifact) |
| `knowledge_search` | Search across all integration data by keyword |
| `knowledge_list_integrations` | List all integration sources and channels |
| `knowledge_load_integration` | Load recent entries from a source/channel |
| `knowledge_capture` | Capture data from an external source into the knowledge base |

**Memory** (5 tools)

| Tool | Description |
|------|-------------|
| `memory_stats` | Short-term and long-term entry counts |
| `memory_save` | Save a memory entry with tags to short or long-term storage |
| `memory_recall` | Search memories by keyword across both layers |
| `memory_promote` | Promote a short-term memory to long-term |
| `memory_clear_short_term` | Clear all short-term memories |

**Agents** (4 tools)

| Tool | Description |
|------|-------------|
| `agent_list` | List all AI agents with roles, models, knowledge scopes |
| `agent_get` | Get full agent details including system prompt |
| `agent_create` | Create a new agent with name, role, system prompt, knowledge scope |
| `agent_delete` | Delete an agent |

**Rules** (4 tools)

| Tool | Description |
|------|-------------|
| `rule_list` | List all rules with triggers and categories |
| `rule_get` | Get full rule details including instruction text |
| `rule_create` | Create a rule with trigger condition and instruction |
| `rule_delete` | Delete a rule |

**Skills** (4 tools)

| Tool | Description |
|------|-------------|
| `skill_list` | List all slash-command skills |
| `skill_get` | Get full skill details including prompt template |
| `skill_create` | Create a skill with system prompt and `{{input}}` template |
| `skill_delete` | Delete a skill |

### Resources

MCP resources for read-only access:

| URI | Description |
|-----|-------------|
| `deepthink://tasks` | All tasks as JSON |
| `deepthink://notes` | All notes as JSON |
| `deepthink://projects` | All projects as JSON |
| `deepthink://knowledge/stats` | Knowledge base overview |
| `deepthink://knowledge/projects` | All knowledge projects |
| `deepthink://knowledge/integrations` | Integration sources and channels |
| `deepthink://memory/stats` | Memory entry counts |

### Example Usage

Once configured, just talk to Claude naturally:

```
> "Create a high-priority task called 'Ship v2.0' due 2026-05-10 in the DeepThink project"
> "What tasks are in progress right now?"
> "Show me a summary of my workspace"
> "Search my knowledge base for API migration notes"
> "Save this decision to the DeepThink project knowledge"
> "Create an agent called 'DevOps Expert' that knows about infrastructure"
> "Add a rule that triggers on code reviews to check for security issues"
> "What memories do I have about deployment?"
```

## Features

| Feature | Description |
|---------|-------------|
| **Workspace** | Projects, notes, and tasks with rich markdown editing |
| **Knowledge Base** | Save web pages, files, clipboard, scripts, RSS feeds — all searchable |
| **AI Chat** | Streaming chat with Claude, markdown rendering, code highlighting, conversation history, auto-compaction |
| **AI Assistants** | Custom AI personas with specialized expertise and knowledge scopes |
| **Automations** | Slash-command skills in chat, context-aware rules that auto-inject into prompts |
| **Connections** | MCP server integration — give AI access to external tools |
| **Smart RAG** | TF-IDF indexed retrieval with chunking and token budgeting |
| **Terminal** | Built-in terminal with AI-powered output analysis |
| **Command Palette** | Quick access to everything via `Cmd+K` |

## AI Chat

The chat is the core interaction surface. It's designed to feel like a native macOS app while being as capable as web-based AI chat tools.

### Conversation Memory

Claude CLI runs stateless (`--no-session-persistence`), so DeepThink manages its own conversation context with a token-optimized compaction strategy:

| Conversation length | What gets sent to Claude |
|---------------------|--------------------------|
| 1-4 messages | All prior messages (user full, assistant capped at 400 chars) |
| 5-8 messages | Older messages compacted (user 200 chars, assistant 120 chars) + last 4 full |
| 8+ messages | Rolling summary (~300 tokens) + last 4 messages full |

The summary regenerates every 6 messages, incorporating the previous summary so context never degrades. Code blocks are stripped from compacted text. A 20-message conversation uses ~1,500 tokens instead of ~10,000 for full history.

### Streaming

Non-MCP queries stream token-by-token via `--output-format stream-json`. MCP queries (tool-use) return full responses since the CLI handles tool orchestration internally.

### Slash Commands

Type `/` in the chat input to see available skills. Skills are reusable AI prompts stored as markdown files in `~/.claude/commands/`. They auto-fill `{{input}}` from:
1. Text after the command (`/summarize some text here`)
2. Selected text in the active note
3. Current note content

### Rules

Rules are auto-triggered system prompt instructions. They activate based on context:
- `always` — injected into every query
- `note.tagged.meeting` — when the active note has a "meeting" tag
- `content_type.code` — when the active note contains code

Active rules show as toggleable pills in the chat toolbar.

### Markdown Rendering

Simple messages use native SwiftUI `AttributedString`. Messages containing code blocks, tables, or headers render via a WKWebView with:
- **marked.js** for markdown parsing
- **highlight.js** for syntax highlighting (dark/light theme aware)
- Per-code-block copy buttons
- Scroll passthrough so the chat scrolls normally

### Chat History

Conversations persist via SwiftData. The history sidebar (right panel) groups by Today/Yesterday/This Week/Older with search. Click to resume any conversation. Conversations auto-title via a background Claude call after the first exchange.

### Knowledge Loop

Chat integrates bidirectionally with the knowledge base:
- **Read**: every query searches the knowledge base via TF-IDF RAG and injects relevant entries
- **Write**: insights auto-extract every 6 messages, or manually via "Save to Knowledge"

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
