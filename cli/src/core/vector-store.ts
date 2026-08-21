import { Database } from "bun:sqlite";
import { existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { DEEPTHINK_ROOT } from "../config";

const DATA_DIR = join(DEEPTHINK_ROOT, "data");
const DB_PATH = join(DATA_DIR, "vectors.db");

let _db: Database | null = null;

function getDB(): Database {
  if (_db) return _db;

  if (!existsSync(DATA_DIR)) mkdirSync(DATA_DIR, { recursive: true });

  _db = new Database(DB_PATH);
  _db.exec("PRAGMA journal_mode=WAL");
  _db.exec("PRAGMA synchronous=NORMAL");
  _db.exec("PRAGMA cache_size=-8000");
  _db.exec("PRAGMA busy_timeout=5000");

  _db.exec(`
    CREATE TABLE IF NOT EXISTS chunks (
      id TEXT PRIMARY KEY,
      entry_id TEXT NOT NULL,
      entry_type TEXT NOT NULL DEFAULT 'knowledge',
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      tags TEXT DEFAULT '[]',
      source TEXT DEFAULT '',
      imported_at REAL NOT NULL,
      chunk_index INTEGER NOT NULL DEFAULT 0,
      total_chunks INTEGER NOT NULL DEFAULT 1,
      content_hash INTEGER NOT NULL DEFAULT 0,
      embedding BLOB,
      agent_id TEXT,
      session_id TEXT,
      visibility TEXT NOT NULL DEFAULT 'shared',
      superseded_by TEXT
    )
  `);
  _db.exec("CREATE INDEX IF NOT EXISTS idx_chunks_entry_id ON chunks(entry_id)");
  _db.exec("CREATE INDEX IF NOT EXISTS idx_chunks_entry_type ON chunks(entry_type)");
  _db.exec("CREATE INDEX IF NOT EXISTS idx_chunks_source ON chunks(source)");
  _db.exec("CREATE INDEX IF NOT EXISTS idx_chunks_hash ON chunks(content_hash)");

  _db.exec(`
    CREATE TABLE IF NOT EXISTS meta (
      key TEXT PRIMARY KEY,
      value TEXT
    )
  `);

  _db.exec(`
    CREATE TABLE IF NOT EXISTS pending_reindex (
      entry_id    TEXT PRIMARY KEY,
      entry_type  TEXT NOT NULL,
      operation   TEXT NOT NULL DEFAULT 'upsert',
      queued_at   INTEGER NOT NULL,
      retry_count INTEGER NOT NULL DEFAULT 0
    )
  `);

  // Cross-type relationship graph (task ↔ note ↔ knowledge ↔ session ↔ reminder).
  // Directed edges; (from, to, relation) is unique so re-linking is idempotent.
  _db.exec(`
    CREATE TABLE IF NOT EXISTS links (
      from_type  TEXT NOT NULL,
      from_id    TEXT NOT NULL,
      to_type    TEXT NOT NULL,
      to_id      TEXT NOT NULL,
      relation   TEXT NOT NULL DEFAULT 'related',
      created_at INTEGER NOT NULL,
      PRIMARY KEY (from_type, from_id, to_type, to_id, relation)
    )
  `);
  _db.exec("CREATE INDEX IF NOT EXISTS idx_links_from ON links(from_type, from_id)");
  _db.exec("CREATE INDEX IF NOT EXISTS idx_links_to ON links(to_type, to_id)");

  runMigrations(_db);
  return _db;
}

// Idempotent schema migrations for databases created before a column existed.
// New DBs already have every column from CREATE TABLE above; this only backfills
// pre-existing installs. Tracked under our OWN meta key — the Swift app owns
// `meta.schema_version`, so we must not write that one or the two migrators fight.
const MCP_SCHEMA_VERSION = 2;

function ensureColumn(db: Database, table: string, column: string, ddl: string): void {
  const cols = db.query(`PRAGMA table_info(${table})`).all() as { name: string }[];
  if (!cols.some((c) => c.name === column)) {
    db.exec(`ALTER TABLE ${table} ADD COLUMN ${ddl}`);
  }
}

function runMigrations(db: Database): void {
  ensureColumn(db, "chunks", "agent_id", "agent_id TEXT");
  ensureColumn(db, "chunks", "session_id", "session_id TEXT");
  ensureColumn(db, "chunks", "visibility", "visibility TEXT NOT NULL DEFAULT 'shared'");
  ensureColumn(db, "chunks", "superseded_by", "superseded_by TEXT");
  db.exec("CREATE INDEX IF NOT EXISTS idx_chunks_agent ON chunks(agent_id)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_chunks_superseded ON chunks(superseded_by)");
  db.run(
    "INSERT INTO meta (key, value) VALUES ('mcp_schema_version', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
    [String(MCP_SCHEMA_VERSION)]
  );
}

// MARK: - Types

export type ChunkVisibility = "private" | "shared" | "handoff";

export interface VectorChunk {
  id: string;
  entryId: string;
  entryType: string;
  title: string;
  content: string;
  tags: string[];
  source: string;
  importedAt: Date;
  chunkIndex: number;
  totalChunks: number;
  contentHash: number;
  embedding: Float32Array | null;
  // Multi-agent provenance & lifecycle (Phase 1/3).
  agentId: string | null;
  sessionId: string | null;
  visibility: ChunkVisibility;
  supersededBy: string | null;
}

// MARK: - CRUD

const upsertSQL = `
  INSERT OR REPLACE INTO chunks
  (id, entry_id, entry_type, title, content, tags, source, imported_at, chunk_index, total_chunks, content_hash, embedding, agent_id, session_id, visibility, superseded_by)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
`;

// Positional bind values for upsertSQL — single source of truth so every writer
// stays in lockstep with the column list.
function chunkValues(chunk: VectorChunk): any[] {
  return [
    chunk.id,
    chunk.entryId,
    chunk.entryType,
    chunk.title,
    chunk.content,
    JSON.stringify(chunk.tags),
    chunk.source,
    chunk.importedAt.getTime() / 1000,
    chunk.chunkIndex,
    chunk.totalChunks,
    chunk.contentHash,
    chunk.embedding ? Buffer.from(chunk.embedding.buffer) : null,
    chunk.agentId,
    chunk.sessionId,
    chunk.visibility,
    chunk.supersededBy,
  ];
}

export function upsertChunk(chunk: VectorChunk): void {
  getDB().run(upsertSQL, chunkValues(chunk));
}

export function upsertChunks(chunks: VectorChunk[]): void {
  const db = getDB();
  const stmt = db.prepare(upsertSQL);
  const tx = db.transaction(() => {
    for (const chunk of chunks) stmt.run(...chunkValues(chunk));
  });
  tx();
}

export function deleteChunksForEntry(entryId: string): void {
  getDB().run("DELETE FROM chunks WHERE entry_id = ?", [entryId]);
}

// Atomically replaces all chunks for an entry — delete + insert in one transaction.
// Prevents the window where an entry has zero chunks between a delete and re-insert.
export function replaceChunksForEntry(entryId: string, chunks: VectorChunk[]): void {
  const db = getDB();
  const stmt = db.prepare(upsertSQL);
  const tx = db.transaction(() => {
    db.run("DELETE FROM chunks WHERE entry_id = ?", [entryId]);
    for (const chunk of chunks) stmt.run(...chunkValues(chunk));
  });
  tx();
}

export function deleteChunksByType(entryType: string): void {
  getDB().run("DELETE FROM chunks WHERE entry_type = ?", [entryType]);
}

export function pruneStaleEntries(validIds: Set<string>, entryType: string): void {
  const existing = allEntryIds(entryType);
  const stale = existing.filter((id) => !validIds.has(id));
  if (stale.length === 0) return;

  const db = getDB();
  const stmt = db.prepare("DELETE FROM chunks WHERE entry_id = ? AND entry_type = ?");
  const tx = db.transaction(() => {
    for (const id of stale) stmt.run(id, entryType);
  });
  tx();
}

// MARK: - Queries

export function contentHash(entryId: string): number | null {
  const row = getDB().query("SELECT content_hash FROM chunks WHERE entry_id = ? LIMIT 1").get(entryId) as any;
  return row ? row.content_hash : null;
}

export function batchContentHashes(entryIds: string[]): Map<string, number> {
  if (entryIds.length === 0) return new Map();
  const result = new Map<string, number>();
  const BATCH_SIZE = 100;
  for (let i = 0; i < entryIds.length; i += BATCH_SIZE) {
    const batch = entryIds.slice(i, i + BATCH_SIZE);
    const placeholders = batch.map(() => "?").join(",");
    const rows = getDB()
      .query(`SELECT entry_id, content_hash FROM chunks WHERE entry_id IN (${placeholders}) GROUP BY entry_id`)
      .all(...batch) as { entry_id: string; content_hash: number }[];
    for (const row of rows) result.set(row.entry_id, row.content_hash);
  }
  return result;
}

export interface ChunkQueryOpts {
  entryType?: string;
  source?: string;
  scope?: string[];
  excludeArchive?: boolean;
  // Multi-agent visibility: when `agentId` is set, return shared/handoff chunks
  // plus that agent's own private chunks (its private context stays isolated from
  // other agents). When unset, private chunks are excluded from general retrieval.
  agentId?: string;
  includeSuperseded?: boolean; // default false — stale/replaced context is hidden
}

// Shared WHERE fragment for visibility + supersession. Returns the SQL conditions
// and their params so both allChunks and chunksWithEmbeddings apply identical rules.
function visibilityConditions(opts?: ChunkQueryOpts): { conditions: string[]; params: any[] } {
  const conditions: string[] = [];
  const params: any[] = [];
  if (!opts?.includeSuperseded) conditions.push("superseded_by IS NULL");
  if (opts?.agentId) {
    conditions.push("(visibility != 'private' OR agent_id = ?)");
    params.push(opts.agentId);
  } else {
    conditions.push("visibility != 'private'");
  }
  return { conditions, params };
}

export function allChunks(opts?: ChunkQueryOpts): VectorChunk[] {
  let sql = "SELECT * FROM chunks";
  const conditions: string[] = [];
  const params: any[] = [];

  if (opts?.entryType) {
    conditions.push("entry_type = ?");
    params.push(opts.entryType);
  }
  if (opts?.source) {
    conditions.push("source = ?");
    params.push(opts.source);
  }
  if (opts?.excludeArchive) {
    conditions.push("source != ?");
    params.push("archive");
  }
  const vis = visibilityConditions(opts);
  conditions.push(...vis.conditions);
  params.push(...vis.params);
  if (conditions.length > 0) sql += ` WHERE ${conditions.join(" AND ")}`;

  const rows = getDB()
    .query(sql)
    .all(...params) as any[];
  let results = rows.map(parseRow);

  if (opts?.scope?.length) {
    results = results.filter((chunk) =>
      opts.scope?.some(
        (s) =>
          chunk.source.toLowerCase().includes(s.toLowerCase()) ||
          chunk.tags.some((t) => t.toLowerCase() === s.toLowerCase()) ||
          chunk.title.toLowerCase().includes(s.toLowerCase())
      )
    );
  }

  return results;
}

export function chunksWithEmbeddings(opts?: ChunkQueryOpts): { chunk: VectorChunk; embedding: number[] }[] {
  let sql = "SELECT * FROM chunks WHERE embedding IS NOT NULL";
  const params: any[] = [];

  if (opts?.entryType) {
    sql += " AND entry_type = ?";
    params.push(opts.entryType);
  }
  if (opts?.excludeArchive) {
    sql += " AND source != ?";
    params.push("archive");
  }
  const vis = visibilityConditions(opts);
  for (const c of vis.conditions) sql += ` AND ${c}`;
  params.push(...vis.params);

  const rows = getDB()
    .query(sql)
    .all(...params) as any[];
  let results = rows
    .map((row) => {
      const chunk = parseRow(row);
      const embedding = chunk.embedding ? Array.from(chunk.embedding).map(Number) : [];
      return { chunk, embedding };
    })
    .filter((r) => r.embedding.length > 0);

  if (opts?.scope?.length) {
    results = results.filter(({ chunk }) =>
      opts.scope?.some(
        (s) =>
          chunk.source.toLowerCase().includes(s.toLowerCase()) ||
          chunk.tags.some((t) => t.toLowerCase() === s.toLowerCase()) ||
          chunk.title.toLowerCase().includes(s.toLowerCase())
      )
    );
  }

  return results;
}

export function chunkCount(entryType?: string): number {
  if (entryType) {
    return (getDB().query("SELECT COUNT(*) as c FROM chunks WHERE entry_type = ?").get(entryType) as any).c;
  }
  return (getDB().query("SELECT COUNT(*) as c FROM chunks").get() as any).c;
}

export function entryCount(entryType?: string): number {
  if (entryType) {
    return (
      getDB().query("SELECT COUNT(DISTINCT entry_id) as c FROM chunks WHERE entry_type = ?").get(entryType) as any
    ).c;
  }
  return (getDB().query("SELECT COUNT(DISTINCT entry_id) as c FROM chunks").get() as any).c;
}

export function chunksForEntryIds(entryIds: string[], entryType?: string): VectorChunk[] {
  if (entryIds.length === 0) return [];
  const BATCH_SIZE = 100;
  const results: VectorChunk[] = [];
  for (let i = 0; i < entryIds.length; i += BATCH_SIZE) {
    const batch = entryIds.slice(i, i + BATCH_SIZE);
    const placeholders = batch.map(() => "?").join(",");
    let sql = `SELECT * FROM chunks WHERE entry_id IN (${placeholders})`;
    const params: (string | number)[] = [...batch];
    if (entryType) {
      sql += " AND entry_type = ?";
      params.push(entryType);
    }
    results.push(
      ...(
        getDB()
          .query(sql)
          .all(...params) as any[]
      ).map(parseRow)
    );
  }
  return results;
}

export function embeddedCount(): number {
  return (getDB().query("SELECT COUNT(DISTINCT entry_id) as c FROM chunks WHERE embedding IS NOT NULL").get() as any).c;
}

// MARK: - Helpers

function allEntryIds(entryType: string): string[] {
  const rows = getDB().query("SELECT DISTINCT entry_id FROM chunks WHERE entry_type = ?").all(entryType) as any[];
  return rows.map((r) => r.entry_id);
}

function parseRow(row: any): VectorChunk {
  let tags: string[] = [];
  try {
    tags = JSON.parse(row.tags);
  } catch {}

  let embedding: Float32Array | null = null;
  if (row.embedding) {
    const buf = row.embedding as Buffer;
    // A truncated/corrupt blob whose length isn't a whole number of floats makes the
    // Float32Array constructor throw, which would break every search rather than just
    // this one chunk. Treat it as un-embedded — the reconciler re-embeds it later.
    if (buf.byteLength > 0 && buf.byteLength % 4 === 0) {
      embedding = new Float32Array(buf.buffer, buf.byteOffset, buf.byteLength / 4);
    }
  }

  return {
    id: row.id,
    entryId: row.entry_id,
    entryType: row.entry_type,
    title: row.title,
    content: row.content,
    tags,
    source: row.source,
    importedAt: new Date(row.imported_at * 1000),
    chunkIndex: row.chunk_index,
    totalChunks: row.total_chunks,
    contentHash: row.content_hash,
    embedding,
    agentId: row.agent_id ?? null,
    sessionId: row.session_id ?? null,
    visibility: (row.visibility ?? "shared") as ChunkVisibility,
    supersededBy: row.superseded_by ?? null,
  };
}

// UTF-8 byte iteration with 32-bit wrapping addition — matches Swift's simpleHash exactly.
export function simpleHash(text: string): number {
  const bytes = new TextEncoder().encode(text);
  let hash = 5381;
  for (const byte of bytes) {
    hash = (Math.imul(hash, 33) + byte) >>> 0;
  }
  return hash;
}

// MARK: - Pending Reindex Queue

export interface PendingReindexRow {
  entryId: string;
  entryType: string;
  operation: "upsert" | "delete";
  queuedAt: number;
  retryCount: number;
}

export function enqueuePendingReindex(
  entryId: string,
  entryType: string,
  operation: "upsert" | "delete" = "upsert"
): void {
  getDB().run(
    `INSERT INTO pending_reindex (entry_id, entry_type, operation, queued_at, retry_count)
     VALUES (?, ?, ?, ?, 0)
     ON CONFLICT(entry_id) DO UPDATE SET
       entry_type = excluded.entry_type,
       operation  = excluded.operation,
       queued_at  = excluded.queued_at`,
    [entryId, entryType, operation, Date.now()]
  );
}

export function deleteExhaustedPendingReindex(maxRetries = 3): void {
  getDB().run("DELETE FROM pending_reindex WHERE retry_count >= ?", [maxRetries]);
}

export function getPendingReindex(maxRetries = 3): PendingReindexRow[] {
  const rows = getDB()
    .query(
      "SELECT entry_id, entry_type, operation, queued_at, retry_count FROM pending_reindex WHERE retry_count < ? ORDER BY queued_at ASC"
    )
    .all(maxRetries) as any[];
  return rows.map((r) => ({
    entryId: r.entry_id,
    entryType: r.entry_type,
    operation: r.operation as "upsert" | "delete",
    queuedAt: r.queued_at,
    retryCount: r.retry_count,
  }));
}

export function deletePendingReindex(entryId: string): void {
  getDB().run("DELETE FROM pending_reindex WHERE entry_id = ?", [entryId]);
}

export function incrementPendingRetry(entryId: string): void {
  getDB().run("UPDATE pending_reindex SET retry_count = retry_count + 1 WHERE entry_id = ?", [entryId]);
}

// MARK: - Semantic Chunker

const MAX_CHUNK_SIZE = 500;
const MIN_CHUNK_SIZE = 100;

export interface ChunkMeta {
  agentId?: string | null;
  sessionId?: string | null;
  visibility?: ChunkVisibility;
  supersededBy?: string | null;
}

export function semanticChunk(
  text: string,
  entryId: string,
  entryType: string,
  title: string,
  tags: string[],
  source: string,
  importedAt: Date,
  hash: number,
  meta: ChunkMeta = {}
): VectorChunk[] {
  const provenance = {
    agentId: meta.agentId ?? null,
    sessionId: meta.sessionId ?? null,
    visibility: meta.visibility ?? "shared",
    supersededBy: meta.supersededBy ?? null,
  };
  const sentences = splitSentences(text);
  if (sentences.length === 0) {
    return [
      {
        id: `${entryId}:0`,
        entryId,
        entryType,
        title,
        content: text,
        tags,
        source,
        importedAt,
        chunkIndex: 0,
        totalChunks: 1,
        contentHash: hash,
        embedding: null,
        ...provenance,
      },
    ];
  }

  const groups: string[][] = [];
  let current: string[] = [];
  let currentLen = 0;

  for (const sentence of sentences) {
    if (currentLen + sentence.length > MAX_CHUNK_SIZE && current.length > 0) {
      groups.push(current);
      const last = current[current.length - 1];
      current = last.length < MAX_CHUNK_SIZE / 2 ? [last] : [];
      currentLen = current.reduce((s, c) => s + c.length, 0);
    }
    current.push(sentence);
    currentLen += sentence.length;
  }

  if (current.length > 0) {
    if (currentLen < MIN_CHUNK_SIZE && groups.length > 0) {
      groups[groups.length - 1].push(...current);
    } else {
      groups.push(current);
    }
  }

  const totalChunks = groups.length;
  return groups.map((group, index) => ({
    id: `${entryId}:${index}`,
    entryId,
    entryType,
    title,
    content: group.join(" "),
    tags,
    source,
    importedAt,
    chunkIndex: index,
    totalChunks,
    contentHash: hash,
    embedding: null,
    ...provenance,
  }));
}

function splitSentences(text: string): string[] {
  const sentences = text.match(/[^.!?\n]+[.!?\n]+|[^.!?\n]+$/g);
  if (!sentences) {
    return text
      .split("\n")
      .map((s) => s.trim())
      .filter(Boolean);
  }
  return sentences.map((s) => s.trim()).filter((s) => s.length > 0);
}

// MARK: - Supersession (Phase 3)

// Mark every chunk of `oldEntryId` as superseded by `newEntryId`. Superseded chunks
// are hidden from retrieval by default (see visibilityConditions) but retained so the
// history stays auditable and can be surfaced explicitly.
export function supersedeEntry(oldEntryId: string, newEntryId: string): number {
  const res = getDB().run("UPDATE chunks SET superseded_by = ? WHERE entry_id = ? AND superseded_by IS NULL", [
    newEntryId,
    oldEntryId,
  ]);
  return Number(res.changes ?? 0);
}

export function clearSupersession(entryId: string): void {
  getDB().run("UPDATE chunks SET superseded_by = NULL WHERE entry_id = ?", [entryId]);
}

export function supersededByOf(entryId: string): string | null {
  const row = getDB()
    .query("SELECT superseded_by FROM chunks WHERE entry_id = ? AND superseded_by IS NOT NULL LIMIT 1")
    .get(entryId) as { superseded_by?: string } | undefined;
  return row?.superseded_by ?? null;
}

// MARK: - Links Graph (Phase 4)

export interface Link {
  fromType: string;
  fromId: string;
  toType: string;
  toId: string;
  relation: string;
  createdAt: number;
}

export function addLink(fromType: string, fromId: string, toType: string, toId: string, relation = "related"): void {
  getDB().run(
    `INSERT INTO links (from_type, from_id, to_type, to_id, relation, created_at)
     VALUES (?, ?, ?, ?, ?, ?)
     ON CONFLICT(from_type, from_id, to_type, to_id, relation) DO NOTHING`,
    [fromType, fromId, toType, toId, relation, Date.now()]
  );
}

// All edges touching an entity, in either direction. Handy for "show me everything
// connected to this task/note/session".
export function linksFor(type: string, id: string): { outgoing: Link[]; incoming: Link[] } {
  const db = getDB();
  const map = (r: any): Link => ({
    fromType: r.from_type,
    fromId: r.from_id,
    toType: r.to_type,
    toId: r.to_id,
    relation: r.relation,
    createdAt: r.created_at,
  });
  const outgoing = (db.query("SELECT * FROM links WHERE from_type = ? AND from_id = ?").all(type, id) as any[]).map(
    map
  );
  const incoming = (db.query("SELECT * FROM links WHERE to_type = ? AND to_id = ?").all(type, id) as any[]).map(map);
  return { outgoing, incoming };
}

export function removeLink(fromType: string, fromId: string, toType: string, toId: string, relation = "related"): void {
  getDB().run("DELETE FROM links WHERE from_type = ? AND from_id = ? AND to_type = ? AND to_id = ? AND relation = ?", [
    fromType,
    fromId,
    toType,
    toId,
    relation,
  ]);
}

export function deleteLinksForEntity(type: string, id: string): void {
  getDB().run("DELETE FROM links WHERE (from_type = ? AND from_id = ?) OR (to_type = ? AND to_id = ?)", [
    type,
    id,
    type,
    id,
  ]);
}

// MARK: - Cross-entry Near-Duplicate Detection (Phase 3)

// Pairwise cosine over the best embedding per entry. O(n²) but n is the entry count
// (hundreds, not chunks), and it only runs during maintenance passes. Returns pairs
// above `threshold`, newest entry first so callers can supersede the older duplicate.
export function findNearDuplicates(
  threshold = 0.92,
  opts?: { entryType?: string }
): { keep: string; duplicate: string; similarity: number }[] {
  const rows = chunksWithEmbeddings({ entryType: opts?.entryType, excludeArchive: true });
  // Best embedding + newest timestamp per entry.
  const byEntry = new Map<string, { embedding: number[]; importedAt: number }>();
  for (const { chunk, embedding } of rows) {
    const prev = byEntry.get(chunk.entryId);
    if (!prev) byEntry.set(chunk.entryId, { embedding, importedAt: chunk.importedAt.getTime() });
  }

  const entries = [...byEntry.entries()];
  const out: { keep: string; duplicate: string; similarity: number }[] = [];
  for (let i = 0; i < entries.length; i++) {
    for (let j = i + 1; j < entries.length; j++) {
      const a = entries[i][1];
      const b = entries[j][1];
      const sim = cosine(a.embedding, b.embedding);
      if (sim >= threshold) {
        // Keep the newer entry, flag the older as the duplicate.
        const [newer, older] =
          a.importedAt >= b.importedAt ? [entries[i][0], entries[j][0]] : [entries[j][0], entries[i][0]];
        out.push({ keep: newer, duplicate: older, similarity: Math.round(sim * 1000) / 1000 });
      }
    }
  }
  return out;
}

function cosine(a: number[], b: number[]): number {
  if (a.length !== b.length || a.length === 0) return 0;
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  const denom = Math.sqrt(na) * Math.sqrt(nb);
  return denom > 0 ? dot / denom : 0;
}

// MARK: - Meta key/value

export function getMeta(key: string): string | null {
  const row = getDB().query("SELECT value FROM meta WHERE key = ?").get(key) as { value?: string } | undefined;
  return row?.value ?? null;
}

export function setMeta(key: string, value: string): void {
  getDB().run("INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", [
    key,
    value,
  ]);
}
