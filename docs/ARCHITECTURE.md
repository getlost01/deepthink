# DeepThink Architecture

## System Overview

DeepThink has three connected surfaces that share one local data directory (`~/DeepThink/`). The **`deepthink-mcp`** MCP server and **`deepthink`** CLI are the primary, agent-agnostic tools — they work with any AI agent or shell workflow with no Claude dependency. The **native macOS app** is the complementary visual interface; its AI chat requires the Claude CLI, but the workspace data it manages is accessible to any surface.

| Surface | Agent requirement |
|---------|------------------|
| `deepthink-mcp` MCP server | **None** — works with Cursor, Claude Code, Windsurf, VS Code Copilot, or any MCP-capable host |
| `deepthink` CLI | **None** — model-agnostic; `deepthink ask` works with whatever LLM you wire up |
| In-app AI (chat, agents, skills, rules) | **Claude CLI** required — spawned as a local subprocess |

```text
  External AI agents          Shell / scripts          Claude CLI (optional)
  Cursor · Windsurf           cron · git hooks         in-app AI chat only
  VS Code Copilot             deepthink CLI                    │
  Claude Code · any MCP       model-agnostic                   │ subprocess
        │ MCP stdio                  │                          ▼
        ▼                            │              ┌────────────────────────────┐
  deepthink-mcp                      │              │    macOS App (SwiftUI)     │
  51 tools · any agent               │              │ Workspace · Knowledge      │
  readonly flag                      │              │ AI Chat · Terminal · ⌘K   │
        │                            │              └──────────────┬─────────────┘
        └────────────────────────────┘                             │
                     │ shared data directory ◄─────────────────────┘
        ┌────────────▼───────────────────────────────────────────┐
        │                  ~/DeepThink/                          │
        │                                                        │
        │  data/deepthink.store  (SwiftData / SQLite WAL)       │
        │  data/vectors.db       (embeddings · Float32)         │
        │  knowledge/            (markdown FS)                  │
        │  .claude/agents|rules|commands                        │
        └────────────────────────────────────────────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| App | SwiftUI, macOS 14+, MVVM + Observable |
| Persistence | SwiftData (Core Data / SQLite), WAL mode |
| Embeddings | SQLite `vectors.db`, Apple NLEmbedding (Float32 BLOB) |
| AI | Claude CLI (`~/.local/bin/claude`), JSON output mode |
| CLI/MCP | Bun + TypeScript, compiled to standalone binaries |
| Terminal | SwiftTerm (embedded terminal views) |
| Build | XcodeGen (`project.yml`), Bun bundler |

---

## Data Layer

### deepthink.store (SwiftData / Core Data SQLite)

The primary database for all workspace entities. Opened by the app via SwiftData. The CLI accesses it via direct SQLite (WAL mode, 5-second busy timeout). Both can read and write concurrently.

Entities (Core Data table names in parentheses):

| Entity | Table | Key Fields |
|--------|-------|-----------|
| Task | `ZTASKITEM` | title, status, priority, dueDate, projectId, storyPoints |
| Note | `ZNOTE` | title, content, projectId, tags, pinned, updatedAt |
| Project | `ZPROJECT` | name, summary, color, archived |
| Reminder | `ZREMINDER` | title, notes, dueDate, completed |

Additional tables managed by Core Data:
- `Z_PRIMARYKEY` — Core Data entity sequence counters
- `dt_audit_log` — every create/update/delete operation logged (see Governance)
- `dt_trash` — full row snapshot before every hard delete (see Governance)

### vectors.db (Embeddings)

Shared SQLite database at `~/DeepThink/data/vectors.db`. Both the Swift app (`VectorStore.swift`) and CLI (`vector-store.ts`) read and write to this file. WAL mode enabled. Float32 BLOB embeddings from Apple NLEmbedding.

Schema — `chunks` table (primary data store):



| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | `{entry_id}:{chunk_index}` |
| `entry_id` | TEXT | Source entry identifier |
| `entry_type` | TEXT | `knowledge`, `task`, `note`, `reminder` |
| `title` | TEXT | Entry title |
| `content` | TEXT | Chunk text |
| `tags` | TEXT | JSON array |
| `source` | TEXT | Source bucket/type |
| `imported_at` | REAL | Unix timestamp |
| `chunk_index` | INTEGER | Position in entry |
| `total_chunks` | INTEGER | Total chunks for entry |
| `content_hash` | INTEGER | djb2 hash for change detection |
| `embedding` | BLOB | Float32 array (~512 dims, Apple NLEmbedding) |

Schema — `pending_reindex` table (durable retry queue):

| Column | Type | Description |
|--------|------|-------------|
| `entry_id` | TEXT | Primary key — one row per entry awaiting (re)index |
| `entry_type` | TEXT | `knowledge`, `task`, `note`, `reminder` |
| `operation` | TEXT | `upsert` or `delete` |
| `queued_at` | INTEGER | Unix timestamp when enqueued |
| `retry_count` | INTEGER | Incremented on failure; `retry_count` is preserved on re-enqueue so keystroke-driven re-queuing does not reset the cap |

Entries with `retry_count >= 3` are pruned by `deleteExhaustedPendingReindex()` at the end of each reconciler drain cycle.

### Knowledge Filesystem

Markdown files with YAML frontmatter at `~/DeepThink/knowledge/`. Organized as:

```text
knowledge/
├── projects/{slug}/
│   ├── context.md        # running project context
│   ├── decisions.md      # decision log
│   └── artifacts/        # supporting files
├── integrations/{source}/{channel}/*.md
└── archive/              # compressed/archived entries
```

Archived entries (`source == 'archive'`) are excluded from all retrieval by default.

---

## Write Paths

### App → SwiftData

Standard SwiftData mutations via `ModelContext`. Changes immediately visible within the app. No explicit sync needed.

### CLI/MCP → SQLite → Darwin Sync → App

```text
MCP tool call / CLI command
    │
    ▼
db.ts — parameterized SQLite INSERT/UPDATE/DELETE
    │
    ├── dt_audit_log: INSERT (entity_type, entity_pk, operation, snapshot, changed_at)
    │
    ├── dt_trash: INSERT full row snapshot before hard DELETE
    │
    └── notifyutil -p com.deepthink.workspace.changed
            │
            ▼
        Darwin notification received by macOS
            │
            ▼
        CLISyncService.swift — DistributedNotificationCenter listener
            │
            ▼
        NotificationCenter.post(.cliWorkspaceChanged)
            │
            ▼
        AppState.externalSyncToken += 1
            │
            ▼
        SwiftUI re-render (token change triggers view refresh)
```

The Darwin notification (`notifyutil`) fires after every mutating CLI/MCP operation. The Swift app receives it via `CLISyncService` and updates `AppState.externalSyncToken`, which causes all dependent SwiftUI views to re-fetch data.

---

## Governance Layer

### dt_audit_log

Every create, update, and delete operation on workspace entities is logged:

| Column | Type | Description |
|--------|------|-------------|
| `entity_type` | TEXT | `task`, `note`, `project`, `reminder` |
| `entity_pk` | TEXT | Primary key of the affected row |
| `operation` | TEXT | `create`, `update`, `delete` |
| `snapshot` | TEXT | JSON snapshot of the row at time of write |
| `changed_at` | INTEGER | Unix milliseconds |

### dt_trash

Full row snapshot saved before every hard delete:

| Column | Type | Description |
|--------|------|-------------|
| `entity_type` | TEXT | `task`, `note`, `project`, `reminder` |
| `entity_pk` | TEXT | Primary key of the deleted row |
| `snapshot` | TEXT | Full JSON row snapshot |
| `deleted_at` | INTEGER | Unix milliseconds |

### Read/Write Boundary

All read-only MCP tools carry `readonly: true` in their tool definition. Mutating tools do not. This allows MCP clients that support capability inspection to distinguish safe read operations from state-changing ones.

Read-only tools: `workspace_list_tasks`, `workspace_get_task`, `workspace_list_notes`, `workspace_get_note`, `workspace_list_projects`, `workspace_get_project`, `workspace_list_reminders`, `workspace_get_reminder`, `workspace_summary`, and all smart/context query tools.

### SwiftData Cascade Deletes

`Project` carries `deleteRule: .cascade` on its `notes`, `tasks`, and `reminders` relationships. `TaskItem` carries `deleteRule: .cascade` on its `subtasks` relationship. Deleting a project from SwiftData automatically deletes all owned notes, tasks, reminders, and nested subtasks — no manual cleanup needed.

### Vector Cascade Delete

When an entity is deleted (task, note, project, reminder, knowledge entry), all associated chunks in `vectors.db` are deleted via a cascade query keyed on `entry_id`. Projects also cascade-delete all chunks for entries belonging to that project.

---

## Service Layer (Swift App)

Key services in `DeepThink/Services/`:

| Service | Role |
|---------|------|
| `ClaudeService.swift` | Claude CLI wrapper — query, model selection, streaming, cost tracking |
| `ContextEngine.swift` | BM25 index, hybrid RRF retrieval, chunk dedup, token budget management |
| `EmbeddingService.swift` | NLEmbedding vectors, SemanticChunker, incremental indexing, NaN guard, `pending_reindex` reconciler |
| `VectorStore.swift` | SQLite CRUD for `vectors.db` — thread-safe `queue.sync` reads, WAL mode, Float32 BLOB, `pending_reindex` table |
| `CLISyncService.swift` | Darwin notification listener, bridges CLI writes to SwiftUI refresh |
| `KnowledgeService.swift` | Knowledge FS CRUD, incremental scanning (changed-since `lastScanAt`), multi-line YAML frontmatter, collision-safe archive move |
| `MCPService.swift` | MCP server config generation, keyword detection, tool-augmented query dispatch |
| `InstallationManager.swift` | CLI binary installation to `~/.local/bin/`, version checks |
| `AgentFileService.swift` | Agent CRUD, context-aware prompt building |
| `SkillFileService.swift` | Skill CRUD, template interpolation, execution |
| `RuleFileService.swift` | Rule CRUD, trigger matching, prompt injection |
| `ArchiveService.swift` | Auto-archives completed tasks after threshold (configurable); runs at startup and hourly via `Timer` |
| `DataCollectorService.swift` | URL scraping, RSS, clipboard, folders, scripts |
| `KnowledgeExtractionService.swift` | Auto-extract facts, auto-tag, chat→knowledge |
| `BacklinkService.swift` | Wiki-link parsing, note↔knowledge cross-linking |
| `CollectorScheduler.swift` | Recurring data collection — FSEvents `FolderWatcher` for folder sources, `Timer` for all others |
| `StorageService.swift` | Directory structure, paths, logging |
| `TaskNotificationService.swift` | macOS notifications for due/overdue tasks |
| `BackupService.swift` | Workspace backup snapshots — create, list, restore full data-directory archives |
| `VersioningService.swift` | Note version history — snapshot on save, diff, restore to any prior version |
| `ObsidianImportService.swift` | Obsidian vault import — parse `[[wikilinks]]`, tags, and frontmatter into knowledge entries |
| `DeadLinkScanner.swift` | Scans all notes for broken `[[wikilinks]]` and reports unresolved targets |
| `MCPCatalogService.swift` | Discovery and management of third-party MCP servers configured in the app |
| `DeepThinkCLIService.swift` | Wrapper around the `deepthink` CLI binary — runs commands and streams output into the app |
| `GlobalHotKey.swift` | Registers system-wide Carbon hotkeys for quick-capture and command palette |
| `UpdateService.swift` | Sparkle-based auto-update checks and in-app update prompts |

---

## CLI/MCP Layer (Bun/TypeScript)

Source at `cli/src/`, compiled to `cli/out/deepthink` and `cli/out/deepthink-mcp`. Both binaries are bundled into the app resources via Xcode post-compile script and installed to `~/.local/bin/` on first launch.

### Core Modules

| File | Role |
|------|------|
| `core/db.ts` | Parameterized SQLite access — all reads and writes to `deepthink.store`; populates `dt_audit_log` and `dt_trash`; fires `notifyutil` after mutations |
| `core/context-engine.ts` | BM25 index build and query, hybrid RRF retrieval, workspace context assembly, archive exclusion |
| `core/embedding-service.ts` | Query embedding via `embed-helper` Swift binary, cosine similarity, incremental indexing, NaN/Infinite validation |
| `core/vector-store.ts` | SQLite CRUD for `vectors.db` — parameterized queries, chunk management, `chunksForEntryIds()` optimization, `pending_reindex` queue |
| `core/llm.ts` | Claude CLI wrapper for CLI-side AI queries |
| `core/sandbox.ts` | Output directory management |

### Tool Modules (MCP)

| File | Role |
|------|------|
| `tools/workspace.ts` | Workspace CRUD MCP tools — tasks, notes, projects, reminders, deep links, `workspace_reindex` |
| `tools/knowledge-mcp.ts` | Knowledge base MCP tools — load, save, search, compress, archive, integrations |
| `tools/smart-mcp.ts` | Smart context MCP tools — `smart_query`, `knowledge_context`, `workspace_context`, `unified_search`, `deepthink_overview` |
| `tools/config-mcp.ts` | Agent, rule, and skill CRUD MCP tools |

### CLI-Only Tool Modules

| File | Role |
|------|------|
| `tools/knowledge.ts` | CLI-side knowledge commands (non-MCP) |
| `tools/search.ts` | CLI search command |
| `tools/file.ts` | CLI file-based operations |
| `tools/analytics.ts` | CLI analytics and stats output |
| `tools/memory.ts` | CLI memory/compaction helpers |

### Agent System

13 agent modules in `agents/` implement the CLI's autonomous reasoning layer:

| File | Role |
|------|------|
| `agents/base.ts` | Base agent class — tool loop, context injection |
| `agents/research.ts` | Deep-research agent — multi-step knowledge retrieval |
| `agents/planner.ts` | Task planning and decomposition |
| `agents/executor.ts` | Task execution with tool use |
| `agents/react.ts` | ReAct-style reasoning agent |
| `agents/analyst.ts` | Data analysis and insight generation |
| `agents/writer.ts` | Long-form writing with workspace context |
| `agents/insight.ts` | Periodic insight synthesis |
| `agents/scheduler.ts` | Schedule management agent |
| `agents/daily-brief.ts` | Morning briefing generation |
| `agents/stale-task.ts` | Stale task detection and nudges |
| `agents/workspace.ts` | Workspace-aware agent helper |
| `agents/memory.ts` | Agent memory access layer |

### Memory Modules

| File | Role |
|------|------|
| `memory/manager.ts` | Conversation memory store — persist and retrieve agent memory across sessions |
| `memory/compressor.ts` | Compress old memory entries to stay within token budgets |

### Entry Points

| File | Role |
|------|------|
| `index.ts` | CLI entry point and command routing |
| `mcp-server.ts` | MCP server — registers all 51 tools and 8 resources |

---

## RAG Pipeline (Shared Logic)

Both the Swift app and CLI implement the same hybrid retrieval algorithm:

1. **Tokenize + stem** — lowercase, 150+ stopwords, suffix stemmer
2. **BM25** — k1=1.5, b=0.75; title boost ×1.5, tag boost ×1.3, recency decay e^(-days/90); threshold >0.1; archive excluded
3. **Semantic** — Apple NLEmbedding, cosine similarity threshold >0.3, top-k=20; input: `"{title}. {content.prefix(500)}"`; NaN/Infinite guard
4. **RRF fusion** — K=60: `score = 1/(K+bm25rank+1) + (semrank exists ? 1/(K+semrank+1) : 0)`
5. **Chunk loading** — `chunksForEntryIds()` loads only needed chunks (no full table scan)
6. **Context assembly** — token-budgeted injection into system prompt

See [rag-pipeline.md](rag-pipeline.md) and [semantic-search.md](semantic-search.md) for full details.

---

## Design System

All UI uses tokens defined in `DeepThink/Views/Shared/DesignSystem.swift` (`DS` namespace). Raw Color literals, ad-hoc fonts, and bare `.buttonStyle(.plain)` are prohibited — every clickable element must use `.buttonStyle(.plainPointer)`, `.buttonStyle(.dsPrimary)`, or `.buttonStyle(.dsSecondary)` to ensure the pointer cursor.

| Token group | Values |
|-------------|--------|
| Spacing | xs=4, sm=8, md=12, lg=16, xl=24, xxl=32 |
| Radius | sm=6, md=8, lg=12 |
| Font sizes | title=18, heading=14, body=13, caption=11, small=10 |

---

## Related Docs

- [RAG Pipeline](rag-pipeline.md)
- [Semantic Search](semantic-search.md)
- [Storage Layout](storage.md)
- [MCP Integration](mcp-integration.md)
- [CLI Reference](cli/commands.md)
