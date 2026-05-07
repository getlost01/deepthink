import { readFileSync, readdirSync, existsSync } from "fs";
import { join, relative } from "path";
import { KNOWLEDGE_DIR, KNOWLEDGE_DIRS } from "../config";
import { semanticSearch, indexEntry, type IndexableEntry } from "./embedding-service";
import {
  type VectorChunk,
  allChunks,
  simpleHash,
  semanticChunk,
  upsertChunks,
  deleteChunksForEntry,
  contentHash as getContentHash,
  pruneStaleEntries,
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
  parts: { title: string; content: string; tags: string[]; source: string; score: number; chunk?: string }[];
  totalTokensEstimate: number;
  entriesScanned: number;
  entriesReturned: number;
}

// ── Stopwords ──

const STOPWORDS = new Set([
  "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
  "have", "has", "had", "do", "does", "did", "will", "would", "could",
  "should", "may", "might", "shall", "can", "need", "dare", "ought",
  "and", "but", "or", "nor", "not", "so", "yet", "both", "either",
  "neither", "each", "every", "all", "any", "few", "more", "most",
  "other", "some", "such", "no", "only", "own", "same", "than",
  "too", "very", "just", "because", "as", "until", "while", "of",
  "at", "by", "for", "with", "about", "against", "between", "through",
  "during", "before", "after", "above", "below", "to", "from", "up",
  "down", "in", "out", "on", "off", "over", "under", "again", "further",
  "then", "once", "here", "there", "when", "where", "why", "how",
  "what", "which", "who", "whom", "this", "that", "these", "those",
  "i", "me", "my", "myself", "we", "our", "ours", "ourselves",
  "you", "your", "yours", "yourself", "yourselves", "he", "him",
  "his", "himself", "she", "her", "hers", "herself", "it", "its",
  "itself", "they", "them", "their", "theirs", "themselves",
]);

// ── Tokenizer ──

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 1 && !STOPWORDS.has(t));
}

function computeTF(tokens: string[]): Record<string, number> {
  const tf: Record<string, number> = {};
  for (const t of tokens) tf[t] = (tf[t] ?? 0) + 1;
  const max = Math.max(...Object.values(tf), 1);
  for (const t in tf) tf[t] /= max;
  return tf;
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
          const importedAt = isNaN(parsed.getTime()) ? new Date() : parsed;

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

// ── Ensure VectorStore is populated ──

function ensureIndexed(entries: IndexedEntry[]): void {
  for (const entry of entries) {
    const hash = simpleHash(entry.content);
    const existing = getContentHash(entry.id);
    if (existing !== null && existing === hash) continue;

    const chunks = semanticChunk(
      entry.content, entry.id, "knowledge", entry.title,
      entry.tags, entry.source, entry.importedAt, hash
    );
    upsertChunks(chunks);
  }
  const validIds = new Set(entries.map(e => e.id));
  pruneStaleEntries(validIds, "knowledge");
}

// ── BM25 Retrieval ──

export function retrieveContext(
  query: string,
  opts: { maxTokens?: number; projectScope?: string; agentScope?: string[]; topK?: number } = {}
): ContextResult {
  const maxTokens = opts.maxTokens ?? 4000;
  const topK = opts.topK ?? 10;

  const entries = loadAllEntries();
  if (entries.length === 0) return { parts: [], totalTokensEstimate: 0, entriesScanned: 0, entriesReturned: 0 };

  ensureIndexed(entries);

  const queryTerms = tokenize(query);
  if (queryTerms.length === 0) return { parts: [], totalTokensEstimate: 0, entriesScanned: entries.length, entriesReturned: 0 };

  // Build TF-IDF index
  const docFreq: Record<string, number> = {};
  const docTerms: Map<string, Record<string, number>> = new Map();

  for (const entry of entries) {
    const allText = `${entry.title} ${entry.tags.join(" ")} ${entry.content}`;
    const terms = tokenize(allText);
    const tf = computeTF(terms);
    docTerms.set(entry.id, tf);
    for (const term of Object.keys(tf)) {
      docFreq[term] = (docFreq[term] ?? 0) + 1;
    }
  }

  // Get chunks from VectorStore
  const chunks = allChunks({ scope: opts.agentScope });

  const docCount = entries.length;
  const avgDocLen = chunks.reduce((s, c) => s + c.content.length, 0) / Math.max(chunks.length, 1);
  const k1 = 1.5;
  const b = 0.75;
  const queryTF = computeTF(queryTerms);
  const querySet = new Set(queryTerms);

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
      const tfNorm = (termTF * (k1 + 1)) / (termTF + k1 * (1 - b + b * docLen / avgDocLen));
      score += idf * tfNorm * qFreq;
    }

    const titleTerms = new Set(tokenize(chunk.title));
    const titleOverlap = [...titleTerms].filter((t) => querySet.has(t)).length;
    if (titleOverlap > 0) score *= 1 + titleOverlap * 0.5;

    const tagTerms = new Set(chunk.tags.flatMap((t) => tokenize(t)));
    const tagOverlap = [...tagTerms].filter((t) => querySet.has(t)).length;
    if (tagOverlap > 0) score *= 1 + tagOverlap * 0.3;

    const daysSince = (Date.now() - chunk.importedAt.getTime()) / 86400000;
    score *= Math.exp(-daysSince / 90) * 0.3 + 0.7;

    if (opts.projectScope) {
      const p = opts.projectScope.toLowerCase();
      if (chunk.title.toLowerCase().includes(p) || chunk.tags.some((t) => t.toLowerCase() === p)) {
        score *= 1.5;
      }
    }

    if (score > 0.01) scored.push({ chunk, score });
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
    const compressed = item.chunk.content.slice(0, Math.min(800, charBudget));
    const partSize = compressed.length + item.chunk.title.length + 20;
    if (charBudget - partSize < 0) break;

    parts.push({
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
  opts: { maxTokens?: number; projectScope?: string; agentScope?: string[]; topK?: number } = {}
): ContextResult {
  const maxTokens = opts.maxTokens ?? 4000;
  const topK = opts.topK ?? 10;

  const bm25 = retrieveContext(query, { ...opts, maxTokens: maxTokens * 2 });
  const semantic = semanticSearch(query, 20, opts.agentScope);

  if (semantic.length === 0) {
    return retrieveContext(query, opts);
  }

  const entries = loadAllEntries();
  const entryMap = new Map(entries.map((e) => [e.id, e]));
  const chunks = allChunks({ scope: opts.agentScope });

  function resolveEntry(embeddingID: string): IndexedEntry | undefined {
    const direct = entryMap.get(embeddingID);
    if (direct) return direct;
    for (const [id, entry] of entryMap) {
      if (embeddingID.endsWith("/" + id) || embeddingID.endsWith("/" + id.split("/").pop())) {
        return entry;
      }
    }
    return undefined;
  }

  const K = 60;
  const fusedScores = new Map<string, number>();
  const titleToChunk = new Map<string, VectorChunk>();

  for (let rank = 0; rank < bm25.parts.length; rank++) {
    const title = bm25.parts[rank].title;
    fusedScores.set(title, (fusedScores.get(title) ?? 0) + 1 / (K + rank + 1));
  }

  for (let rank = 0; rank < semantic.length; rank++) {
    const entry = resolveEntry(semantic[rank].entryID);
    if (!entry) continue;
    const title = entry.title;
    fusedScores.set(title, (fusedScores.get(title) ?? 0) + 1 / (K + rank + 1));
    if (!titleToChunk.has(title)) {
      const chunk = chunks.find(c => c.entryId === entry.id);
      if (chunk) titleToChunk.set(title, chunk);
    }
  }

  const sorted = [...fusedScores.entries()].sort((a, b) => b[1] - a[1]);

  let charBudget = maxTokens * 4;
  const parts: ContextResult["parts"] = [];

  for (const [title, score] of sorted) {
    if (parts.length >= topK) break;

    const existing = bm25.parts.find((p) => p.title === title);
    if (existing) {
      const partSize = existing.content.length + title.length + 20;
      if (charBudget - partSize < 0) break;
      parts.push({ ...existing, score: Math.round(score * 10000) / 10000 });
      charBudget -= partSize;
    } else {
      const chunk = titleToChunk.get(title);
      if (!chunk) continue;
      const content = chunk.content.slice(0, Math.min(800, charBudget));
      const partSize = content.length + title.length + 20;
      if (charBudget - partSize < 0) break;
      parts.push({
        title,
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

import * as db from "./db";

export function workspaceContext(query: string, maxItems = 5): {
  tasks: { pk: number; title: string; status: string; priority: string; score: number; isArchived?: boolean }[];
  notes: { pk: number; title: string; project: string | null; score: number; isArchived?: boolean }[];
  reminders: { pk: number; title: string; reminderDate: Date | null; score: number }[];
  totalTokensEstimate: number;
} {
  const queryTerms = new Set(tokenize(query));
  if (queryTerms.size === 0) {
    const tasks = db.listTasks({ excludeArchived: true }).slice(0, maxItems);
    const notes = db.listNotes({ excludeArchived: true }).slice(0, maxItems);
    const reminders = db.listReminders({ completed: false }).slice(0, maxItems);
    return {
      tasks: tasks.map((t) => ({ pk: t.pk, title: t.title, status: t.status, priority: t.priority, score: 0 })),
      notes: notes.map((n) => ({ pk: n.pk, title: n.title, project: n.projectName, score: 0 })),
      reminders: reminders.map((r) => ({ pk: r.pk, title: r.title, reminderDate: r.reminderDate, score: 0 })),
      totalTokensEstimate: 0,
    };
  }

  function scoreText(text: string): number {
    const terms = tokenize(text);
    const overlap = terms.filter((t) => queryTerms.has(t)).length;
    return overlap / Math.max(queryTerms.size, 1);
  }

  const tasks = db.listTasks()
    .map((t) => ({ ...t, score: scoreText(`${t.title} ${t.detail}`) * (t.isArchived ? 0.2 : 1) }))
    .sort((a, b) => b.score - a.score || b.modifiedAt.getTime() - a.modifiedAt.getTime())
    .slice(0, maxItems)
    .map((t) => ({ pk: t.pk, title: t.title, status: t.status, priority: t.priority, score: Math.round(t.score * 100) / 100, ...(t.isArchived ? { isArchived: true } : {}) }));

  const notes = db.listNotes()
    .map((n) => ({ ...n, score: scoreText(`${n.title} ${n.content}`) * (n.isArchived ? 0.2 : 1) }))
    .sort((a, b) => b.score - a.score || b.modifiedAt.getTime() - a.modifiedAt.getTime())
    .slice(0, maxItems)
    .map((n) => ({ pk: n.pk, title: n.title, project: n.projectName, score: Math.round(n.score * 100) / 100, ...(n.isArchived ? { isArchived: true } : {}) }));

  const reminders = db.listReminders({ completed: false })
    .map((r) => ({ ...r, score: scoreText(`${r.title} ${r.notes}`) }))
    .sort((a, b) => b.score - a.score || b.modifiedAt.getTime() - a.modifiedAt.getTime())
    .slice(0, maxItems)
    .map((r) => ({ pk: r.pk, title: r.title, reminderDate: r.reminderDate, score: Math.round(r.score * 100) / 100 }));

  const totalChars = [...tasks, ...notes, ...reminders].reduce(
    (s, item) => s + JSON.stringify(item).length, 0
  );

  return { tasks, notes, reminders, totalTokensEstimate: Math.round(totalChars / 4) };
}
