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
deepthink context semantic "authentication"       # pure semantic vector search
deepthink context workspace "auth migration"     # relevant tasks/notes/reminders only
deepthink context knowledge "API design"          # BM25-scored knowledge chunks
```

### AI Queries

```bash
deepthink ask "What tasks need attention?" --recall --project MyProject
deepthink ask "Explain this error" --file ./error.log
```

Options:
- `--recall` — include workspace context
- `--project <name>` — scope to project
- `--file <path>` — include file content

### Multi-Step Task Execution

```bash
deepthink run "Analyze the codebase and create a migration plan" --project MyProject
```

Uses an agent pipeline:
1. **Planner** — breaks task into JSON step array with tool assignments
2. **Executor** — runs each step, calling tools as needed
3. **Writer** — produces markdown summary of results

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
deepthink search "React server components"        # web search
deepthink search local "TODO" --dir ./src          # local file search

deepthink analyze data.csv --question "What are the trends?"
deepthink analyze data.csv --report --title "Q2 Analysis"
deepthink analyze quick data.csv                   # local stats only
```

### Documentation

```bash
deepthink docs "API Reference" --input ./src/api.ts --output api-docs
```

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

```
deepthink run "task description"
    ↓
Planner.think() → JSON steps [{action, tool, params}]
    ↓
Executor runs each step → calls tools → collects results
    ↓
Writer.think() → markdown summary
    ↓
Output saved to sandbox/outputs/
```

## Available Tools

| Category | Tools |
|----------|-------|
| File | `write_file`, `read_file` |
| Search | `search_web`, `search_local` |
| Analytics | `analyze_file` |
| Knowledge | `save_knowledge`, `search_knowledge` |
| Workspace | `workspace_list_tasks`, `workspace_create_task`, `workspace_update_task`, etc. |

## Context Engine (CLI)

The CLI has its own hybrid retrieval engine matching the Swift app's capabilities:

### BM25 Keyword Search (`cli/src/core/context-engine.ts`)
- Sentence-boundary chunks, max 500 chars, min 100 chars, last-sentence overlap
- Stopword filtering (150+ words)
- BM25 scoring with k1=1.5, b=0.75 length normalization
- Title (1.5x), tag (1.3x), recency, and project scope boosting
- Frontmatter parsing for metadata
- Token estimation for budget management

### Semantic Search (`cli/src/core/embedding-service.ts`)
- Reads and writes to shared `~/DeepThink/data/vectors.db` (same DB as Swift app)
- Query embedding via compiled Swift helper (`~/DeepThink/.cache/embed-helper`) using Apple NLEmbedding
- Can index entries independently — does not require the Swift app to run first
- Cosine similarity search with 0.3 minimum threshold

### Hybrid Retrieval (`retrieveContextHybrid`)
- Runs BM25 + semantic in parallel
- Merges via Reciprocal Rank Fusion (RRF, k=60)
- Falls back to BM25-only if no embeddings available
- Default for `context query` and MCP `smart_query`/`knowledge_context` tools

## Shared Data

CLI and app share the same data directory (`~/DeepThink/`):
- Both read/write to the same knowledge base
- Both use the same agents, skills, rules
- SwiftData database (notes, tasks) accessed via MCP bridge

## Key Files

```
cli/src/
├── index.ts           # CLI entry point, command routing
├── mcp-server.ts      # MCP server (45 tools for Claude)
├── config.ts          # Paths, settings
├── core/
│   ├── context-engine.ts  # BM25 + hybrid retrieval for CLI
│   └── embedding-service.ts # Semantic search via NLEmbedding
├── agents/
│   ├── planner.ts     # Task decomposition
│   ├── executor.ts    # Step execution
│   ├── writer.ts      # Summary generation
│   ├── analyst.ts     # Data analysis
│   └── workspace.ts   # Workspace operations
├── memory/            # Persistent memory management
└── tools/             # Tool implementations
```
