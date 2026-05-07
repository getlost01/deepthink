# DeepThink Architecture

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

## System Components

### 1. UI Layer (SwiftUI Views)

```
Views/
├── ContentView.swift          # Root: sidebar + content router + onboarding
├── Sidebar/SidebarView.swift  # Navigation sidebar (7 sections)
├── Workspace/                 # Projects, notes, tasks, overview
├── Knowledge/                 # Browser, search, timeline
├── AI/AIView.swift            # AI chat entry point
├── Shared/AIChatView.swift    # Chat interface (context assembly, agent selection)
├── Agents/AgentListView.swift # AI assistant management + templates
├── SkillsRules/               # Automations (skills + rules)
├── Tools/ToolsHubView.swift   # MCP connection management
├── Terminal/                  # Multi-tab terminal (SwiftTerm)
├── CommandPalette/            # Cmd+K quick launcher
└── Shared/DesignSystem.swift  # DS tokens, components (DSCard, DSEmptyState, etc.)
```

### 2. Service Layer

```
Services/
├── ContextEngine.swift           # TF-IDF index, RAG, chunking, dedup, summaries
├── KnowledgeService.swift        # Knowledge CRUD, search, RAG context formatting
├── ClaudeService.swift           # Claude CLI wrapper (query, model selection, cost tracking)
├── MCPService.swift              # MCP server config, tool-augmented queries
├── AgentFileService.swift        # Agent CRUD, context-aware prompt building
├── SkillFileService.swift        # Skill CRUD, template interpolation, execution
├── RuleFileService.swift         # Rule CRUD, trigger matching, prompt injection
├── DataCollectorService.swift    # URL scraping, RSS, clipboard, folders, scripts
├── KnowledgeExtractionService.swift  # Auto-extract facts, auto-tag, chat→knowledge
├── BacklinkService.swift         # Wiki-link parsing, note↔knowledge cross-linking
├── CollectorScheduler.swift      # Timer-based recurring data collection
├── StorageService.swift          # Directory structure, paths, logging
├── MCPCatalogService.swift       # npm registry browser for MCP servers
├── VersioningService.swift       # Note version history
├── TaskNotificationService.swift # macOS UNUserNotification for due/overdue tasks (9am daily)
└── DeepThinkCLIService.swift     # CLI binary installation
```

### 3. Model Layer

```
Models/
├── Note.swift              # @Model — title, content, project, tags, pinned
├── TaskItem.swift           # @Model — title, status, priority, due date, story points
├── Project.swift            # @Model — name, summary, color, archived, notes[], tasks[]
├── Tag.swift                # @Model — name, color
├── Conversation.swift       # @Model — chat history persistence
├── ChatMessage.swift        # @Model — individual chat messages
├── MCPServer.swift          # @Model — MCP server config (command, args, enabled)
├── DataSource.swift         # @Model — scheduled collection sources
├── NoteLink.swift           # @Model — wiki-link edges between notes
├── NoteVersion.swift        # @Model — note version snapshots
├── KnowledgeEntry.swift     # Struct — parsed knowledge file (title, content, tags, source)
├── AgentFile.swift          # Struct — parsed agent markdown
├── SkillFile.swift          # Struct — parsed skill markdown
├── AIMessage.swift          # Struct — in-memory chat messages
├── Enums.swift              # Navigation, task status, priority enums
└── WorkspaceConformance.swift # Protocol conformance for context engine
```

## Context Pipeline

The core innovation. Every AI interaction goes through this pipeline:

```
User Query
    │
    ▼
┌─────────────────────────────────┐
│  1. Context Engine (TF-IDF)     │
│     - Tokenize query            │
│     - Score all chunks (BM25)   │
│     - Apply scope filters       │
│     - Dedup results             │
│     - Token budget allocation   │
└───────────────┬─────────────────┘
                │
    ┌───────────┼───────────┐
    ▼           ▼           ▼
┌─────────┐ ┌────────┐ ┌──────────┐
│Knowledge│ │Workspace│ │Conversa- │
│RAG      │ │Context  │ │tion      │
│(chunks) │ │(scored) │ │Summary   │
└────┬────┘ └───┬────┘ └────┬─────┘
     │          │           │
     └──────────┼───────────┘
                │
                ▼
┌─────────────────────────────────┐
│  2. System Prompt Assembly      │
│     - Agent instructions        │
│     - Matched rules             │
│     - Scoped knowledge          │
└───────────────┬─────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│  3. Claude CLI / MCP Dispatch   │
│     - Direct query (no tools)   │
│     - MCP query (with tools)    │
│     - Model selection           │
└───────────────┬─────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│  4. Response + Side Effects     │
│     - Display in chat           │
│     - Persist to conversation   │
│     - Auto-extract knowledge    │
│     - Rebuild index             │
└─────────────────────────────────┘
```

### TF-IDF Indexing (ContextEngine)

Cached in RAM; rebuilt only when knowledge content changes (version-gated):

1. **Tokenization** — lowercase, strip stop words (150+), filter tokens >2 chars, apply suffix stemmer (`-ing`, `-ed`, `-tion`, `-ness`, `-ment`, `-ly`, plurals)
2. **Term Frequency (TF)** — normalized frequency per document
3. **Inverse Document Frequency (IDF)** — `log((N - df + 0.5) / (df + 0.5) + 1)`
4. **BM25 Scoring** — `IDF × TF_norm` with `k1=1.5, b=0.75` length normalization; knowledge chunks only (`entry_type = "knowledge"`)
5. **Boosting** — title match (1.5x), tag match (1.3x), recency (exp decay over 90 days), project scope (1.5x)
6. **Relevance window** — sliding window finds highest query-term density region instead of naive front-truncation
7. **Chunking** — `SemanticChunker`: max 500 chars, sentence-boundary split, last-sentence overlap
8. **Dedup** — hash fingerprinting + Jaccard similarity (threshold 0.75)

### Vector Storage (VectorStore)

SQLite database at `~/DeepThink/data/vectors.db` (WAL mode):
- Single `chunks` table: id, entry_id, entry_type, title, content, tags, source, imported_at, chunk_index, total_chunks, content_hash, embedding (Float32 BLOB)
- Indexes: entry_id, entry_type, source, content_hash
- Shared between Swift app and CLI — both read/write the same file
- Entry types: `knowledge` (knowledge base), `workspace` (tasks + notes indexed by CLI for semantic retrieval)
- Replaces old `embeddings.json` + `embedding_hashes.json`

### Token Budget Management

Every context component gets a token allocation:

| Component | Default Budget | Strategy |
|-----------|---------------|----------|
| Knowledge RAG | 4000 tokens | Top chunks by score, truncate at sentence |
| Workspace context | 600 tokens | Query-relevant notes/tasks only |
| Conversation summary | 400 tokens | Older messages summarized, recent kept verbatim |
| Agent knowledge | 2000 tokens | Scope-filtered + query-relevant |
| System prompt | Varies | Agent instructions + matched rules |

Total per query: ~5-7K tokens typical (down from unbounded).

## Knowledge Collection

### Sources

| Source | Method | Scheduling |
|--------|--------|-----------|
| Web pages | HTML scraping → markdown | Manual or recurring |
| RSS/Atom feeds | Feed parsing → article scraping | Recurring intervals |
| Folders | File watch (incremental sync) | Recurring intervals |
| Clipboard | System pasteboard capture | Manual or recurring |
| Scripts | Shell execution → output capture | Recurring intervals |
| Conversations | Auto-extract every 6 messages | Automatic |
| Notes | Auto-extract facts when >30 words | Automatic |
| MCP servers | Via MCP protocol | On-demand |

### Knowledge Entry Format

All entries stored as markdown with YAML frontmatter:

```markdown
---
title: Article Title
source: url
url: https://example.com/article
tags: [research, ai, retrieval]
imported_at: 2026-05-03T10:30:00Z
---

Article content in markdown...
```

### Deduplication

Three-layer dedup prevents redundant entries:

1. **Hash fingerprint** — exact content match (fast, O(1) lookup)
2. **Jaccard similarity** — near-duplicate detection (>75% term overlap)
3. **Incremental sync** — folder watcher only copies new/modified files

## AI Assistants

Assistants are markdown files with YAML frontmatter in `.claude/agents/`:

```markdown
---
name: Researcher
role: Deep-dives into knowledge, synthesizes findings
icon: magnifyingglass.circle
knowledge_scope: [web, manual]
built_in: true
---

You are a research agent. Your job is to...
```

### Context Assembly for Agents

When a user chats with an agent:

1. Agent's system prompt loaded from markdown body
2. Matching rules appended (trigger-based)
3. Knowledge scope + query → TF-IDF retrieval → scoped context injected
4. Full prompt = RAG context + workspace context + user query

### Built-in Templates

6 starter templates for non-technical users:
- Research Assistant
- Writing Coach
- Task Planner
- Meeting Notes
- Idea Brainstormer
- Code Explainer

## Automations

### Skills

Reusable AI actions with template variables (`{{input}}`):

```markdown
---
name: Summarize
trigger: manual
icon: text.justify.leading
category: Writing
---

You are a concise summarizer. Output only bullet points.

---

Summarize the following in 2-3 bullet points:

{{input}}
```

Skills auto-inject relevant knowledge context during execution.

### Rules

Always-on instructions that inject into agent system prompts:

```markdown
---
name: Writing Style
trigger: always
icon: textformat
category: Writing
---

When helping with writing:
- Be concise and direct
- Use active voice
- Avoid jargon unless technical context
```

## MCP Integration

MCP servers extend AI with external tool access:

```
User query → Detect tool need → Write MCP config JSON
    → Claude CLI --mcp-config → Tool calls → Response
```

The app includes its own MCP server (`deepthink-mcp`) with 45 tools:
- `workspace_list/get/create/update/delete_task` + `workspace_list/get/create/update/delete_note`
- `workspace_list/get/create/update/delete_project` + `workspace_list/get/create/update/delete_reminder`
- `workspace_summary`, `smart_query`, `knowledge_context`, `workspace_context`, `deepthink_overview`
- `knowledge_stats/list_projects/load_project/save_project/search/list_integrations/load_integration/capture`
- `agent/rule/skill list/get/create/delete`

## CLI Architecture

```
cli/src/
├── index.ts           # CLI entry (ask, run, react, insight, research, schedule, context, knowledge, task, note, project, workspace, search, analyze, docs)
├── mcp-server.ts      # MCP server (45-tool workspace access for Claude/Cursor/etc)
├── config.ts          # Paths, settings
├── core/              # context-engine, db, embedding-service, vector-store, llm, sandbox
├── agents/
│   ├── base.ts        # Agent base class — think(), memory integration, output logging
│   ├── memory.ts      # Per-agent persistent memory (observations, corrections, facts) at data/agent-memory/
│   ├── scheduler.ts   # Job scheduler — daily-brief (20h), stale-tasks (7d), insight-scan (4h)
│   ├── daily-brief.ts # DailyBriefAgent — workspace snapshot → pinned "Daily Brief" note
│   ├── insight.ts     # InsightAgent — scans overdue/stale/blocked/cluster patterns → data/insights.json
│   ├── stale-task.ts  # StaleTaskAgent — 14+ day stale task triage report
│   ├── react.ts       # ReactAgent — THOUGHT/ACTION/PARAMS ReAct loop with 12+ tools, max 12 steps
│   ├── research.ts    # ResearchPipeline — generates Qs, searches web+local, synthesizes, saves
│   ├── planner.ts     # Planner — multi-step task decomposition
│   ├── executor.ts    # Executor — runs planner steps
│   ├── writer.ts      # Writer — structured doc generation
│   ├── analyst.ts     # Analyst — data/CSV analysis
│   └── workspace.ts   # WorkspaceAgent — NL workspace mutations
└── tools/             # workspace, knowledge, search, file, smart-mcp implementations
```

Built with Bun, compiled to standalone binaries. Shares the same data directory (`~/DeepThink/`) with the app.

## Agent System (CLI)

### Agent Base Class (`base.ts`)

All agents extend `Agent`. `think(prompt)` prepends per-agent persistent memory to the system prompt, calls Claude, then appends the interaction as an observation to memory.

```
agent.think(prompt)
    ↓
buildMemoryContext(agentId) → prepend to systemPrompt
    ↓
query(prompt, systemPrompt) → Claude response
    ↓
appendObservation(agentId, preview)   # persists to data/agent-memory/<id>.json
saveIntegrationData("agent", id, ...)  # logs output to knowledge integrations
```

### Agent Memory (`memory.ts`)

Stored at `~/DeepThink/data/agent-memory/<agentId>.json`:

| Field | Capacity | Purpose |
|-------|----------|---------|
| `observations` | last 20 | Recent prompt→response previews |
| `corrections` | last 10 | User-provided corrections injected into system prompt |
| `facts` | unlimited (key-value) | Named facts the agent should remember |

### Scheduled Jobs (`scheduler.ts`)

State at `~/DeepThink/data/schedule-state.json`. Jobs run via `deepthink schedule run` or triggered from the app's General Settings → AI Agents panel.

| Job | Agent | Interval | Output |
|-----|-------|----------|--------|
| `daily-brief` | `DailyBriefAgent` | Every 20h | Pinned "Daily Brief" note |
| `stale-tasks` | `StaleTaskAgent` | Every 7 days | Triage report note |
| `insight-scan` | `InsightAgent` | Every 4h | `data/insights.json` |

### Insight Types (`InsightAgent`)

| Type | Trigger | Severity |
|------|---------|----------|
| `overdue_tasks` | Any task past due date | action |
| `high_priority_stale` | High/Urgent task not updated in 7+ days | warning |
| `blocked_tasks` | "In Progress" task stuck 5+ days | warning |
| `stale_project` | Project inactive 21+ days with open tasks | info |
| `task_cluster` | 5+ unassigned tasks — AI detects project theme | info |

### ReAct Agent (`react.ts`)

THOUGHT / ACTION / PARAMS loop up to 12 steps. Available tools: all workspace CRUD, `knowledge_search`, `unified_search`, `knowledge_save`, `read_file`, `write_file`, `search_web`.

### Research Pipeline (`research.ts`)

1. Generate N research questions (Planner)
2. For each question: hybrid search local knowledge + web search
3. Extract key findings per question (Agent)
4. Synthesize across all questions (Writer)
5. Save structured note + optionally save to knowledge base

## Additional Data Storage

| Data | Location | Persistence |
|------|----------|-------------|
| Proactive insights | `data/insights.json` | Written by InsightAgent each scan |
| Scheduler state | `data/schedule-state.json` | Last-run timestamps per job |
| Agent memory | `data/agent-memory/<id>.json` | Per-agent observations/corrections/facts |

## Design System

Monochrome + single accent color (blue). Key tokens:

| Token | Value |
|-------|-------|
| Spacing | xs=4, sm=8, md=12, lg=16, xl=24, xxl=32 |
| Radius | sm=6, md=8, lg=12 |
| Font sizes | title=18, heading=14, body=13, caption=11, small=10 |
| Sidebar | 200pt expanded, 52pt collapsed |
| Toolbar | 44pt height |
| Row | 36pt height |

Key components: `DSPageHeader`, `DSCard`, `DSEmptyState`, `DSHelpButton`, `DSActionButton`, `DSSearchField`, `DSTabButton`, `DSToolbarButton`, `DSStatChip`, `DSPill`.
