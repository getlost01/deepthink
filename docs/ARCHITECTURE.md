# DeepThink Architecture

## Overview

DeepThink has two main components that share a local data directory (`~/DeepThink/`):

```
┌─────────────────────────────────────┐    ┌──────────────────────────────────┐
│        macOS App (SwiftUI)          │    │       CLI + MCP Server           │
│                                     │    │        (Bun/TypeScript)          │
│  Workspace · Knowledge · AI Chat   │    │                                  │
│  Terminal · Quick Capture · MCP UI  │    │  deepthink  ·  deepthink-mcp    │
└──────────────────┬──────────────────┘    └──────────────┬───────────────────┘
                   │                                       │
                   └──────────────┬────────────────────────┘
                                  │ shared data
                   ┌──────────────▼────────────────────────┐
                   │          ~/DeepThink/                  │
                   │                                        │
                   │  data/deepthink.store  (SwiftData)    │
                   │  data/vectors.db       (embeddings)   │
                   │  knowledge/            (markdown)     │
                   │  .claude/agents|rules|commands        │
                   └────────────────────────────────────────┘
                                  │
                   ┌──────────────▼────────────────────────┐
                   │           Claude CLI                   │
                   │     (~/.local/bin/claude)              │
                   │  JSON output · MCP config · streaming │
                   └────────────────────────────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **App** | SwiftUI, macOS 14+, MVVM + Observable |
| **Data** | SwiftData (SQLite), Markdown files with YAML frontmatter |
| **AI** | Claude CLI (`~/.local/bin/claude`), JSON output mode |
| **CLI** | Bun + TypeScript, compiled to standalone binaries |
| **MCP** | Model Context Protocol servers via claude CLI `--mcp-config` |
| **Editor** | Tiptap (WYSIWYG markdown via WebView), SwiftTerm (terminal) |
| **Build** | XcodeGen (`project.yml`), Bun bundler |

## App: System Components

### UI Layer (SwiftUI Views)

```
Views/
├── ContentView.swift              # Root: sidebar + content router + onboarding
├── Sidebar/SidebarView.swift      # Navigation sidebar
├── Workspace/                     # Projects, notes, tasks, overview
├── Knowledge/                     # Browser, search, timeline
├── AI/AIView.swift                # AI chat entry point
├── Shared/AIChatView.swift        # Chat interface (context assembly, agent selection)
├── Agents/AgentListView.swift     # AI assistant management + templates
├── SkillsRules/                   # Automations (skills + rules)
├── Tools/ToolsHubView.swift       # MCP connection management
├── Terminal/                      # Multi-tab terminal (SwiftTerm)
├── CommandPalette/                # Cmd+K quick launcher
└── Shared/DesignSystem.swift      # DS tokens, components
```

### Service Layer

```
Services/
├── ContextEngine.swift                # TF-IDF index, RAG, chunking, dedup, summaries
├── KnowledgeService.swift             # Knowledge CRUD, search, RAG context formatting
├── ClaudeService.swift                # Claude CLI wrapper (query, model selection, cost tracking)
├── MCPService.swift                   # MCP server config, tool-augmented queries
├── AgentFileService.swift             # Agent CRUD, context-aware prompt building
├── SkillFileService.swift             # Skill CRUD, template interpolation, execution
├── RuleFileService.swift              # Rule CRUD, trigger matching, prompt injection
├── DataCollectorService.swift         # URL scraping, RSS, clipboard, folders, scripts
├── KnowledgeExtractionService.swift   # Auto-extract facts, auto-tag, chat→knowledge
├── BacklinkService.swift              # Wiki-link parsing, note↔knowledge cross-linking
├── CollectorScheduler.swift           # Timer-based recurring data collection
├── StorageService.swift               # Directory structure, paths, logging
├── MCPCatalogService.swift            # npm registry browser for MCP servers
├── VersioningService.swift            # Note version history
├── TaskNotificationService.swift      # macOS notifications for due/overdue tasks
└── DeepThinkCLIService.swift          # CLI binary installation
```

### Model Layer

```
Models/
├── Note.swift              # @Model — title, content, project, tags, pinned
├── TaskItem.swift          # @Model — title, status, priority, due date, story points
├── Project.swift           # @Model — name, summary, color, archived
├── Tag.swift               # @Model — name, color
├── Conversation.swift      # @Model — chat history persistence
├── ChatMessage.swift       # @Model — individual chat messages
├── MCPServer.swift         # @Model — MCP server config (command, args, enabled)
├── DataSource.swift        # @Model — scheduled collection sources
├── NoteLink.swift          # @Model — wiki-link edges between notes
├── NoteVersion.swift       # @Model — note version snapshots
├── KnowledgeEntry.swift    # Struct — parsed knowledge file
├── AgentFile.swift         # Struct — parsed agent markdown
├── SkillFile.swift         # Struct — parsed skill markdown
└── AIMessage.swift         # Struct — in-memory chat messages
```

## Context Pipeline

Every AI interaction flows through this pipeline:

```
User Query
    │
    ▼
┌─────────────────────────────────┐
│  1. Context Engine (TF-IDF)     │
│     Tokenize → BM25 score       │
│     Scope filters + dedup       │
│     Token budget allocation     │
└───────────────┬─────────────────┘
                │
    ┌───────────┼───────────┐
    ▼           ▼           ▼
┌─────────┐ ┌────────┐ ┌──────────┐
│Knowledge│ │Workspace│ │Conversa- │
│RAG      │ │Context  │ │tion      │
│(chunks) │ │(scored) │ │Summary   │
└────┬────┘ └───┬────┘ └────┬─────┘
     └──────────┼───────────┘
                ▼
┌─────────────────────────────────┐
│  2. System Prompt Assembly      │
│     Agent instructions          │
│     Matched rules               │
│     Scoped knowledge            │
└───────────────┬─────────────────┘
                ▼
┌─────────────────────────────────┐
│  3. Claude CLI / MCP Dispatch   │
│     Direct query (no tools)     │
│     MCP query (with tools)      │
└───────────────┬─────────────────┘
                ▼
┌─────────────────────────────────┐
│  4. Response + Side Effects     │
│     Display · Persist           │
│     Auto-extract knowledge      │
│     Rebuild index               │
└─────────────────────────────────┘
```

### TF-IDF / BM25 Indexing

Cached in RAM; rebuilt only when knowledge changes (version-gated):

1. **Tokenization** — lowercase, strip 150+ stop words, suffix stemmer (`-ing`, `-ed`, `-tion`, `-ness`, `-ment`, `-ly`, plurals)
2. **BM25 Scoring** — `IDF × TF_norm` with `k1=1.5, b=0.75` length normalization
3. **Boosting** — title (1.5×), tag (1.3×), recency (exp decay over 90 days), project scope (1.5×)
4. **Relevance window** — sliding window over highest query-term density region
5. **Chunking** — `SemanticChunker`: max 500 chars, sentence-boundary split, last-sentence overlap
6. **Dedup** — hash fingerprinting + Jaccard similarity (threshold 0.75)

### Token Budget

| Component | Budget | Strategy |
|-----------|--------|----------|
| Knowledge RAG | 4000 tokens | Top chunks by score, sentence-truncated |
| Workspace context | 600 tokens | Query-relevant notes/tasks only |
| Conversation summary | 400 tokens | Older messages summarized, recent verbatim |
| Agent knowledge | 2000 tokens | Scope-filtered + query-relevant |

Total per query: ~5–7K tokens.

## CLI Architecture

```
cli/src/
├── index.ts            # Entry point + command routing
├── mcp-server.ts       # MCP server (45 tools for Claude/Cursor/VS Code)
├── config.ts           # Paths, settings
├── core/
│   ├── context-engine.ts    # BM25 + hybrid retrieval
│   ├── embedding-service.ts # Semantic search via NLEmbedding
│   ├── db.ts                # SQLite access helpers
│   ├── llm.ts               # Claude CLI wrapper
│   └── sandbox.ts           # Output directory management
├── agents/
│   ├── base.ts          # Agent base — think(), memory, output logging
│   ├── memory.ts        # Per-agent persistent memory
│   ├── scheduler.ts     # Job scheduler (daily-brief, stale-tasks, insight-scan)
│   ├── daily-brief.ts   # DailyBriefAgent → pinned note
│   ├── insight.ts       # InsightAgent → insights.json
│   ├── stale-task.ts    # StaleTaskAgent → triage report
│   ├── react.ts         # ReAct agent (THOUGHT/ACTION loop, 12 steps max)
│   ├── research.ts      # Research pipeline (questions → search → synthesize)
│   ├── planner.ts       # Multi-step task decomposition
│   ├── executor.ts      # Step runner
│   ├── writer.ts        # Markdown output generation
│   ├── analyst.ts       # Data/CSV analysis
│   └── workspace.ts     # NL workspace mutations
└── tools/               # Tool implementations
```

### Agent Memory

Stored at `~/DeepThink/data/agent-memory/<agentId>.json`:

| Field | Capacity | Purpose |
|-------|----------|---------|
| `observations` | last 20 | Recent prompt→response previews |
| `corrections` | last 10 | User corrections injected into system prompt |
| `facts` | unlimited | Named key-value facts |

### Scheduled Jobs

State at `~/DeepThink/data/schedule-state.json`:

| Job | Agent | Interval | Output |
|-----|-------|----------|--------|
| `daily-brief` | `DailyBriefAgent` | 20h | Pinned "Daily Brief" note |
| `stale-tasks` | `StaleTaskAgent` | 7 days | Triage report note |
| `insight-scan` | `InsightAgent` | 4h | `data/insights.json` |

### Insight Types

| Type | Trigger | Severity |
|------|---------|----------|
| `overdue_tasks` | Task past due date | action |
| `high_priority_stale` | High/urgent task not updated 7+ days | warning |
| `blocked_tasks` | "In Progress" task stuck 5+ days | warning |
| `stale_project` | Project inactive 21+ days with open tasks | info |
| `task_cluster` | 5+ unassigned tasks with detectable theme | info |

## Knowledge Collection

### Sources

| Source | Method | Scheduling |
|--------|--------|-----------|
| Web pages | HTML scraping → markdown | Manual or recurring |
| RSS/Atom feeds | Feed parsing → article scraping | Recurring |
| Folders | File watch, incremental sync | Recurring |
| Clipboard | System pasteboard capture | Manual or recurring |
| Scripts | Shell execution → output capture | Recurring |
| Conversations | Auto-extract every 6 messages | Automatic |
| Notes | Auto-extract facts when >30 words | Automatic |
| MCP servers | Via MCP protocol | On-demand |

### Entry Format

```markdown
---
title: OAuth Token Design
source: manual
bucket: General
tags: [security, auth, api]
imported_at: 2026-05-04T10:30:00Z
---

Content in markdown...
```

### Deduplication

1. **Hash fingerprint** — exact content match, O(1)
2. **Jaccard similarity** — near-duplicate detection (>75% term overlap)
3. **Incremental sync** — folder watcher only copies new/modified files

## MCP Integration

```
User query → keyword detection → write MCP config JSON
    → Claude CLI --mcp-config → tool calls → response
```

The app ships its own MCP server (`deepthink-mcp`) with 45 tools across 6 categories. See [MCP Integration](mcp-integration.md) for the full tool list and external client setup.

## Design System

Monochrome + single accent (blue). Tokens in `Views/Shared/DesignSystem.swift`:

| Token | Values |
|-------|--------|
| Spacing | xs=4, sm=8, md=12, lg=16, xl=24, xxl=32 |
| Radius | sm=6, md=8, lg=12 |
| Font sizes | title=18, heading=14, body=13, caption=11, small=10 |

Key components: `DSPageHeader`, `DSCard`, `DSEmptyState`, `DSActionButton`, `DSSearchField`, `DSTabButton`, `DSStatChip`, `DSPill`.

## Related Docs

- [App Features](app/README.md)
- [CLI Reference](cli/README.md)
- [RAG Pipeline](rag-pipeline.md)
- [MCP Integration](mcp-integration.md)
- [Storage Layout](storage.md)
