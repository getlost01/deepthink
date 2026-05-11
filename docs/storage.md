# Data Storage

All DeepThink data lives in `~/DeepThink/` on your Mac. Nothing leaves your machine.

## Directory Layout

```text
~/DeepThink/
├── data/
│   ├── deepthink.store          # SwiftData SQLite (tasks, notes, projects, reminders, audit log, trash)
│   ├── vectors.db               # Chunks + embeddings (Float32 BLOB), shared by app and CLI
│   ├── insights.json            # Saved proactive insights
│   ├── schedule-state.json      # Scheduler last-run timestamps
│   └── agent-memory/            # Per-agent persistent memory (observations, facts)
├── knowledge/                   # Knowledge base (markdown + YAML frontmatter)
│   ├── projects/{slug}/
│   │   ├── context.md           # Running project context
│   │   ├── decisions.md         # Decision log
│   │   └── artifacts/           # Supporting files
│   ├── integrations/{source}/{channel}/*.md
│   ├── archive/                 # Compressed/archived entries (excluded from search by default)
│   └── index.json               # Knowledge index (titles, tags, metadata)
├── .claude/                     # AI configuration files
│   ├── commands/                # Skills (markdown with YAML frontmatter)
│   ├── rules/                   # Rules (markdown with YAML frontmatter)
│   └── agents/                  # Agents (markdown with YAML frontmatter)
├── .cache/
│   └── embed-helper             # Compiled Swift binary for NLEmbedding (auto-built on first use)
├── memory/                      # Persistent AI memory
├── sandbox/                     # Generated docs, analysis outputs
├── logs/                        # App and terminal logs
└── workspace/                   # Exported notes/projects
```

---

## deepthink.store Schema

SwiftData uses Core Data's SQLite backend. Table names follow Core Data conventions (uppercase Z prefix).

### ZTASKITEM

| Column | Type | Notes |
|--------|------|-------|
| `Z_PK` | INTEGER | Primary key |
| `ZTITLE` | TEXT | Task title |
| `ZSTATUS` | TEXT | `Todo`, `In Progress`, `Done`, `Cancelled` |
| `ZPRIORITY` | TEXT | `low`, `medium`, `high`, `urgent` |
| `ZDUEDATE` | REAL | Unix timestamp, nullable |
| `ZPROJECT` | INTEGER | FK to ZPROJECT |
| `ZSTORYPOINTSVALUE` | INTEGER | Story points, nullable |
| `ZUPDATEDAT` | REAL | Unix timestamp |
| `ZCREATEDAT` | REAL | Unix timestamp |

### ZNOTE

| Column | Type | Notes |
|--------|------|-------|
| `Z_PK` | INTEGER | Primary key |
| `ZTITLE` | TEXT | Note title |
| `ZCONTENT` | TEXT | Markdown content |
| `ZPROJECT` | INTEGER | FK to ZPROJECT, nullable |
| `ZTAGS` | TEXT | JSON array of tag strings |
| `ZPINNED` | INTEGER | Boolean (0/1) |
| `ZUPDATEDAT` | REAL | Unix timestamp |
| `ZCREATEDAT` | REAL | Unix timestamp |

### ZPROJECT

| Column | Type | Notes |
|--------|------|-------|
| `Z_PK` | INTEGER | Primary key |
| `ZNAME` | TEXT | Project name |
| `ZSUMMARY` | TEXT | Short description, nullable |
| `ZCOLOR` | TEXT | Hex color string, nullable |
| `ZARCHIVED` | INTEGER | Boolean (0/1) |
| `ZCREATEDAT` | REAL | Unix timestamp |

### ZREMINDER

| Column | Type | Notes |
|--------|------|-------|
| `Z_PK` | INTEGER | Primary key |
| `ZTITLE` | TEXT | Reminder title |
| `ZNOTES` | TEXT | Additional notes, nullable |
| `ZDUEDATE` | REAL | Unix timestamp, nullable |
| `ZCOMPLETED` | INTEGER | Boolean (0/1) |
| `ZCREATEDAT` | REAL | Unix timestamp |

### Z_PRIMARYKEY

Core Data sequence counters — one row per entity type. Used internally by Core Data to generate primary keys. Do not modify directly.

### dt_audit_log

Every create, update, and delete on workspace entities is appended here by `db.ts`:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Autoincrement primary key |
| `entity_type` | TEXT | `task`, `note`, `project`, `reminder` |
| `entity_pk` | TEXT | Primary key of the affected row |
| `operation` | TEXT | `create`, `update`, `delete` |
| `snapshot` | TEXT | Full JSON snapshot of the row at time of write |
| `changed_at` | INTEGER | Unix milliseconds |

### dt_trash

Full row snapshot saved before every hard delete, written by `db.ts` before the DELETE statement executes:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Autoincrement primary key |
| `entity_type` | TEXT | `task`, `note`, `project`, `reminder` |
| `entity_pk` | TEXT | Primary key of the deleted row |
| `snapshot` | TEXT | Full JSON row snapshot |
| `deleted_at` | INTEGER | Unix milliseconds |

---

## vectors.db Schema

Single table: `chunks`.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | `{entry_id}:{chunk_index}` — primary key |
| `entry_id` | TEXT | Source entry identifier |
| `entry_type` | TEXT | `knowledge`, `task`, `note`, `reminder` |
| `title` | TEXT | Entry title (denormalized for fast retrieval) |
| `content` | TEXT | Chunk text |
| `tags` | TEXT | JSON array of tag strings |
| `source` | TEXT | Source bucket/type (e.g. `manual`, `web`, `archive`) |
| `imported_at` | REAL | Unix timestamp |
| `chunk_index` | INTEGER | Zero-based position within the entry |
| `total_chunks` | INTEGER | Total number of chunks for this entry |
| `content_hash` | INTEGER | djb2 hash of chunk content — used for change detection |
| `embedding` | BLOB | Float32 array (~512 dims, Apple NLEmbedding), little-endian |

Indexes: `entry_id` for cascade deletes and `chunksForEntryIds()` lookups; `entry_type` for type-filtered queries.

---

## Knowledge Filesystem

Entries are markdown files with YAML frontmatter:

```markdown
---
title: OAuth Token Design
source: manual
tags: [security, auth, api]
imported_at: 2026-05-04T10:30:00Z
---

Content in markdown...
```

**Projects layout:**

```text
knowledge/projects/{slug}/
├── context.md      # running project context (append-friendly)
├── decisions.md    # decision log
└── artifacts/      # arbitrary supporting files
```

**Integrations layout:**

```text
knowledge/integrations/{source}/{channel}/
└── {timestamp}-{slug}.md   # captured entries
```

**Archive:** `knowledge/archive/` holds compressed summaries. Files with `source: archive` in their frontmatter (or stored in the archive directory) are excluded from all BM25 and semantic retrieval by default.

---

## Concurrent Access and WAL Mode

Both `deepthink.store` and `vectors.db` are opened in WAL (Write-Ahead Logging) mode. This allows:

- The macOS app (SwiftData) and CLI (`deepthink`, `deepthink-mcp`) to read simultaneously without blocking
- One writer at a time with a 5-second busy timeout before the CLI returns an error
- Readers never blocked by a writer in WAL mode

The app opens `deepthink.store` exclusively via SwiftData. The CLI opens it directly via `better-sqlite3` with WAL pragmas set on connection open.

---

## Index Storage Summary

| Data | Location | Persistence |
|------|----------|-------------|
| BM25 index (term frequencies) | RAM | Rebuilt when knowledge version increments; not persisted |
| Chunks + embeddings | `data/vectors.db` | SQLite WAL, persisted, incremental updates via content_hash |
| Knowledge entries | `knowledge/**/*.md` | Markdown + YAML frontmatter on disk |
| Audit log | `data/deepthink.store` (`dt_audit_log`) | Persisted, append-only |
| Trash snapshots | `data/deepthink.store` (`dt_trash`) | Persisted, written before every hard delete |
| Agent memory | `data/agent-memory/<id>.json` | Persisted JSON per agent |

---

## Resetting Data

To reset embeddings only (forces full re-index on next launch):
```bash
rm ~/DeepThink/data/vectors.db
```

To reset the entire workspace (destructive — removes all tasks, notes, projects, knowledge):
```bash
rm -rf ~/DeepThink/
```

The app recreates the directory structure on next launch.
