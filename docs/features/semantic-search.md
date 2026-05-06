# Semantic Search

Meaning-based search using Apple's NaturalLanguage framework. Complements BM25 keyword search — together they form the hybrid retrieval system.

## Why Semantic Search

BM25 only matches keywords. If your knowledge says "OAuth token rotation prevents session hijacking" and you search "authentication security", BM25 finds nothing — no shared words.

Semantic search converts both the query and every knowledge entry into 512-dimensional vectors. Entries with similar meaning score high even without keyword overlap.

## How It Works

### Embedding Generation

```
Knowledge Entry: "OAuth token rotation prevents session hijacking"
        ↓
NLEmbedding.sentenceEmbedding(for: .english)
        ↓
[0.23, -0.14, 0.67, 0.02, ...] (512 dimensions)
```

Each entry is embedded as: `"{title}. {first 500 chars of content}"`

### Cosine Similarity Search

```
Query: "authentication security"
        ↓
embed(query) → query vector
        ↓
For each entry:
    similarity = dot(query, entry) / (|query| × |entry|)
        ↓
Filter: similarity > 0.3 (minimum threshold)
Sort by score, return top K
```

### Hybrid Fusion

Semantic results are merged with BM25 results using Reciprocal Rank Fusion:

```
fused_score = 1/(60 + bm25_rank) + 1/(60 + semantic_rank)
```

An entry found by only one method still surfaces. An entry found by both ranks higher.

## Incremental Indexing

Embeddings are expensive to compute. The service tracks content hashes to skip unchanged entries:

1. On `KnowledgeService.reload()`, all entries passed to `EmbeddingService.indexEntries()`
2. For each entry, compute content hash
3. If hash matches stored hash → skip (already embedded)
4. If new or changed → embed and store
5. Stale entries (deleted from knowledge base) → pruned

## Persistence

| File | Content |
|------|---------|
| `~/DeepThink/data/embeddings.json` | All vectors as JSON `[{id, v: "0.23,-0.14,..."}]` |
| `~/DeepThink/data/embedding_hashes.json` | Content hashes `{entryID: "hash"}` |

On app launch, embeddings load from disk. Only new/changed entries get re-embedded.

## CLI Support

Semantic search is available in the CLI via `cli/src/core/embedding-service.ts`:

- **Reads shared embeddings** from `~/DeepThink/data/embeddings.json` (indexed by Swift app)
- **Query embedding** via a compiled Swift helper binary (`~/.cache/embed-helper`) using the same NLEmbedding model
- **Hybrid retrieval** in `context-engine.ts` merges BM25 + semantic via RRF, same as Swift app
- **CLI commands**:
  - `deepthink context query <q>` — hybrid retrieval (default)
  - `deepthink context query <q> --bm25` — keyword-only fallback
  - `deepthink context semantic <q>` — pure semantic search
- **MCP tools**: `smart_query` and `knowledge_context` use hybrid retrieval

The Swift helper is auto-compiled on first use and cached. Requires macOS with Xcode Command Line Tools.

## Limitations

- **English only**: `NLEmbedding.sentenceEmbedding(for: .english)` — other languages may return nil
- **Quality**: Apple's built-in model is general-purpose, not tuned for domain-specific content
- **Input truncation**: Only first 500 chars of content embedded (sentence embedding quality degrades with length)
- **macOS only**: CLI semantic search requires Apple's NaturalLanguage framework via Swift
- **Indexing**: CLI reads embeddings but does not index — the Swift app must run first to generate embeddings
- **Future upgrade path**: swap `NLEmbedding` for a local MLX model (e.g., all-MiniLM-L6-v2) for better quality and cross-platform support

## Key Files

| File | Role |
|------|------|
| `Services/EmbeddingService.swift` | Embedding generation, cosine similarity, persistence |
| `Services/ContextEngine.swift` | `retrieveContextHybrid()` — merges BM25 + semantic via RRF |
| `Services/KnowledgeService.swift` | Triggers embedding indexing on `reload()` |
| `cli/src/core/embedding-service.ts` | CLI: reads shared embeddings, query embedding via Swift helper |
| `cli/src/core/context-engine.ts` | CLI: `retrieveContextHybrid()` — BM25 + semantic RRF fusion |
