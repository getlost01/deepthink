# RAG Pipeline

DeepThink's Retrieval-Augmented Generation pipeline automatically finds relevant knowledge for every AI interaction. No manual context-pasting — ask a question, get an answer grounded in your actual knowledge base.

## How It Works

Every chat message flows through this pipeline:

```
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

### BM25/TF-IDF Index (`ContextEngine`)

- **Tokenization**: lowercase, remove 150+ stop words, filter tokens >2 chars
- **Term Frequency (TF)**: normalized frequency per document
- **Inverse Document Frequency (IDF)**: `log((N - df + 0.5) / (df + 0.5) + 1)`
- **BM25 Scoring**: `IDF × TF_norm` with `k1=1.5, b=0.75` length normalization
- **Chunking**: entries >600 chars split at sentence boundaries with 100-char overlap
- **Dedup**: hash fingerprints + Jaccard similarity (>75% threshold)
- **Storage**: RAM only — rebuilds in milliseconds from knowledge files

### Semantic Embeddings (`EmbeddingService`)

- **Model**: Apple NaturalLanguage `NLEmbedding.sentenceEmbedding(for: .english)` — 512 dimensions
- **Input**: Combined `title + first 500 chars of content` per entry
- **Incremental**: content hash tracks changes — only re-embeds modified entries
- **Storage**: `~/DeepThink/data/embeddings.json` (persisted across launches)
- **Change detection**: `~/DeepThink/data/embedding_hashes.json`

## Retrieval

### Hybrid Search (`retrieveContextHybrid`)

For each query, both search methods run in parallel:

| Method | What It Finds | Example |
|--------|---------------|---------|
| BM25 | Entries with matching keywords | "authentication" finds entries containing "authentication" |
| Semantic | Entries with similar meaning | "authentication" finds entries about "login security", "OAuth tokens" |

Results are merged via **Reciprocal Rank Fusion (RRF)**:

```
score(entry) = 1/(k + bm25_rank) + 1/(k + semantic_rank)
where k = 60
```

This ensures both keyword-exact and meaning-similar entries surface. An entry ranked #1 by BM25 and #5 by semantic search gets a higher fused score than one ranked #3 by both.

### Scope Filtering

Context can be narrowed at retrieval time:

| Scope | Set By | Effect |
|-------|--------|--------|
| `agentScope` | Agent's `knowledge_scope` field | Only entries matching specified folders/tags |
| `projectScope` | Current project context | Entries tagged with project name boosted 1.5x |
| `skillScope` | Skill's `knowledge_scope` field | Skill-specific RAG filtering |

### Boosting

On top of BM25 scores:

- **Title match**: query terms in title → 1.5x boost
- **Tag match**: query terms in tags → 1.3x boost
- **Recency**: exponential decay over 90 days (`exp(-days/90) * 0.3 + 0.7`)
- **Project scope**: matching project → 1.5x boost

## Context Assembly

The full prompt sent to Claude combines:

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

```
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

| Data | Location | Format |
|------|----------|--------|
| BM25 index | RAM | Rebuilt on each `reload()` |
| Semantic embeddings | `data/embeddings.json` | JSON array of `{id, vector}` |
| Content hashes | `data/embedding_hashes.json` | JSON `{entryID: hash}` |
| Knowledge entries | `knowledge/**/*.md` | Markdown + YAML frontmatter |
| Conversation summaries | RAM | Cache, regenerated as needed |
| Dedup fingerprints | RAM | `Set<UInt64>`, rebuilt with index |

## Key Files

### Swift App
| File | Role |
|------|------|
| `Services/ContextEngine.swift` | BM25 index, hybrid retrieval, chunking, dedup, token budgeting |
| `Services/EmbeddingService.swift` | NLEmbedding vectors, cosine similarity, disk persistence |
| `Services/KnowledgeService.swift` | Knowledge CRUD, RAG context formatting, reload triggers |
| `Views/Shared/AIChatView.swift` | Context assembly, prompt building, sends to Claude |

### CLI
| File | Role |
|------|------|
| `cli/src/core/context-engine.ts` | BM25 index, hybrid retrieval (RRF), chunking, token budgeting |
| `cli/src/core/embedding-service.ts` | Reads shared embeddings, query embedding via Swift helper, cosine similarity |
| `cli/src/tools/smart-mcp.ts` | MCP tools (`smart_query`, `knowledge_context`) using hybrid retrieval |
