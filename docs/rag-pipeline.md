# RAG Pipeline

DeepThink's Retrieval-Augmented Generation pipeline finds relevant knowledge for every AI interaction automatically. Both the Swift app and CLI implement the same algorithm against the same shared databases.

## End-to-End Flow

```text
User query
    │
    ▼
┌─────────────────────────────────┐
│  1. Tokenize + Stem             │
│  lowercase · stopwords · stem   │
└───────────────┬─────────────────┘
                │
        ┌───────┴────────┐
        ▼                ▼
┌──────────────┐  ┌──────────────────┐
│  2. BM25     │  │  3. Semantic     │
│  keyword     │  │  NLEmbedding     │
│  scoring     │  │  cosine sim      │
└──────┬───────┘  └────────┬─────────┘
        └───────┬────────┘
                ▼
┌─────────────────────────────────┐
│  4. RRF Fusion                  │
│  rank merge · K=60              │
└───────────────┬─────────────────┘
                ▼
┌─────────────────────────────────┐
│  5. chunksForEntryIds()         │
│  load only needed chunks        │
└───────────────┬─────────────────┘
                ▼
┌─────────────────────────────────┐
│  6. Window Extraction           │
│  highest query-term density     │
└───────────────┬─────────────────┘
                ▼
┌─────────────────────────────────┐
│  7. Context Assembly            │
│  token-budgeted prompt inject   │
└─────────────────────────────────┘
```

---

## Step 1 - Tokenize + Stem

Applied to both the query and all indexed content at build time.

- Lowercase entire input
- Remove 150+ stopwords (synchronized between TypeScript and Swift implementations)
- Filter tokens shorter than 3 characters
- Apply suffix stemmer: strips `-ing`, `-ed`, `-tion`, `-ness`, `-ment`, `-ly`, and common plural endings
- Result: "running authentication systems" → `["run", "authent", "system"]`

---

## Step 2 - BM25 Keyword Scoring

**Parameters:** k1=1.5, b=0.75

**IDF formula:**

```text
IDF(term) = log((N - df + 0.5) / (df + 0.5) + 1)
```

**BM25 score per document:**

```text
score(d, q) = Σ IDF(t) × (TF(t,d) × (k1+1)) / (TF(t,d) + k1×(1 - b + b×(|d|/avgdl)))
```

**Boosting applied after base score:**

| Boost | Factor | Condition |
|-------|--------|-----------|
| Title match | ×1.5 | Query terms found in entry title |
| Tag match | ×1.3 | Query terms found in entry tags |
| Recency decay | e^(-days/90) | Applied as: `score × (0.7 + 0.3 × decay)` - min 0.7× |
| Project scope | ×1.5 | Entry belongs to the scoped project |

**Threshold:** Scores ≤0.1 are discarded before fusion.

**Archive exclusion:** Entries with `source == 'archive'` are excluded from BM25 retrieval. The index is built only over active entries.

**Index caching:** The BM25 index is built in RAM and rebuilt only when knowledge content changes (version-gated). Not rebuilt per query.

---

## Step 3 - Semantic Search

**Model:** Apple `NLEmbedding.sentenceEmbedding(for: .english)` - on-device, ~512 dimensions, no API key required.

**Input format (standardized):**

```text
"{title}. {content.prefix(500)}"
```

This format is used for both indexing chunks and embedding queries, ensuring the vector space is consistent.

**Cosine similarity:**

```text
similarity(a, b) = dot(a, b) / (|a| × |b|)
```

**Threshold:** similarity ≤0.3 discarded.

**Top-k:** 20 results returned before fusion.

**NaN/Infinite guard:** All embedding vectors are validated before storage. Any vector containing NaN or Infinite values is rejected and not written to `vectors.db`.

**Archive exclusion:** Same as BM25 - `source == 'archive'` entries excluded from semantic retrieval.

---

## Step 4 - RRF Fusion

Reciprocal Rank Fusion merges BM25 and semantic result lists without requiring score normalization.

**Formula:**

```text
fused_score(entry) = 1/(K + bm25_rank + 1) + (semrank exists ? 1/(K + semrank + 1) : 0)
where K = 60
```

Key properties:
- An entry found by only one method contributes its term to the sum (no penalty for missing from the other list)
- An entry found by both methods scores higher than either alone
- K=60 dampens rank differences at the top of each list
- Results keyed by `entry_id` (not title) to prevent false merges when entries share titles

Falls back to BM25-only if no embeddings are available in `vectors.db`.

---

## Step 5 - chunksForEntryIds() Optimization

After RRF produces a ranked list of `entry_id` values, the system loads only the chunks for those specific entries:

```sql
SELECT * FROM chunks WHERE entry_id IN (?, ?, ...)
```

This avoids a full table scan of `vectors.db`. The chunk content, title, tags, and source are loaded only for entries that passed the ranking threshold.

---

## Step 6 - Window Extraction

For multi-chunk entries, a sliding window selects the region of highest query-term density rather than naively truncating from the front. This ensures the most relevant portion of a long entry is surfaced even if it appears mid-document.

---

## Step 7 - Context Assembly

Token-budgeted injection into the Claude system prompt:

| Component | Token Budget | Content |
|-----------|-------------|---------|
| Knowledge RAG | ~4,000 tokens | Top ranked chunks from hybrid search |
| Workspace context | ~600 tokens | Query-relevant tasks, notes, reminders |
| Conversation history | ~400 tokens | Rolling summary for long conversations |
| System prompt | Varies | Agent instructions + active rules |
| **Total** | **~5–7K tokens** | |

---

## unified_search - All Four Types

`unified_search` runs hybrid retrieval across all entity types simultaneously: `knowledge`, `task`, `note`, `reminder`. Key behaviors:

- The `content` field is fully populated for workspace items (tasks, notes, reminders) - not empty or truncated
- Semantic search runs once and is shared across knowledge and workspace retrieval to avoid duplicate embedding lookups
- Results carry a `type` label so callers know what kind of item each result is
- Archive entries excluded by default; pass explicit source filter to include them

---

## workspace_context vs knowledge_context vs unified_search

| Tool / Function | What it searches | When to use |
|-----------------|-----------------|-------------|
| `workspace_context` | Tasks, notes, reminders only | "What's blocking X?", "Tasks related to auth" |
| `knowledge_context` | Knowledge FS entries only | "Find everything about JWT", "Design decisions for project Y" |
| `unified_search` | All four types simultaneously | Unknown where info lives, broad context gathering |
| `smart_query` | Auto-selects mode, token-budgets output | Default first call for any open-ended question |

---

## Key Files

### Swift App

| File | Role |
|------|------|
| `Services/ContextEngine.swift` | BM25 index build, `retrieveContextHybrid()`, RRF fusion, token budgeting |
| `Services/EmbeddingService.swift` | NLEmbedding, SemanticChunker, incremental indexing, NaN guard |
| `Services/VectorStore.swift` | SQLite CRUD, `chunksForEntryIds()`, Float32 BLOB |
| `Services/KnowledgeService.swift` | Knowledge FS reload (incremental via `lastScanAt`), YAML frontmatter parsing, context formatting |

### CLI

| File | Role |
|------|------|
| `cli/src/core/context-engine.ts` | BM25 index, `retrieveContextHybrid()`, archive exclusion, workspace context |
| `cli/src/core/embedding-service.ts` | Query embedding via embed-helper, cosine similarity, indexing |
| `cli/src/core/vector-store.ts` | SQLite layer, `chunksForEntryIds()`, shared schema, `pending_reindex` queue |
| `cli/src/tools/smart-mcp.ts` | MCP tools: `smart_query`, `knowledge_context`, `workspace_context`, `unified_search` |
