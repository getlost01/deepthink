# Semantic Search

Meaning-based search using Apple's NaturalLanguage framework. Complements BM25 keyword search — together they form the hybrid retrieval system.

## Why Semantic Search

BM25 only matches keywords. If your knowledge says "OAuth token rotation prevents session hijacking" and you search "authentication security", BM25 finds nothing — no shared words.

Semantic search converts both the query and every knowledge entry into ~512-dimensional vectors. Entries with similar meaning score high even without keyword overlap.

## How It Works

### Embedding Generation

```
Knowledge Entry: "OAuth token rotation prevents session hijacking"
        ↓
SemanticChunker splits into sentence-boundary chunks (max 500 chars)
        ↓
For each chunk: embed("{title}. {first 500 chars of chunk}")
        ↓
NLEmbedding.sentenceEmbedding(for: .english)
        ↓
Float32 array (~512 dims) stored as BLOB in vectors.db
```

### Cosine Similarity Search

```
Query: "authentication security"
        ↓
embed(query) → query vector
        ↓
For each chunk with embedding in vectors.db:
    similarity = dot(query, chunk) / (|query| × |chunk|)
        ↓
Filter: similarity > 0.3 (minimum threshold)
Dedup: one result per entry_id
Sort by score, return top K
```

### Hybrid Fusion

Semantic results are merged with BM25 results using Reciprocal Rank Fusion:

```
fused_score = 1/(60 + bm25_rank) + 1/(60 + semantic_rank)
```

An entry found by only one method still surfaces. An entry found by both ranks higher.

## What Gets Indexed

VectorStore indexes all content types, not just knowledge entries:

| Entry Type | Source | `entry_type` value |
|------------|--------|-------------------|
| Knowledge base entries | `~/DeepThink/knowledge/**/*.md` | `knowledge` |
| Notes | SwiftData | `note` |
| Tasks | SwiftData | `task` |
| Reminders | SwiftData | `reminder` |

## Incremental Indexing

Embeddings are expensive to compute. A `content_hash` (djb2) stored per chunk in `vectors.db` skips unchanged entries:

1. On `KnowledgeService.reload()`, all entries passed to `EmbeddingService.indexEntries()`
2. For each entry, compute content hash
3. If hash matches stored hash → skip (already embedded)
4. If new or changed → re-chunk and re-embed
5. Stale entries (deleted from knowledge base) → pruned from `vectors.db`

## Storage

Everything stored in a single SQLite database:

| File | Content |
|------|---------|
| `~/DeepThink/data/vectors.db` | All chunks + embeddings (Float32 BLOB), content hashes, entry metadata |

Replaces the old `embeddings.json` + `embedding_hashes.json` files. Uses WAL journal mode for concurrent read/write access by both app and CLI.

## CLI Support

Semantic search is available in the CLI via `cli/src/core/embedding-service.ts`:

- **Shared DB**: reads and writes to the same `~/DeepThink/data/vectors.db` as the Swift app
- **Query embedding**: compiled Swift helper at `~/DeepThink/.cache/embed-helper` using the same `NLEmbedding` model
- **Indexing**: CLI can index entries independently via `indexEntry()` — does not require the app to run first
- **Hybrid retrieval**: `context-engine.ts` merges BM25 + semantic via RRF, same algorithm as Swift app
- **CLI commands**:
  - `deepthink context query <q>` — hybrid retrieval (default)
  - `deepthink context query <q> --bm25` — keyword-only fallback
  - `deepthink context semantic <q>` — pure semantic search
- **MCP tools**: `smart_query` and `knowledge_context` use hybrid retrieval

The Swift helper is auto-compiled on first use and cached at `~/DeepThink/.cache/embed-helper`. Requires macOS with Xcode Command Line Tools (`swiftc`).

## Limitations

- **English only**: `NLEmbedding.sentenceEmbedding(for: .english)` — other languages may return nil
- **Quality**: Apple's built-in model is general-purpose, not tuned for domain-specific content
- **Input truncation**: Only first 500 chars of each chunk embedded (quality degrades with length)
- **macOS only**: CLI semantic search requires Apple's NaturalLanguage framework via `swiftc`
- **Future upgrade path**: swap `NLEmbedding` for a local MLX model (e.g., all-MiniLM-L6-v2) for better quality and cross-platform support

## Key Files

| File | Role |
|------|------|
| `Services/VectorStore.swift` | SQLite CRUD for chunks + embeddings, `VectorChunk` model |
| `Services/EmbeddingService.swift` | Embedding generation, `SemanticChunker`, cosine similarity, incremental indexing |
| `Services/ContextEngine.swift` | `retrieveContextHybrid()` — merges BM25 + semantic via RRF |
| `Services/KnowledgeService.swift` | Triggers embedding indexing on `reload()` |
| `cli/src/core/vector-store.ts` | CLI SQLite layer, `semanticChunk`, shared schema |
| `cli/src/core/embedding-service.ts` | CLI: query embedding via Swift helper, indexing, cosine similarity |
| `cli/src/core/context-engine.ts` | CLI: `retrieveContextHybrid()` — BM25 + semantic RRF fusion |
