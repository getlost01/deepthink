# CLI

Command-line interface for headless workspace management, AI queries, and automation. Built with Bun + TypeScript, compiled to standalone binaries.

## Installation

```bash
# Build CLI tools
cd cli && bun install && bun run build:all && cd ..

# Auto-installed to ~/.local/bin/ on app launch:
# - deepthink (main CLI)
# - deepthink-mcp (MCP server)
```

## Commands

### Context Retrieval

Token-efficient workspace context for AI integrations:

```bash
deepthink context overview                       # compact counts + top items (~200 tokens)
deepthink context query "What's blocking v2?"    # hybrid retrieval (BM25 + semantic)
deepthink context query "auth flow" --bm25       # keyword-only (skip semantic)
deepthink context semantic "authentication"      # pure semantic vector search
deepthink context workspace "auth migration"     # relevant tasks/notes/reminders only
deepthink context knowledge "API design"         # BM25-scored knowledge chunks
```

### AI Queries

```bash
deepthink ask "What tasks need attention?" --recall --project MyProject
deepthink ask "Explain this error" --file ./error.log
```

Options:
- `--recall` - include workspace context
- `--project <name>` - scope to project
- `--file <path>` - include file content

### Multi-Step Task Execution

```bash
deepthink run "Analyze the codebase and create a migration plan" --project MyProject
```

Uses an agent pipeline:
1. **Planner** - breaks task into JSON step array with tool assignments
2. **Executor** - runs each step, calling tools as needed
3. **Writer** - produces markdown summary of results

### Workspace Management

Natural language workspace operations:

```bash
deepthink workspace "create a high-priority task for API migration due Friday"
```

Direct CRUD commands:

```bash
# Tasks
deepthink task list --status "In Progress" --project MyProject
deepthink task add "Review PR" --priority high --due 2026-05-10 --project MyProject
deepthink task show "Review PR"
deepthink task done "Review PR"

# Notes
deepthink note list --project MyProject --pinned
deepthink note add "Meeting Notes" --content "..." --project MyProject
deepthink note show "Meeting Notes"

# Projects
deepthink project list
deepthink project add "MyProject" --summary "API migration" --color "#FF6B6B"
```

### Knowledge Base

```bash
deepthink knowledge list
deepthink knowledge search "auth middleware" --source slack --limit 10
deepthink knowledge save MyProject "Decided to use JWT tokens" --type decision
deepthink knowledge load MyProject
deepthink knowledge capture slack general "Deploy completed successfully"
deepthink knowledge compress slack general
deepthink knowledge archive OldProject
```

### Search & Analysis

```bash
deepthink search "React server components"         # web search
deepthink search local "TODO" --dir ./src          # local file search

deepthink analyze data.csv --question "What are the trends?"
deepthink analyze data.csv --report --title "Q2 Analysis"
deepthink analyze quick data.csv                   # local stats only
```

### Documentation

```bash
deepthink docs "API Reference" --input ./src/api.ts --output api-docs
```

---

## Agent System

The CLI includes a multi-agent system for complex tasks:

| Agent | Role |
|-------|------|
| **Planner** | Breaks tasks into structured step arrays with tool assignments |
| **Executor** | Runs steps sequentially, handles errors, calls tools |
| **Writer** | Produces markdown summaries, docs, insights |
| **Analyst** | Analyzes data files, produces statistics and reports |
| **Workspace** | Specialized for workspace CRUD operations |

### Agent Flow

```text
deepthink run "task description"
    │
    ▼
Planner.think() → JSON steps [{action, tool, params}]
    │
    ▼
Executor runs each step → calls tools → collects results
    │
    ▼
Writer.think() → markdown summary
    │
    ▼
Output saved to sandbox/outputs/
```

---

## Available Tools

| Category | Tools |
|----------|-------|
| File | `write_file`, `read_file` |
| Search | `search_web`, `search_local` |
| Analytics | `analyze_file` |
| Knowledge | `save_knowledge`, `search_knowledge` |
| Workspace | `workspace_list_tasks`, `workspace_create_task`, `workspace_update_task`, etc. |

---

## Context Engine (CLI)

The CLI has its own hybrid retrieval engine matching the Swift app's capabilities. Both implement the same algorithm against the same shared databases.

### BM25 Keyword Search (`cli/src/core/context-engine.ts`)

- **Chunking:** sentence-boundary split, min 100 chars, max 500 chars, last-sentence overlap between adjacent chunks
- **Stopwords:** 150+ words, synchronized with the Swift app's stopword list
- **Tokenization:** lowercase, stopword removal, suffix stemmer (`-ing`, `-ed`, `-tion`, `-ness`, `-ment`, `-ly`, plurals)
- **Scoring:** BM25 with k1=1.5, b=0.75 length normalization
- **Boosting:** title match ×1.5, tag match ×1.3, recency decay e^(-days/90), project scope ×1.5
- **Threshold:** scores ≤0.1 discarded before fusion
- **Archive exclusion:** entries with `source == 'archive'` excluded from retrieval
- **Index caching:** built in RAM, rebuilt only when content version changes - not per query
- **Token estimation:** budget management for context assembly

### Semantic Search (`cli/src/core/embedding-service.ts`)

- **Shared DB:** reads and writes to `~/DeepThink/data/vectors.db` - the same file used by the Swift app
- **Query embedding:** compiled Swift helper at `~/DeepThink/.cache/embed-helper` using Apple `NLEmbedding.sentenceEmbedding(.english)` - identical model to the app
- **Input format:** `"{title}. {content.prefix(500)}"` for both indexing and queries
- **NaN/Infinite guard:** all embedding vectors validated before storage; corrupt vectors discarded
- **Cosine similarity threshold:** 0.3 minimum - results below discarded
- **Top-k:** 20 results returned before fusion
- **Incremental indexing:** `content_hash` (djb2) per chunk; unchanged chunks skipped on re-index
- **Independent operation:** CLI can index entries without the Swift app running

### Hybrid Retrieval (`retrieveContextHybrid`)

- Runs BM25 + semantic in parallel
- Merges via Reciprocal Rank Fusion: `score = 1/(60 + bm25_rank + 1) + (semrank exists ? 1/(60 + semrank + 1) : 0)`
- K=60; no penalty for an entry missing from one of the two lists
- Falls back to BM25-only if `vectors.db` has no embeddings
- Default for `context query` and MCP `smart_query` / `knowledge_context` tools
- Uses `chunksForEntryIds()` to load only chunks for entries that passed ranking - no full table scan of `vectors.db`

### unified_search

- Searches all four entity types simultaneously: `knowledge`, `task`, `note`, `reminder`
- Content field fully populated for workspace items (tasks, notes, reminders) - not truncated or empty
- Single semantic search pass shared across workspace and knowledge retrieval to avoid duplicate embedding lookups
- Archive entries excluded by default

---

## Shared Data

CLI and app share the same data directory (`~/DeepThink/`):

- Both read/write to the same `deepthink.store` (WAL mode, 5s busy timeout)
- Both read/write to the same `vectors.db` embeddings database
- Both use the same agents, skills, rules in `.claude/`
- CLI mutations fire a Darwin notification (`com.deepthink.workspace.changed`) received by `CLISyncService.swift` in the app, triggering a live SwiftUI refresh

---

## Key Files

```text
cli/src/
├── index.ts                   # CLI entry point, command routing
├── mcp-server.ts              # MCP server (45 tools)
├── config.ts                  # Paths, settings
├── core/
│   ├── context-engine.ts      # BM25 index, hybrid RRF retrieval, archive exclusion
│   ├── embedding-service.ts   # Semantic search via embed-helper, NaN guard, indexing
│   ├── vector-store.ts        # vectors.db SQLite layer, chunksForEntryIds()
│   ├── db.ts                  # deepthink.store access, dt_audit_log, dt_trash, notifyutil
│   ├── llm.ts                 # Claude CLI wrapper
│   └── sandbox.ts             # Output directory management
├── agents/
│   ├── planner.ts             # Task decomposition
│   ├── executor.ts            # Step execution
│   ├── writer.ts              # Summary generation
│   ├── analyst.ts             # Data analysis
│   └── workspace.ts           # Workspace operations
└── tools/                     # MCP tool implementations
    ├── workspace.ts
    ├── knowledge-mcp.ts
    ├── smart-mcp.ts
    └── config-mcp.ts
```
