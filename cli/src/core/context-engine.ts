import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";
import { KNOWLEDGE_DIR, KNOWLEDGE_DIRS } from "../config";
import * as db from "./db";
import { type SemanticResult, semanticSearch } from "./embedding-service";
import {
  allChunks,
  chunksForEntryIds,
  contentHash as getContentHash,
  pruneStaleEntries,
  semanticChunk,
  simpleHash,
  upsertChunks,
  type VectorChunk,
} from "./vector-store";

// ── Types ──

export interface IndexedEntry {
  id: string;
  title: string;
  content: string;
  tags: string[];
  source: string;
  importedAt: Date;
}

export interface ContextResult {
  parts: {
    entryId: string;
    title: string;
    content: string;
    tags: string[];
    source: string;
    score: number;
    chunk?: string;
  }[];
  totalTokensEstimate: number;
  entriesScanned: number;
  entriesReturned: number;
}

// ── Stopwords ──

const STOPWORDS = new Set([
  "a",
  "an",
  "the",
  "is",
  "are",
  "was",
  "were",
  "be",
  "been",
  "being",
  "have",
  "has",
  "had",
  "do",
  "does",
  "did",
  "will",
  "would",
  "could",
  "should",
  "may",
  "might",
  "shall",
  "can",
  "need",
  "dare",
  "ought",
  "and",
  "but",
  "or",
  "nor",
  "not",
  "so",
  "yet",
  "both",
  "either",
  "neither",
  "each",
  "every",
  "all",
  "any",
  "few",
  "more",
  "most",
  "other",
  "some",
  "such",
  "no",
  "only",
  "own",
  "same",
  "than",
  "too",
  "very",
  "just",
  "because",
  "as",
  "until",
  "while",
  "of",
  "at",
  "by",
  "for",
  "with",
  "about",
  "against",
  "between",
  "through",
  "during",
  "before",
  "after",
  "above",
  "below",
  "to",
  "from",
  "up",
  "down",
  "in",
  "out",
  "on",
  "off",
  "over",
  "under",
  "again",
  "further",
  "then",
  "once",
  "here",
  "there",
  "when",
  "where",
  "why",
  "how",
  "what",
  "which",
  "who",
  "whom",
  "this",
  "that",
  "these",
  "those",
  "i",
  "me",
  "my",
  "myself",
  "we",
  "our",
  "ours",
  "ourselves",
  "you",
  "your",
  "yours",
  "yourself",
  "yourselves",
  "he",
  "him",
  "his",
  "himself",
  "she",
  "her",
  "hers",
  "herself",
  "it",
  "its",
  "itself",
  "they",
  "them",
  "their",
  "theirs",
  "themselves",
]);

// ── Stemmer ──

function stem(word: string): string {
  if (word.length > 4 && word.endsWith("sses")) return word.slice(0, -2);
  if (word.length > 4 && word.endsWith("ies")) return word.slice(0, -2);
  if (word.length > 3 && word.endsWith("ss")) return word;
  if (word.length > 2 && word.endsWith("s") && !word.endsWith("ss")) return word.slice(0, -1);
  if (word.length > 6 && word.endsWith("ational")) return `${word.slice(0, -7)}ate`;
  if (word.length > 5 && word.endsWith("ation")) return `${word.slice(0, -5)}ate`;
  if (word.length > 4 && word.endsWith("ness")) return word.slice(0, -4);
  if (word.length > 4 && word.endsWith("ment")) return word.slice(0, -4);
  if (word.length > 4 && word.endsWith("ting")) return word.slice(0, -3);
  if (word.length > 3 && word.endsWith("ing")) return word.slice(0, -3);
  if (word.length > 3 && word.endsWith("ely")) return word.slice(0, -3);
  if (word.length > 2 && word.endsWith("ed")) return word.slice(0, -2);
  if (word.length > 2 && word.endsWith("er")) return word.slice(0, -2);
  if (word.length > 2 && word.endsWith("ly")) return word.slice(0, -2);
  return word;
}

// ── Tokenizer ──

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 1 && !STOPWORDS.has(t))
    .map(stem);
}

function computeTF(tokens: string[]): Record<string, number> {
  const tf: Record<string, number> = {};
  for (const t of tokens) tf[t] = (tf[t] ?? 0) + 1;
  const max = Math.max(...Object.values(tf), 1);
  for (const t in tf) tf[t] /= max;
  return tf;
}

// ── Relevance Window Extraction ──

function extractRelevantWindow(content: string, queryTerms: Set<string>, maxLen: number): string {
  if (content.length <= maxLen) return content;

  const words = content.split(/\s+/);
  const windowSize = Math.floor(maxLen / 5);

  if (words.length <= windowSize) return content.slice(0, maxLen);

  const hits = words.map((w) => {
    const t = stem(w.toLowerCase().replace(/[^a-z0-9]/g, ""));
    return queryTerms.has(t) ? 1 : 0;
  });

  let windowScore = hits.slice(0, windowSize).reduce((a: number, b) => a + b, 0);
  let bestStart = 0;
  let bestScore = windowScore;

  for (let i = 1; i <= words.length - windowSize; i++) {
    windowScore += hits[i + windowSize - 1] - hits[i - 1];
    if (windowScore > bestScore) {
      bestScore = windowScore;
      bestStart = i;
    }
  }

  const selected = words.slice(bestStart, bestStart + windowSize).join(" ");
  return selected.length > maxLen ? selected.slice(0, maxLen) : selected;
}

// ── Frontmatter Parser ──

function parseFrontmatter(text: string): { meta: Record<string, string>; body: string } {
  if (!text.startsWith("---")) return { meta: {}, body: text };
  const end = text.indexOf("---", 3);
  if (end === -1) return { meta: {}, body: text };

  const meta: Record<string, string> = {};
  for (const line of text.slice(3, end).trim().split("\n")) {
    const idx = line.indexOf(":");
    if (idx > 0) meta[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
  }
  return { meta, body: text.slice(end + 3).trim() };
}

// ── Load All Knowledge Entries ──

function loadAllEntries(): IndexedEntry[] {
  const entries: IndexedEntry[] = [];
  if (!existsSync(KNOWLEDGE_DIR)) return entries;

  function scanDir(dir: string, source: string) {
    if (!existsSync(dir)) return;
    for (const item of readdirSync(dir, { withFileTypes: true })) {
      if (item.isDirectory()) {
        scanDir(join(dir, item.name), source);
      } else if (item.name.endsWith(".md")) {
        try {
          const raw = readFileSync(join(dir, item.name), "utf-8");
          const { meta, body } = parseFrontmatter(raw);
          const tags = (meta.tags ?? "")
            .replace(/^\[|]$/g, "")
            .split(",")
            .map((t) => t.trim())
            .filter(Boolean);

          const dateStr = meta.importedAt ?? meta.imported_at ?? meta.importedat;
          const parsed = dateStr ? new Date(dateStr) : new Date();
          const importedAt = Number.isNaN(parsed.getTime()) ? new Date() : parsed;

          entries.push({
            id: relative(KNOWLEDGE_DIR, join(dir, item.name)),
            title: meta.title ?? item.name.replace(".md", ""),
            content: body,
            tags,
            source,
            importedAt,
          });
        } catch {}
      }
    }
  }

  scanDir(join(KNOWLEDGE_DIR, "general"), "general");
  scanDir(join(KNOWLEDGE_DIR, "folders"), "folders");
  scanDir(join(KNOWLEDGE_DIR, "clipboard"), "clipboard");
  scanDir(join(KNOWLEDGE_DIR, "web"), "web");
  scanDir(join(KNOWLEDGE_DIR, "manual"), "manual");
  scanDir(join(KNOWLEDGE_DIR, "imports"), "imports");
  scanDir(join(KNOWLEDGE_DIR, "scripts"), "scripts");
  scanDir(KNOWLEDGE_DIRS.projects, "projects");
  scanDir(KNOWLEDGE_DIRS.integrations, "integrations");
  scanDir(KNOWLEDGE_DIRS.archive, "archive");

  return entries;
}

// ── Caches ──

const _hashCache = new Map<string, number>();

// Version bumped whenever ensureIndexed writes new chunks — signals TF-IDF rebuild needed
let _indexVersion = 0;

// Entries cache: 30s TTL (knowledge files change infrequently)
let _entriesCache: { entries: IndexedEntry[]; ts: number } | null = null;

interface TFIDFCache {
  version: number;
  entryCount: number;
  docFreq: Record<string, number>;
  docTerms: Map<string, Record<string, number>>;
}
let _tfidfCache: TFIDFCache | null = null;

function loadAllEntriesCached(): IndexedEntry[] {
  const now = Date.now();
  if (_entriesCache && now - _entriesCache.ts < 30_000) return _entriesCache.entries;
  const entries = loadAllEntries();
  _entriesCache = { entries, ts: now };
  return entries;
}

function getTFIDF(entries: IndexedEntry[]): TFIDFCache {
  if (_tfidfCache && _tfidfCache.version === _indexVersion && _tfidfCache.entryCount === entries.length) {
    return _tfidfCache;
  }

  const docFreq: Record<string, number> = {};
  const docTerms = new Map<string, Record<string, number>>();

  for (const entry of entries) {
    const allText = `${entry.title} ${entry.tags.join(" ")} ${entry.content}`;
    const terms = tokenize(allText);
    const tf = computeTF(terms);
    docTerms.set(entry.id, tf);
    for (const term of Object.keys(tf)) {
      docFreq[term] = (docFreq[term] ?? 0) + 1;
    }
  }

  _tfidfCache = { version: _indexVersion, entryCount: entries.length, docFreq, docTerms };
  return _tfidfCache;
}

// ── Ensure VectorStore is populated ──

function ensureIndexed(entries: IndexedEntry[]): void {
  for (const entry of entries) {
    const hash = simpleHash(entry.content);
    const cached = _hashCache.get(entry.id);
    if (cached === hash) continue;

    const existing = getContentHash(entry.id);
    if (existing !== null && existing === hash) {
      _hashCache.set(entry.id, hash);
      continue;
    }

    const chunks = semanticChunk(
      entry.content,
      entry.id,
      "knowledge",
      entry.title,
      entry.tags,
      entry.source,
      entry.importedAt,
      hash
    );
    upsertChunks(chunks);
    _hashCache.set(entry.id, hash);
    _indexVersion++;
    _tfidfCache = null; // invalidate on write
  }
  const validIds = new Set(entries.map((e) => e.id));
  pruneStaleEntries(validIds, "knowledge");
}

// ── BM25 Retrieval ──

export function retrieveContext(
  query: string,
  opts: { maxTokens?: number; projectScope?: string; agentScope?: string[]; topK?: number } = {}
): ContextResult {
  const maxTokens = opts.maxTokens ?? 4000;
  const topK = opts.topK ?? 10;

  const entries = loadAllEntriesCached();
  if (entries.length === 0) return { parts: [], totalTokensEstimate: 0, entriesScanned: 0, entriesReturned: 0 };

  ensureIndexed(entries);

  const queryTerms = tokenize(query);
  if (queryTerms.length === 0)
    return { parts: [], totalTokensEstimate: 0, entriesScanned: entries.length, entriesReturned: 0 };

  const queryTermSet = new Set(queryTerms);
  const { docFreq, docTerms, entryCount: docCount } = getTFIDF(entries);

  // Only score knowledge chunks — workspace chunks have no docTerms entry and would be skipped anyway
  const chunks = allChunks({ scope: opts.agentScope, entryType: "knowledge", excludeArchive: true });

  const scorableChunks = chunks.filter((c) => docTerms.has(c.entryId));
  const avgDocLen =
    scorableChunks.length > 0
      ? scorableChunks.reduce((s, c) => s + c.content.length, 0) / scorableChunks.length
      : chunks.reduce((s, c) => s + c.content.length, 0) / Math.max(chunks.length, 1);
  const k1 = 1.5;
  const b = 0.75;
  const queryTF = computeTF(queryTerms);

  const scored: { chunk: VectorChunk; score: number }[] = [];

  for (const chunk of chunks) {
    const tf = docTerms.get(chunk.entryId);
    if (!tf) continue;

    let score = 0;
    const docLen = chunk.content.length;

    for (const [term, qFreq] of Object.entries(queryTF)) {
      const df = docFreq[term] ?? 0;
      const idf = Math.log((docCount - df + 0.5) / (df + 0.5) + 1.0);
      const termTF = tf[term] ?? 0;
      const tfNorm = (termTF * (k1 + 1)) / (termTF + k1 * (1 - b + (b * docLen) / avgDocLen));
      score += idf * tfNorm * qFreq;
    }

    const titleTerms = new Set(tokenize(chunk.title));
    const titleOverlap = [...titleTerms].filter((t) => queryTermSet.has(t)).length;
    if (titleOverlap > 0) score *= 1 + titleOverlap * 0.5;

    const tagTerms = new Set(chunk.tags.flatMap((t) => tokenize(t)));
    const tagOverlap = [...tagTerms].filter((t) => queryTermSet.has(t)).length;
    if (tagOverlap > 0) score *= 1 + tagOverlap * 0.3;

    const daysSince = (Date.now() - chunk.importedAt.getTime()) / 86400000;
    score *= Math.exp(-daysSince / 90) * 0.3 + 0.7;

    if (opts.projectScope) {
      const p = opts.projectScope.toLowerCase();
      if (chunk.title.toLowerCase().includes(p) || chunk.tags.some((t) => t.toLowerCase().includes(p))) {
        score *= 1.5;
      }
    }

    if (score > 0.1) scored.push({ chunk, score });
  }

  scored.sort((a, b) => b.score - a.score);

  const usedEntries = new Set<string>();
  const selected: typeof scored = [];

  for (const item of scored) {
    if (selected.length >= topK) break;
    if (usedEntries.has(item.chunk.entryId)) {
      if (scored[0] && item.score > scored[0].score * 0.7) {
        selected.push(item);
      }
      continue;
    }
    selected.push(item);
    usedEntries.add(item.chunk.entryId);
  }

  let charBudget = maxTokens * 4;
  const parts: ContextResult["parts"] = [];

  for (const item of selected) {
    const compressed = extractRelevantWindow(item.chunk.content, queryTermSet, Math.min(800, charBudget));
    const partSize = compressed.length + item.chunk.title.length + 20;
    if (charBudget - partSize < 0) break;

    parts.push({
      entryId: item.chunk.entryId,
      title: item.chunk.title,
      content: compressed,
      tags: item.chunk.tags,
      source: item.chunk.source,
      score: Math.round(item.score * 1000) / 1000,
      chunk: item.chunk.totalChunks > 1 ? `${item.chunk.chunkIndex + 1}/${item.chunk.totalChunks}` : undefined,
    });

    charBudget -= partSize;
  }

  return {
    parts,
    totalTokensEstimate: Math.round(parts.reduce((s, p) => s + p.content.length + p.title.length, 0) / 4),
    entriesScanned: entries.length,
    entriesReturned: parts.length,
  };
}

// ── Hybrid Retrieval (BM25 + Semantic via RRF) ──

export function retrieveContextHybrid(
  query: string,
  opts: { maxTokens?: number; projectScope?: string; agentScope?: string[]; topK?: number } = {},
  precomputedSemantic?: SemanticResult[]
): ContextResult {
  const maxTokens = opts.maxTokens ?? 4000;
  const topK = opts.topK ?? 10;

  const bm25 = retrieveContext(query, { ...opts, maxTokens: maxTokens * 2 });
  const semantic = precomputedSemantic ?? semanticSearch(query, 20, opts.agentScope);

  if (bm25.parts.length === 0 && semantic.length === 0) {
    return { parts: [], totalTokensEstimate: 0, entriesScanned: 0, entriesReturned: 0 };
  }
  if (semantic.length === 0) {
    return bm25;
  }

  const entries = loadAllEntriesCached();
  const entryMap = new Map(entries.map((e) => [e.id, e]));

  function resolveEntryId(embeddingID: string): string | undefined {
    if (entryMap.has(embeddingID)) return embeddingID;
    for (const id of entryMap.keys()) {
      if (embeddingID.endsWith(`/${id}`) || embeddingID.endsWith(`/${id.split("/").pop()}`)) {
        return id;
      }
    }
    return undefined;
  }

  const K = 60;
  const fusedScores = new Map<string, number>();
  const bm25PartByEntryId = new Map<string, ContextResult["parts"][number]>();

  for (let rank = 0; rank < bm25.parts.length; rank++) {
    const part = bm25.parts[rank];
    fusedScores.set(part.entryId, (fusedScores.get(part.entryId) ?? 0) + 1 / (K + rank + 1));
    if (!bm25PartByEntryId.has(part.entryId)) bm25PartByEntryId.set(part.entryId, part);
  }

  for (let rank = 0; rank < semantic.length; rank++) {
    const entryId = resolveEntryId(semantic[rank].entryID) ?? semantic[rank].entryID;
    fusedScores.set(entryId, (fusedScores.get(entryId) ?? 0) + 1 / (K + rank + 1));
  }

  // Only load chunks for semantic-only results — BM25 results already have content
  const neededIds = [...fusedScores.keys()].filter((id) => !bm25PartByEntryId.has(id));
  const chunkByEntryId = new Map<string, VectorChunk>();
  if (neededIds.length > 0) {
    for (const c of chunksForEntryIds(neededIds, "knowledge")) {
      if (!chunkByEntryId.has(c.entryId)) chunkByEntryId.set(c.entryId, c);
    }
  }

  const sorted = [...fusedScores.entries()].sort((a, b) => b[1] - a[1]);

  const queryTermSet = new Set(tokenize(query));
  let charBudget = maxTokens * 4;
  const parts: ContextResult["parts"] = [];

  for (const [entryId, score] of sorted) {
    if (parts.length >= topK) break;

    const existing = bm25PartByEntryId.get(entryId);
    if (existing) {
      const partSize = existing.content.length + existing.title.length + 20;
      if (charBudget - partSize < 0) break;
      parts.push({ ...existing, score: Math.round(score * 10000) / 10000 });
      charBudget -= partSize;
    } else {
      const chunk = chunkByEntryId.get(entryId);
      if (!chunk) continue;
      const content = extractRelevantWindow(chunk.content, queryTermSet, Math.min(800, charBudget));
      const partSize = content.length + chunk.title.length + 20;
      if (charBudget - partSize < 0) break;
      parts.push({
        entryId,
        title: chunk.title,
        content,
        tags: chunk.tags,
        source: chunk.source,
        score: Math.round(score * 10000) / 10000,
      });
      charBudget -= partSize;
    }
  }

  return {
    parts,
    totalTokensEstimate: Math.round(parts.reduce((s, p) => s + p.content.length + p.title.length, 0) / 4),
    entriesScanned: bm25.entriesScanned,
    entriesReturned: parts.length,
  };
}

// ── Workspace Smart Context ──

export function workspaceContext(
  query: string,
  maxItems = 5,
  preloaded?: {
    tasks: db.TaskRow[];
    notes: db.NoteRow[];
    reminders: ReturnType<typeof db.listReminders>;
    semantic: SemanticResult[];
  }
): {
  tasks: { pk: number; title: string; status: string; priority: string; score: number; isArchived?: boolean }[];
  notes: { pk: number; title: string; project: string | null; score: number; isArchived?: boolean }[];
  reminders: { pk: number; title: string; reminderDate: Date | null; score: number }[];
  totalTokensEstimate: number;
} {
  const queryTerms = new Set(tokenize(query));
  if (queryTerms.size === 0) {
    const tasks = (preloaded?.tasks ?? db.listTasks({ excludeArchived: true })).slice(0, maxItems);
    const notes = (preloaded?.notes ?? db.listNotes({ excludeArchived: true })).slice(0, maxItems);
    const reminders = (preloaded?.reminders ?? db.listReminders({ completed: false })).slice(0, maxItems);
    return {
      tasks: tasks.map((t) => ({ pk: t.pk, title: t.title, status: t.status, priority: t.priority, score: 0 })),
      notes: notes.map((n) => ({ pk: n.pk, title: n.title, project: n.projectName, score: 0 })),
      reminders: reminders.map((r) => ({ pk: r.pk, title: r.title, reminderDate: r.reminderDate, score: 0 })),
      totalTokensEstimate: 0,
    };
  }

  const tasks = preloaded?.tasks ?? db.listTasks();
  const notes = preloaded?.notes ?? db.listNotes();
  const reminders = preloaded?.reminders ?? db.listReminders({ completed: false });

  function scoreText(text: string): number {
    const terms = tokenize(text);
    const overlap = terms.filter((t) => queryTerms.has(t)).length;
    return overlap / Math.max(queryTerms.size, 1);
  }

  const K = 60;
  const semResults = preloaded?.semantic ?? semanticSearch(query, 60);
  const semRankMap = new Map<string, number>();
  semResults.forEach((r, rank) => semRankMap.set(r.entryID, rank));

  function rrfScore(bm25Rank: number, entryKey: string): number {
    const semRank = semRankMap.get(entryKey);
    const semRrf = semRank !== undefined ? 1 / (K + semRank + 1) : 0;
    return 1 / (K + bm25Rank + 1) + semRrf;
  }

  const tasksBM25 = tasks
    .map((t) => ({ ...t, bm25: scoreText(`${t.title} ${t.detail}`) * (t.isArchived ? 0.2 : 1) }))
    .sort((a, b) => b.bm25 - a.bm25 || b.modifiedAt.getTime() - a.modifiedAt.getTime());

  const notesBM25 = notes
    .map((n) => ({ ...n, bm25: scoreText(`${n.title} ${n.content}`) * (n.isArchived ? 0.2 : 1) }))
    .sort((a, b) => b.bm25 - a.bm25 || b.modifiedAt.getTime() - a.modifiedAt.getTime());

  const remindersBM25 = reminders
    .map((r) => ({ ...r, bm25: scoreText(`${r.title} ${r.notes}`) }))
    .sort((a, b) => b.bm25 - a.bm25 || b.modifiedAt.getTime() - a.modifiedAt.getTime());

  const scoredTasks = tasksBM25
    .map((t, rank) => ({ ...t, score: rrfScore(rank, `task:${t.pk}`) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, maxItems)
    .map((t) => ({
      pk: t.pk,
      title: t.title,
      status: t.status,
      priority: t.priority,
      score: Math.round(t.score * 10000) / 10000,
      ...(t.isArchived ? { isArchived: true } : {}),
    }));

  const scoredNotes = notesBM25
    .map((n, rank) => ({ ...n, score: rrfScore(rank, `note:${n.pk}`) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, maxItems)
    .map((n) => ({
      pk: n.pk,
      title: n.title,
      project: n.projectName,
      score: Math.round(n.score * 10000) / 10000,
      ...(n.isArchived ? { isArchived: true } : {}),
    }));

  const scoredReminders = remindersBM25
    .map((r, rank) => ({ ...r, score: rrfScore(rank, `reminder:${r.pk}`) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, maxItems)
    .map((r) => ({
      pk: r.pk,
      title: r.title,
      reminderDate: r.reminderDate,
      score: Math.round(r.score * 10000) / 10000,
    }));

  const totalChars = [...scoredTasks, ...scoredNotes, ...scoredReminders].reduce(
    (s, item) => s + JSON.stringify(item).length,
    0
  );

  return {
    tasks: scoredTasks,
    notes: scoredNotes,
    reminders: scoredReminders,
    totalTokensEstimate: Math.round(totalChars / 4),
  };
}

// ── Unified Search (workspace + knowledge, BM25 + semantic, RRF-fused) ──

export interface UnifiedResult {
  type: "task" | "note" | "reminder" | "knowledge";
  entryId: string;
  pk?: number;
  title: string;
  content: string;
  project?: string | null;
  status?: string;
  priority?: string;
  tags?: string[];
  source?: string;
  score: number;
}

export function unifiedSearch(
  query: string,
  opts: { maxItems?: number; types?: Array<"task" | "note" | "reminder" | "knowledge"> } = {}
): UnifiedResult[] {
  const maxItems = opts.maxItems ?? 10;
  const types = opts.types ?? ["task", "note", "reminder", "knowledge"];
  const K = 60;

  // Load workspace data once
  const tasks = db.listTasks();
  const notes = db.listNotes();
  const reminders = db.listReminders({ completed: false });

  const semantic = semanticSearch(query, 60);

  const taskDetail = new Map(tasks.map((t) => [t.pk, t.detail]));
  const noteContent = new Map(notes.map((n) => [n.pk, n.content]));
  const reminderNotes = new Map(reminders.map((r) => [r.pk, r.notes]));

  const scoreMap = new Map<string, number>();
  const resultMap = new Map<string, UnifiedResult>();

  const ws = workspaceContext(query, 20, { tasks, notes, reminders, semantic });

  if (types.includes("task")) {
    ws.tasks.forEach((t, rank) => {
      const key = `task:${t.pk}`;
      scoreMap.set(key, (scoreMap.get(key) ?? 0) + 1 / (K + rank + 1));
      if (!resultMap.has(key))
        resultMap.set(key, {
          type: "task",
          entryId: key,
          pk: t.pk,
          title: t.title,
          content: taskDetail.get(t.pk) ?? "",
          status: t.status,
          priority: t.priority,
          score: 0,
        });
    });
  }

  if (types.includes("note")) {
    ws.notes.forEach((n, rank) => {
      const key = `note:${n.pk}`;
      scoreMap.set(key, (scoreMap.get(key) ?? 0) + 1 / (K + rank + 1));
      if (!resultMap.has(key))
        resultMap.set(key, {
          type: "note",
          entryId: key,
          pk: n.pk,
          title: n.title,
          content: noteContent.get(n.pk) ?? "",
          project: n.project,
          score: 0,
        });
    });
  }

  if (types.includes("reminder")) {
    ws.reminders.forEach((r, rank) => {
      const key = `reminder:${r.pk}`;
      scoreMap.set(key, (scoreMap.get(key) ?? 0) + 1 / (K + rank + 1));
      if (!resultMap.has(key))
        resultMap.set(key, {
          type: "reminder",
          entryId: key,
          pk: r.pk,
          title: r.title,
          content: reminderNotes.get(r.pk) ?? "",
          score: 0,
        });
    });
  }

  if (types.includes("knowledge")) {
    // Pass pre-computed semantic (trimmed to top 20) to avoid a second search
    const kn = retrieveContextHybrid(query, { topK: 20 }, semantic);
    kn.parts.forEach((p, rank) => {
      const key = `knowledge:${p.entryId}`;
      scoreMap.set(key, (scoreMap.get(key) ?? 0) + 1 / (K + rank + 1));
      if (!resultMap.has(key))
        resultMap.set(key, {
          type: "knowledge",
          entryId: p.entryId,
          title: p.title,
          content: p.content,
          tags: p.tags,
          source: p.source,
          score: 0,
        });
    });
  }

  return [...scoreMap.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, maxItems)
    .flatMap(([key, score]) => {
      const result = resultMap.get(key);
      return result ? [{ ...result, score: Math.round(score * 10000) / 10000 }] : [];
    });
}
