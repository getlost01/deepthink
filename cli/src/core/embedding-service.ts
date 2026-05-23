import { execFileSync, execSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DEEPTHINK_ROOT } from "../config";
import * as db from "./db";
import { hexToUUID } from "./db";
import {
  batchContentHashes,
  chunksWithEmbeddings,
  deleteChunksForEntry,
  deleteExhaustedPendingReindex,
  deletePendingReindex,
  embeddedCount,
  enqueuePendingReindex,
  contentHash as getContentHash,
  getPendingReindex,
  incrementPendingRetry,
  pruneStaleEntries,
  replaceChunksForEntry,
  semanticChunk,
  simpleHash,
} from "./vector-store";

const CACHE_DIR = join(DEEPTHINK_ROOT, ".cache");
const HELPER_BIN = join(CACHE_DIR, "embed-helper");
const HELPER_SRC = join(CACHE_DIR, "embed-helper.swift");
const HELPER_VERSION_FILE = join(CACHE_DIR, "embed-helper.version");

// Bump this whenever SWIFT_SOURCE changes so stale binaries are auto-recompiled.
const SWIFT_VERSION = "2";

const _embeddingCache = new Map<string, { vector: Float32Array; ts: number }>();
const EMBEDDING_CACHE_TTL = 5 * 60 * 1000;
const EMBEDDING_CACHE_MAX = 200;

const SWIFT_SOURCE = `import NaturalLanguage
import Foundation

let args = CommandLine.arguments.dropFirst()

if args.first == "--batch" {
    // Batch mode: read one text per line from stdin, emit one CSV vector per line.
    // An empty output line signals embedding failure for that input.
    guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
        fputs("error: NLEmbedding unavailable\\n", stderr)
        exit(1)
    }
    while let line = readLine(strippingNewline: true) {
        if let vector = embedding.vector(for: line) {
            print(vector.map { String($0) }.joined(separator: ","))
        } else {
            print("")
        }
    }
} else {
    // Single-arg mode (backward compat)
    guard !args.isEmpty else {
        fputs("usage: embed-helper <text>\\n", stderr)
        exit(1)
    }
    let text = args.joined(separator: " ")
    guard let embedding = NLEmbedding.sentenceEmbedding(for: .english),
          let vector = embedding.vector(for: text) else {
        fputs("error: NLEmbedding unavailable\\n", stderr)
        exit(1)
    }
    print(vector.map { String($0) }.joined(separator: ","))
}
`;

function ensureHelper(): boolean {
  if (existsSync(HELPER_BIN) && existsSync(HELPER_VERSION_FILE)) {
    try {
      if (readFileSync(HELPER_VERSION_FILE, "utf-8").trim() === SWIFT_VERSION) return true;
    } catch {}
    // Version mismatch — delete stale artifacts and recompile.
    try {
      unlinkSync(HELPER_BIN);
    } catch {}
    try {
      unlinkSync(HELPER_VERSION_FILE);
    } catch {}
  } else if (existsSync(HELPER_BIN)) {
    // Binary exists but no version file — treat as stale.
    try {
      unlinkSync(HELPER_BIN);
    } catch {}
  }
  try {
    if (!existsSync(CACHE_DIR)) mkdirSync(CACHE_DIR, { recursive: true });
    writeFileSync(HELPER_SRC, SWIFT_SOURCE);
    execSync(`swiftc -O -o '${HELPER_BIN}' '${HELPER_SRC}'`, {
      timeout: 30000,
      stdio: ["pipe", "pipe", "pipe"],
    });
    writeFileSync(HELPER_VERSION_FILE, SWIFT_VERSION);
    return true;
  } catch {
    return false;
  }
}

// Embeds multiple texts in a single subprocess call. Cache is consulted/updated per text.
function embedBatch(texts: string[]): (Float32Array | null)[] {
  if (texts.length === 0) return [];
  if (!ensureHelper()) return texts.map(() => null);

  const now = Date.now();
  const results: (Float32Array | null)[] = new Array(texts.length).fill(null);
  const uncachedIndices: number[] = [];
  const uncachedTexts: string[] = [];

  for (let i = 0; i < texts.length; i++) {
    const cached = _embeddingCache.get(texts[i]);
    if (cached && now - cached.ts < EMBEDDING_CACHE_TTL) {
      results[i] = cached.vector;
    } else {
      uncachedIndices.push(i);
      uncachedTexts.push(texts[i]);
    }
  }

  if (uncachedTexts.length === 0) return results;

  try {
    // Newlines would break the line-delimited protocol — replace with spaces.
    const stdin = uncachedTexts.map((t) => t.replace(/\n/g, " ")).join("\n");
    const output = execFileSync(HELPER_BIN, ["--batch"], {
      input: stdin,
      timeout: Math.max(10000, uncachedTexts.length * 800),
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    const lines = output.split("\n");
    for (let j = 0; j < uncachedIndices.length; j++) {
      const line = (lines[j] ?? "").trim();
      if (!line) continue;
      const values = line.split(",").map(Number);
      if (values.length > 0 && !values.some(Number.isNaN)) {
        const vector = new Float32Array(values);
        if (_embeddingCache.size >= EMBEDDING_CACHE_MAX) {
          _embeddingCache.delete(_embeddingCache.keys().next().value!);
        }
        _embeddingCache.set(texts[uncachedIndices[j]], { vector, ts: now });
        results[uncachedIndices[j]] = vector;
      }
    }
  } catch {
    // Leave nulls for uncached texts on failure.
  }

  return results;
}

function embedQuery(text: string): Float32Array | null {
  return embedBatch([text])[0] ?? null;
}

function cosineSimilarity(a: number[] | Float32Array, b: number[] | Float32Array): number {
  if (a.length !== b.length || a.length === 0) return 0;
  let dot = 0,
    normA = 0,
    normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  const denom = Math.sqrt(normA) * Math.sqrt(normB);
  return denom > 0 ? dot / denom : 0;
}

// MARK: - Indexing

export interface IndexableEntry {
  id: string;
  type: string;
  title: string;
  content: string;
  tags: string[];
  source: string;
  importedAt: Date;
}

// Internal: accepts a pre-loaded hash map to avoid per-entry DB queries.
function indexEntryCore(entry: IndexableEntry, knownHashes?: Map<string, number>): void {
  const hash = simpleHash(entry.content);
  const existing = knownHashes !== undefined ? (knownHashes.get(entry.id) ?? null) : getContentHash(entry.id);
  if (existing !== null && existing === hash) return;

  const chunks = semanticChunk(
    entry.content,
    entry.id,
    entry.type,
    entry.title,
    entry.tags,
    entry.source,
    entry.importedAt,
    hash
  );

  const texts = chunks.map((c) => `${entry.title}. ${c.content.slice(0, 500)}`);
  const embeddings = embedBatch(texts);
  const withEmbeddings = chunks.map((chunk, i) => ({ ...chunk, embedding: embeddings[i] ?? null }));

  if (withEmbeddings.every((c) => c.embedding === null)) {
    throw new Error(`embedding failed for all chunks of ${entry.id} — will retry`);
  }

  replaceChunksForEntry(entry.id, withEmbeddings);
}

export function indexEntry(entry: IndexableEntry): void {
  try {
    indexEntryCore(entry);
  } catch {
    enqueuePendingReindex(entry.id, entry.type);
  }
}

export function indexEntries(entries: IndexableEntry[]): void {
  if (entries.length === 0) return;
  const knownHashes = batchContentHashes(entries.map((e) => e.id));
  for (const entry of entries) indexEntryCore(entry, knownHashes);
  const validIds = new Set(entries.map((e) => e.id));
  pruneStaleEntries(validIds, entries[0].type ?? "knowledge");
}

export function removeEntry(entryId: string): void {
  deleteChunksForEntry(entryId);
}

// Re-embed all workspace items that are missing or have stale embeddings.
// Safe to call multiple times — unchanged items are skipped.
export function reindexWorkspace(): { indexed: number } {
  const tasks = db.listTasks({ excludeArchived: false });
  const notes = db.listNotes({ excludeArchived: false });
  const reminders = db.listReminders({});
  const projects = db.listProjects();

  const entries: IndexableEntry[] = [
    ...tasks.map((t) => ({
      id: `task:${hexToUUID(t.id)}`,
      type: "task",
      title: t.title,
      content: taskContent(t.title, t.detail, t.status, t.isArchived),
      tags: [],
      source: t.isArchived ? "archive" : "task",
      importedAt: t.modifiedAt,
    })),
    ...notes.map((n) => ({
      id: `note:${hexToUUID(n.id)}`,
      type: "note",
      title: n.title,
      content: noteContent(n.title, n.content, n.isArchived),
      tags: [],
      source: n.isArchived ? "archive" : "note",
      importedAt: n.modifiedAt,
    })),
    ...reminders.map((r) => ({
      id: `reminder:${hexToUUID(r.id)}`,
      type: "reminder",
      title: r.title,
      content: reminderContent(r.title, r.notes, r.isCompleted),
      tags: [],
      source: "reminder",
      importedAt: r.modifiedAt,
    })),
    ...projects.map((p) => ({
      id: `project:${hexToUUID(p.id)}`,
      type: "project",
      title: p.name,
      content: projectContent(p.name, p.summary, p.isArchived),
      tags: [],
      source: p.isArchived ? "archive" : "project",
      importedAt: p.modifiedAt,
    })),
  ];

  const knownHashes = batchContentHashes(entries.map((e) => e.id));
  let indexed = 0;
  for (const entry of entries) {
    const hash = simpleHash(entry.content);
    if ((knownHashes.get(entry.id) ?? null) !== hash) {
      try {
        indexEntryCore(entry, knownHashes);
        indexed++;
      } catch {
        enqueuePendingReindex(entry.id, entry.type);
      }
    }
  }

  const validIds = new Set(entries.map((e) => e.id));
  pruneStaleEntries(new Set([...validIds].filter((id) => id.startsWith("task:"))), "task");
  pruneStaleEntries(new Set([...validIds].filter((id) => id.startsWith("note:"))), "note");
  pruneStaleEntries(new Set([...validIds].filter((id) => id.startsWith("reminder:"))), "reminder");
  pruneStaleEntries(new Set([...validIds].filter((id) => id.startsWith("project:"))), "project");

  return { indexed };
}

// Drain the pending_reindex queue — processes entries that failed inline indexing.
export function drainPendingReindex(): { processed: number; failed: number } {
  const pending = getPendingReindex(3);
  if (pending.length === 0) return { processed: 0, failed: 0 };

  const tasks = db.listTasks({ excludeArchived: false });
  const notes = db.listNotes({ excludeArchived: false });
  const reminders = db.listReminders({});
  const projects = db.listProjects();

  const taskMap = new Map(tasks.map((t) => [`task:${hexToUUID(t.id)}`, t]));
  const noteMap = new Map(notes.map((n) => [`note:${hexToUUID(n.id)}`, n]));
  const reminderMap = new Map(reminders.map((r) => [`reminder:${hexToUUID(r.id)}`, r]));
  const projectMap = new Map(projects.map((p) => [`project:${hexToUUID(p.id)}`, p]));

  let processed = 0;
  let failed = 0;

  for (const row of pending) {
    try {
      if (row.operation === "delete") {
        deleteChunksForEntry(row.entryId);
        deletePendingReindex(row.entryId);
        processed++;
        continue;
      }

      let entry: IndexableEntry | null = null;

      if (row.entryType === "task") {
        const t = taskMap.get(row.entryId);
        if (!t) { deletePendingReindex(row.entryId); continue; }
        entry = { id: row.entryId, type: "task", title: t.title, content: taskContent(t.title, t.detail, t.status, t.isArchived), tags: [], source: t.isArchived ? "archive" : "task", importedAt: t.modifiedAt };
      } else if (row.entryType === "note") {
        const n = noteMap.get(row.entryId);
        if (!n) { deletePendingReindex(row.entryId); continue; }
        entry = { id: row.entryId, type: "note", title: n.title, content: noteContent(n.title, n.content, n.isArchived), tags: [], source: n.isArchived ? "archive" : "note", importedAt: n.modifiedAt };
      } else if (row.entryType === "reminder") {
        const r = reminderMap.get(row.entryId);
        if (!r) { deletePendingReindex(row.entryId); continue; }
        entry = { id: row.entryId, type: "reminder", title: r.title, content: reminderContent(r.title, r.notes, r.isCompleted), tags: [], source: "reminder", importedAt: r.modifiedAt };
      } else if (row.entryType === "project") {
        const p = projectMap.get(row.entryId);
        if (!p) { deletePendingReindex(row.entryId); continue; }
        entry = { id: row.entryId, type: "project", title: p.name, content: projectContent(p.name, p.summary, p.isArchived), tags: [], source: p.isArchived ? "archive" : "project", importedAt: p.modifiedAt };
      }

      if (!entry) { deletePendingReindex(row.entryId); continue; }

      indexEntryCore(entry);
      deletePendingReindex(row.entryId);
      processed++;
    } catch {
      incrementPendingRetry(row.entryId);
      failed++;
    }
  }

  deleteExhaustedPendingReindex();
  return { processed, failed };
}

// Start a 30-second background reconciler that drains the pending_reindex queue.
export function startReconciler(): void {
  setInterval(() => { try { drainPendingReindex(); } catch {} }, 30_000);
}

// MARK: - Content string builders (canonical format — keep in sync with Swift side)

export function taskContent(title: string, detail: string, status: string, isArchived: boolean): string {
  return `${title}\n${detail}\nstatus:${status}\narchived:${isArchived}`;
}

export function noteContent(title: string, content: string, isArchived: boolean): string {
  return `${title}\n${content}\narchived:${isArchived}`;
}

export function reminderContent(title: string, notes: string | null | undefined, isCompleted: boolean): string {
  return `${title}\n${notes ?? ""}\ncompleted:${isCompleted}`;
}

export function projectContent(name: string, summary: string | null | undefined, isArchived: boolean): string {
  return `${name}\n${summary ?? ""}\narchived:${isArchived}`;
}

// MARK: - Search

export interface SemanticResult {
  entryID: string;
  score: number;
}

export function semanticSearch(query: string, topK: number = 10, scope?: string[]): SemanticResult[] {
  const queryVector = embedQuery(query);
  if (!queryVector) return [];

  const entries = chunksWithEmbeddings({ scope });
  // Track the best-scoring chunk per entry (not just first-seen).
  const bestScores = new Map<string, number>();

  for (const { chunk, embedding } of entries) {
    const similarity = cosineSimilarity(queryVector, embedding);
    if (similarity > 0.3) {
      const prev = bestScores.get(chunk.entryId);
      if (prev === undefined || similarity > prev) bestScores.set(chunk.entryId, similarity);
    }
  }

  return [...bestScores.entries()]
    .map(([entryID, score]) => ({ entryID, score }))
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
}

export function embeddingStats(): { indexed: number; available: boolean } {
  const available = ensureHelper();
  return { indexed: embeddedCount(), available };
}
