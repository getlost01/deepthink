# Semantic Search

Meaning-based search using Apple's NaturalLanguage framework. Complements BM25 keyword search - together they form the hybrid retrieval system used by both the Swift app and CLI.

## Why Semantic Search

BM25 only matches keywords. If your knowledge says "OAuth token rotation prevents session hijacking" and you search "authentication security", BM25 finds nothing - no shared words.

Semantic search converts both the query and every chunk into ~512-dimensional vectors. Entries with similar meaning score high even without keyword overlap.

---

## Shared vectors.db

Both the Swift app (`VectorStore.swift`) and the CLI (`vector-store.ts`) read from and write to the same database:

```text
~/DeepThink/data/vectors.db
```

WAL mode is enabled so both processes can access the file concurrently without blocking each other. There is no replication or sync step - writes from either side are immediately visible to the other.

---

## Embedding Model

**Apple `NLEmbedding.sentenceEmbedding(for: .english)`**

- On-device inference - no API key, no network call
- ~512-dimensional Float32 output
- English language only; other languages may return nil
- Available on macOS 12+ via the NaturalLanguage framework

The CLI accesses this model via a compiled Swift helper binary (`embed-helper`) rather than calling NLEmbedding directly from TypeScript. The helper is auto-compiled on first use:

```text
~/DeepThink/.cache/embed-helper
```

Requires macOS with Xcode Command Line Tools (`swiftc`). The app and CLI use the identical model - there is no version skew in embedding space.

---

## Chunking Algorithm

Long entries are split before embedding. Both Swift (`SemanticChunker` in `EmbeddingService.swift`) and TypeScript (`semanticChunk` in `vector-store.ts`) implement the same logic:

- **Split boundary:** sentence boundaries (Swift uses `enumerateSubstrings(.bySentences, .localized)`; TypeScript uses a sentence regex)
- **Minimum chunk size:** 100 characters - sentences below this are merged with the next
- **Maximum chunk size:** 500 characters - sentences that would exceed this start a new chunk
- **Overlap:** the last sentence of the previous chunk is prepended to the next chunk, preserving context across boundaries
- **Result:** each chunk is self-contained enough to be meaningful in isolation, with a small bridge to adjacent content

---

## Embedding Format

The input string sent to NLEmbedding for every chunk and every query is standardized:

```text
"{title}. {content.prefix(500)}"
```

This format applies to all item types - knowledge entries, tasks, notes, and reminders. Using the same format for indexing and querying keeps the embedding space consistent.

---

## NaN / Infinite Validation

Before any embedding vector is written to `vectors.db`, every element is checked:

```swift
// Swift
guard embedding.allSatisfy({ $0.isFinite }) else { return }
```

```typescript
// TypeScript (embedding-service.ts)
if (embedding.some(v => !isFinite(v))) { continue; }
```

Vectors containing NaN or Infinite values are silently discarded. This prevents corrupt blobs from poisoning cosine similarity results.

---

## Cosine Similarity Scoring

```text
Query: "authentication security"
    │
    ▼
embed("{title}. {query text}") → query vector (Float32[~512])
    │
    ▼
For each chunk with embedding in vectors.db:
    similarity = dot(query_vec, chunk_vec) / (|query_vec| × |chunk_vec|)
    │
    ▼
Filter: similarity ≤ 0.3 → discarded
Dedup: one result per entry_id (highest chunk score wins)
Sort descending, return top-k=20
```

The 0.3 threshold filters out weakly related entries that would add noise to the context window.

---

## Content Hash Deduplication

Each chunk row in `vectors.db` stores a `content_hash` (djb2 integer). On re-index:

1. Compute hash of current chunk content
2. Compare against stored `content_hash`
3. If match → skip (embedding already current)
4. If new or changed → re-chunk and re-embed
5. Entries deleted from the knowledge FS or workspace → pruned from `vectors.db`

This makes incremental indexing cheap - only changed content triggers NLEmbedding calls.

---

## Durable Retry Queue (pending_reindex)

Embeddings that fail (NLEmbedding returns nil, NaN guard fires, or the process is interrupted) are written to a `pending_reindex` SQLite table in `vectors.db`. A background reconciler retries them on the next cycle.

**Key behaviors:**

- Re-enqueuing an already-queued entry (`ON CONFLICT DO UPDATE`) updates the operation and timestamp but **preserves `retry_count`** - rapid content edits do not reset the cap.
- `retry_count` is incremented on failure; entries with `retry_count >= 3` are pruned by `deleteExhaustedPendingReindex()` at the end of each drain, preventing infinite retry loops.
- Both the Swift `EmbeddingService` and TypeScript `embedding-service.ts` implement the same queue/drain logic so the behavior is consistent regardless of which side does the indexing.

---

## Incremental Knowledge Scanning

`KnowledgeService.reload()` tracks `lastScanAt`. On subsequent reloads it only rescans files with `contentModificationDate > lastScanAt - 1s`, then diffs the full path list to detect deletions. The first reload (or after app restart) always does a full scan.

Detected changes are passed to `EmbeddingService.scheduleIndexEntries()` which dispatches embedding on a dedicated utility-QoS queue, keeping the main thread free.

---

## Thread Safety in VectorStore

All read and write operations in `VectorStore.swift` are serialized through a concurrent `DispatchQueue` with barrier writes:

- Reads: `queue.sync { … }` - concurrent, multiple readers allowed
- Writes: `queue.async(flags: .barrier) { … }` or `queue.sync(flags: .barrier) { … }` - exclusive

Prior to this, read methods (`contentHash`, `allChunks`, `chunksWithEmbeddings`, `chunkCount`, `entryCount`, `embeddedCount`, `getMeta`, `allEntryIDs`) were called without queue protection, risking SQLite "database is locked" errors under concurrent embedding and search workloads.

---

## Chunk Cascade Delete

When any entity is deleted - task, note, project, reminder, or knowledge entry - all associated chunks in `vectors.db` are removed:

```sql
DELETE FROM chunks WHERE entry_id = ?
```

For project deletes, all chunks belonging to entries in that project are cascade-deleted. This keeps `vectors.db` in sync with the source of truth without requiring periodic cleanup jobs.

---

## What Gets Indexed

| Entry Type | entry_type value | Indexed by |
|------------|-----------------|-----------|
| Knowledge FS entries | `knowledge` | Swift `EmbeddingService`, CLI `embedding-service.ts` |
| Tasks | `task` | Swift `EmbeddingService.indexWorkspaceItems()`, CLI |
| Notes | `note` | Swift `EmbeddingService.indexWorkspaceItems()`, CLI |
| Reminders | `reminder` | Swift `EmbeddingService.indexWorkspaceItems()`, CLI |

Archive entries (`source == 'archive'`) are stored in `vectors.db` but excluded from retrieval queries by default via `WHERE source != 'archive'`.

---

## CLI Commands

```bash
deepthink context semantic "authentication"     # pure semantic search
deepthink context query "auth flow"             # hybrid BM25 + semantic (default)
deepthink context query "auth flow" --bm25      # keyword-only, skip semantic
```

---

## Limitations

- **English only** - `NLEmbedding.sentenceEmbedding(for: .english)`. Non-English content may produce nil or degraded embeddings.
- **500-char input cap** - only the first 500 chars of each chunk are embedded; very long chunks lose tail content in the vector representation.
- **General-purpose model** - Apple's built-in model is not tuned for software or personal knowledge domains.
- **macOS only** - the `embed-helper` binary requires `swiftc` and the NaturalLanguage framework. Not available on Linux or Windows.

---

## Key Files

| File | Role |
|------|------|
| `Services/VectorStore.swift` | SQLite CRUD for `vectors.db`, Float32 BLOB read/write, parameterized queries |
| `Services/EmbeddingService.swift` | NLEmbedding calls, SemanticChunker, incremental indexing, NaN guard, workspace item indexing |
| `Services/ContextEngine.swift` | `retrieveContextHybrid()` - merges BM25 + semantic via RRF |
| `Services/KnowledgeService.swift` | Incremental scan via `lastScanAt`; triggers `EmbeddingService.scheduleIndexEntries()` for changed files only |
| `cli/src/core/vector-store.ts` | CLI SQLite layer, `semanticChunk`, shared schema, `chunksForEntryIds()` |
| `cli/src/core/embedding-service.ts` | Query embedding via embed-helper, cosine similarity, indexing, NaN guard |
| `cli/src/core/context-engine.ts` | CLI `retrieveContextHybrid()` - BM25 + semantic RRF fusion |
