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

Built in RAM on each retrieval call, scoring chunks from `VectorStore`:

1. **Tokenization** — lowercase, strip stop words (150+), filter tokens >2 chars
2. **Term Frequency (TF)** — normalized frequency per document
3. **Inverse Document Frequency (IDF)** — `log((N - df + 0.5) / (df + 0.5) + 1)`
4. **BM25 Scoring** — `IDF × TF_norm` with `k1=1.5, b=0.75` length normalization
5. **Boosting** — title match (1.5x), tag match (1.3x), recency (exp decay over 90 days), project scope (1.5x)
6. **Chunking** — `SemanticChunker`: max 500 chars, sentence-boundary split, last-sentence overlap
7. **Dedup** — hash fingerprinting + Jaccard similarity (threshold 0.75)

### Vector Storage (VectorStore)

SQLite database at `~/DeepThink/data/vectors.db` (WAL mode):
- Single `chunks` table: id, entry_id, entry_type, title, content, tags, source, imported_at, chunk_index, total_chunks, content_hash, embedding (Float32 BLOB)
- Indexes: entry_id, entry_type, source, content_hash
- Shared between Swift app and CLI — both read/write the same file
- Entry types: `knowledge`, `note`, `task`, `reminder`
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
├── index.ts           # CLI entry point (commands: ask, run, context, knowledge, task, note, project, workspace, search, analyze, docs)
├── mcp-server.ts      # MCP server (workspace tools for Claude)
├── config.ts          # Paths, settings
├── core/              # Shared utilities
├── agents/            # Agent loading and prompt building
├── memory/            # Persistent memory management
└── tools/             # Tool implementations
```

Built with Bun, compiled to standalone binaries. Shares the same data directory (`~/DeepThink/`) with the app.

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
