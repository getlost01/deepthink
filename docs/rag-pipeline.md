# RAG Pipeline

DeepThink's Retrieval-Augmented Generation pipeline automatically finds relevant knowledge for every AI interaction. No manual context-pasting — ask a question, get an answer grounded in your actual knowledge base.

## How It Works

Every chat message flows through this pipeline:

```text
User types question
        ↓
   ┌────────────────────────────┐
   │  1. DUAL INDEXING          │
   │  BM25 (keywords) +        │
   │  NLEmbedding (meaning)    │
   └────────────┬───────────────┘
                ↓
   ┌────────────────────────────┐
   │  2. HYBRID RETRIEVAL       │
   │  Reciprocal Rank Fusion    │
   │  (best of both searches)  │
   └────────────┬───────────────┘
                ↓
   ┌────────────────────────────┐
   │  3. CONTEXT ASSEMBLY       │
   │  Knowledge + Workspace +   │
   │  Conversation history      │
   └────────────┬───────────────┘
                ↓
   ┌────────────────────────────┐
   │  4. PROMPT INJECTION       │
   │  Agent instructions +      │
   │  Rules + Scoped knowledge  │
   └────────────┬───────────────┘
                ↓
   Claude responds with grounded answer
```

## Indexing

Indexing happens automatically on app launch and whenever knowledge changes.

### Storage Layer (`VectorStore`)

All chunks and embeddings are stored in a shared SQLite database:

```text
~/DeepThink/data/vectors.db
```

Schema (`chunks` table):

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | `{entry_id}:{chunk_index}` |
| `entry_id` | TEXT | Source entry identifier |
| `entry_type` | TEXT | `knowledge`, `task`, `note`, `reminder` |
| `title` | TEXT | Entry title |
| `content` | TEXT | Chunk text content |
| `tags` | TEXT | JSON array of tags |
| `source` | TEXT | Source bucket/type |
| `imported_at` | REAL | Unix timestamp |
| `chunk_index` | INTEGER | Chunk position in entry |
| `total_chunks` | INTEGER | Total chunks for entry |
| `content_hash` | INTEGER | djb2 hash for change detection |
| `embedding` | BLOB | Float32 array (NLEmbedding, ~512 dims) |

Both the Swift app and CLI share the same `vectors.db` file. Indexed entry types:
- Knowledge base entries
- Notes (from SwiftData)
- Tasks (from SwiftData)
- Reminders (from SwiftData)

### Chunking (`SemanticChunker`)

Long entries split into sentence-boundary chunks:

- **Max chunk size**: 500 chars
- **Min chunk size**: 100 chars
- **Overlap**: last sentence of previous chunk kept as first sentence of next
- **Split method**: Apple `enumerateSubstrings(.bySentences, .localized)` in Swift; sentence regex in CLI

### BM25/TF-IDF Index (`ContextEngine`)

Cached in RAM; rebuilt only when knowledge content changes (version-gated, not per-query):

- **Tokenization**: lowercase, remove 150+ stop words, filter tokens >2 chars, apply suffix stemmer (`-ing`, `-ed`, `-tion`, `-ness`, `-ment`, `-ly`, plurals) — "running" and "runs" both match "run"
- **Term Frequency (TF)**: normalized frequency per document
- **Inverse Document Frequency (IDF)**: `log((N - df + 0.5) / (df + 0.5) + 1)`
- **BM25 Scoring**: `IDF × TF_norm` with `k1=1.5, b=0.75` length normalization
- Scores only `knowledge` chunks — workspace chunks excluded from BM25 (scored separately via workspace context)
- **Relevance window**: sliding window selects the highest query-term density region of each chunk (not naive front-truncation)

### Semantic Embeddings (`EmbeddingService`)

- **Model**: Apple NaturalLanguage `NLEmbedding.sentenceEmbedding(for: .english)` — ~512 dimensions
- **Input per chunk**: `"{title}. {first 500 chars of chunk content}"`
- **Change detection**: `content_hash` stored per chunk in `vectors.db` — skips unchanged entries
- **Storage**: Float32 BLOB in `vectors.db` (replaces old `embeddings.json`)
- **Stale pruning**: removed entries deleted from `vectors.db` on index rebuild

## Retrieval

### Hybrid Search (`retrieveContextHybrid`)

For each query, both search methods run:

| Method | What It Finds | Example |
|--------|---------------|---------|
| BM25 | Entries with matching keywords | "authentication" finds entries containing "authentication" |
| Semantic | Entries with similar meaning | "authentication" finds entries about "login security", "OAuth tokens" |

Results merged via **Reciprocal Rank Fusion (RRF)**:

```text
fused_score(entry) = 1/(k + bm25_rank) + 1/(k + semantic_rank)
where k = 60
```

Falls back to BM25-only if no embeddings are available.

### Scope Filtering

Context narrowed at retrieval time:

| Scope | Set By | Effect |
|-------|--------|--------|
| `agentScope` | Agent's `knowledge_scope` field | Only chunks matching specified buckets/tags |
| `projectScope` | Current project context | Entries tagged with project name boosted 1.5x |
| `skillScope` | Skill's `knowledge_scope` field | Skill-specific RAG filtering |

### Boosting (applied to BM25 scores)

- **Title match**: query terms in title → 1.5x per overlapping term
- **Tag match**: query terms in tags → 1.3x per overlapping term
- **Recency**: `exp(-days/90) * 0.3 + 0.7` (90-day exponential decay, min 0.7x)
- **Project scope**: matching project → 1.5x

### Chunk Dedup

Per-query dedup prevents the same entry from flooding results:

- First chunk from each entry always included if score > threshold
- Additional chunks from same entry only included if score > 70% of top score

## Context Assembly

The full prompt sent to Claude:

| Component | Token Budget | Content |
|-----------|-------------|---------|
| Knowledge RAG | ~4,000 tokens | Top ranked chunks from hybrid search |
| Workspace context | ~600 tokens | Query-relevant notes + active tasks |
| Conversation history | ~400 tokens | Rolling summary for long convos |
| System prompt | Varies | Agent instructions + active rules |
| **Total per query** | **~5-7K tokens** | Down from ~10K unbounded |

### Conversation History Compaction

| Messages | Strategy |
|----------|----------|
| 1-4 | Full history sent |
| 5-8 | Older messages compacted (truncated), recent 4 full |
| 8+ | Claude-generated summary (~300 tokens) + last 4 full |

Summary regenerates every 6 messages, incorporating previous summary.

## Auto-Learning Loop

Every 6 chat messages, DeepThink auto-extracts knowledge back into the knowledge base:

```text
Chat conversation
    ↓ (every 6 messages)
KnowledgeExtractionService.extractFromConversation()
    ↓
New knowledge entry created in knowledge base
    ↓
ContextEngine.rebuildIndex() + EmbeddingService.indexEntries()
    ↓
Future conversations can find this knowledge via RAG
```

Manual extraction also available via "Save to Knowledge" button in chat toolbar.

## Data Storage

| Data | Location | Persistence |
|------|----------|-------------|
| BM25 index (TF-IDF terms) | RAM | Cached; rebuilt only when `_indexVersion` increments (content write detected) |
| Chunks + embeddings | `data/vectors.db` | SQLite WAL, persisted, incremental updates |
| Content hashes | `data/vectors.db` (`content_hash` column) | Persisted, tracks what's already embedded |
| Knowledge entries | `knowledge/**/*.md` | Markdown + YAML frontmatter |
| Conversation summaries | RAM | Cache, regenerated as needed |
| Dedup fingerprints | RAM | `Set<UInt64>`, rebuilt with index |

## Key Files

### Swift App
| File | Role |
|------|------|
| `Services/VectorStore.swift` | SQLite storage for chunks + embeddings (WAL, Float32 BLOB) |
| `Services/ContextEngine.swift` | BM25 retrieval, hybrid RRF fusion, chunk dedup, token budgeting |
| `Services/EmbeddingService.swift` | NLEmbedding vectors, `SemanticChunker`, incremental indexing |
| `Services/KnowledgeService.swift` | Knowledge CRUD, RAG context formatting, reload triggers |
| `Views/Shared/AIChatView.swift` | Context assembly, prompt building, sends to Claude |

### CLI
| File | Role |
|------|------|
| `cli/src/core/vector-store.ts` | SQLite storage, `semanticChunk`, shared DB with Swift app |
| `cli/src/core/context-engine.ts` | BM25 index, hybrid retrieval (RRF), workspace context |
| `cli/src/core/embedding-service.ts` | Query embedding via Swift helper, cosine similarity, indexing |
| `cli/src/tools/smart-mcp.ts` | MCP tools (`smart_query`, `knowledge_context`) |
