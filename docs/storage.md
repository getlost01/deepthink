# Data Storage

All DeepThink data lives in `~/DeepThink/` on your Mac. Nothing leaves your machine.

## Directory Layout

```text
~/DeepThink/
├── data/
│   ├── deepthink.store          # SwiftData SQLite (notes, tasks, projects, conversations)
│   ├── vectors.db               # Chunks + embeddings (Float32 BLOB), shared by app and CLI
│   ├── insights.json            # Saved proactive insights
│   ├── schedule-state.json      # Scheduler last-run timestamps
│   └── agent-memory/            # Per-agent persistent memory (observations, facts)
├── knowledge/                   # Knowledge base (markdown + YAML frontmatter)
│   ├── general/                 # Default bucket
│   ├── web/                     # Scraped web pages
│   ├── clipboard/               # Clipboard captures
│   ├── manual/                  # User-created entries
│   ├── imports/                 # Imported content (Obsidian vaults, files)
│   ├── integrations/            # External data sources
│   ├── projects/                # Per-project knowledge
│   ├── research/                # Research captures
│   ├── scripts/                 # Script-collected data
│   ├── archive/                 # Compressed entries
│   └── index.json               # Knowledge index (titles, tags, metadata)
├── .claude/                     # AI configuration files
│   ├── commands/                # Skills (markdown with YAML frontmatter)
│   ├── rules/                   # Rules (markdown with YAML frontmatter)
│   └── agents/                  # Agents (markdown with YAML frontmatter)
├── memory/                      # Persistent AI memory
├── sandbox/                     # Generated docs, analysis outputs
├── tools/                       # Tool outputs
├── logs/                        # App and terminal logs
└── workspace/                   # Exported notes/projects
```

## Index Storage

| Data | Location | Notes |
|------|----------|-------|
| BM25/TF-IDF index | RAM | Rebuilt only when knowledge changes (version-gated) |
| Chunks + embeddings | `data/vectors.db` | SQLite WAL, Float32 BLOB, shared by app and CLI |
| Content hashes | RAM + `data/vectors.db` | Per-chunk, used for change detection |
| Knowledge entries | RAM (30s TTL) | Disk re-read at most once per 30s |
| Conversation summaries | RAM | Regenerated as needed |

## Shared Access

The Swift app and CLI (`deepthink`, `deepthink-mcp`) share the same data directory. Both read and write to the same knowledge base and vector store. SwiftData models (notes, tasks) are accessed by the CLI via the MCP bridge.

## vectors.db Schema

The `chunks` table in `vectors.db`:

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

## Resetting Data

To start fresh, delete `~/DeepThink/`. The app will recreate the directory structure on next launch.

To reset only embeddings (force re-index): delete `~/DeepThink/data/vectors.db`.
