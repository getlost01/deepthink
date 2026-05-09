# Knowledge Base

Multi-source knowledge capture, storage, and retrieval system. Everything stored as markdown files with YAML frontmatter — human-readable, version-control friendly, portable.

## Sources

| Source | How | Scheduling |
|--------|-----|-----------|
| **Web pages** | URL scraping → HTML to markdown | Manual or recurring |
| **RSS/Atom feeds** | Feed parsing → article scraping | Recurring |
| **Folders** | File watch with incremental sync | Recurring |
| **Clipboard** | System pasteboard capture | Manual or recurring |
| **Scripts** | Shell execution → output capture | Recurring |
| **Obsidian vaults** | One-click vault import with syntax conversion | Manual |
| **Quick Capture** | Option+Space from anywhere | Manual |
| **Conversations** | Auto-extract every 6 chat messages | Automatic |
| **Notes** | Auto-extract facts from notes >30 words | Automatic |
| **MCP servers** | Via Model Context Protocol | On-demand |
| **Manual entry** | Write directly in Knowledge UI | Manual |

## Storage Format

All entries stored as markdown with YAML frontmatter:

```markdown
---
title: OAuth Token Design
source: manual
bucket: General
tags: [security, auth, api]
imported_at: 2026-05-04T10:30:00Z
---

We use rotating refresh tokens with 15-minute access token TTL...
```

## Directory Structure

```
~/DeepThink/knowledge/
├── general/           # Default bucket
├── folders/           # User-created buckets
├── web/               # Scraped web pages
├── clipboard/         # Clipboard captures
├── manual/            # User-created entries
├── scripts/           # Script output
├── imports/           # File imports (Obsidian, etc.)
├── integrations/      # MCP/external data
├── projects/          # Per-project knowledge
├── research/          # Research captures
├── archive/           # Old/compressed entries
└── index.json         # Knowledge index
```

## Deduplication

Three-layer system prevents redundant entries:

1. **Hash fingerprint** — exact content match, O(1) lookup
2. **Jaccard similarity** — near-duplicate detection (>75% term overlap)
3. **Incremental sync** — folder watcher only copies new/modified files

## Search

### Keyword Search
Basic substring matching across title, content, and tags. Used for the search bar in Knowledge Browser.

### Smart Retrieval (RAG)
BM25 + semantic hybrid search via `ContextEngine.retrieveContextHybrid()`. Used for AI chat context injection. See [RAG Pipeline](../rag-pipeline.md).

## Bucket Management

- Create custom buckets in Knowledge UI
- Move entries between buckets
- Filter by bucket in browser view
- Scope agents/skills to specific buckets via `knowledge_scope`

## Auto-Extraction

### From Conversations
Every 6 chat messages, `KnowledgeExtractionService` asks Claude to extract key facts, decisions, and insights. Creates new knowledge entries automatically.

### From Notes
Notes with >30 words auto-analyzed for extractable knowledge facts. Tags auto-generated via Claude.

## Key Files

| File | Role |
|------|------|
| `Models/KnowledgeEntry.swift` | Entry data structure (title, content, tags, source, bucket) |
| `Services/KnowledgeService.swift` | CRUD, search, RAG context, bucket management |
| `Services/DataCollectorService.swift` | URL scraping, RSS, clipboard, folders, scripts |
| `Services/ObsidianImportService.swift` | Obsidian vault import |
| `Services/KnowledgeExtractionService.swift` | Auto-extraction from conversations/notes |
| `Services/ContextEngine.swift` | BM25 index, hybrid search, chunking, dedup |
| `Services/EmbeddingService.swift` | Semantic embeddings |
| `Views/Knowledge/KnowledgeBrowserView.swift` | Browse, search, manage entries |
| `Views/Knowledge/KnowledgeTimelineView.swift` | Timeline view |
