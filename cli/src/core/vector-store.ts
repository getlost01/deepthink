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
      embedding BLOB
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

  return _db;
}

// MARK: - Types

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
}

// MARK: - CRUD

const upsertSQL = `
  INSERT OR REPLACE INTO chunks
  (id, entry_id, entry_type, title, content, tags, source, imported_at, chunk_index, total_chunks, content_hash, embedding)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
`;

export function upsertChunk(chunk: VectorChunk): void {
  const db = getDB();
  db.run(
    upsertSQL,
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
    chunk.embedding ? Buffer.from(chunk.embedding.buffer) : null
  );
}

export function upsertChunks(chunks: VectorChunk[]): void {
  const db = getDB();
  const stmt = db.prepare(upsertSQL);
  const tx = db.transaction(() => {
    for (const chunk of chunks) {
      stmt.run(
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
        chunk.embedding ? Buffer.from(chunk.embedding.buffer) : null
      );
    }
  });
  tx();
}

export function deleteChunksForEntry(entryId: string): void {
  getDB().run("DELETE FROM chunks WHERE entry_id = ?", [entryId]);
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

export function allChunks(opts?: { entryType?: string; source?: string; scope?: string[] }): VectorChunk[] {
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

export function chunksWithEmbeddings(opts?: {
  entryType?: string;
  scope?: string[];
}): { chunk: VectorChunk; embedding: number[] }[] {
  let sql = "SELECT * FROM chunks WHERE embedding IS NOT NULL";
  const params: any[] = [];

  if (opts?.entryType) {
    sql += " AND entry_type = ?";
    params.push(opts.entryType);
  }

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
  let sql = "SELECT COUNT(*) as c FROM chunks";
  if (entryType) sql += ` WHERE entry_type = '${entryType}'`;
  return (getDB().query(sql).get() as any).c;
}

export function entryCount(entryType?: string): number {
  let sql = "SELECT COUNT(DISTINCT entry_id) as c FROM chunks";
  if (entryType) sql += ` WHERE entry_type = '${entryType}'`;
  return (getDB().query(sql).get() as any).c;
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
    embedding = new Float32Array(buf.buffer, buf.byteOffset, buf.byteLength / 4);
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
  };
}

export function simpleHash(text: string): number {
  let hash = 5381;
  const slice = text.slice(0, 2000);
  for (let i = 0; i < slice.length; i++) {
    hash = ((hash * 33) ^ slice.charCodeAt(i)) >>> 0;
  }
  return hash;
}

// MARK: - Semantic Chunker

const MAX_CHUNK_SIZE = 500;
const MIN_CHUNK_SIZE = 100;

export function semanticChunk(
  text: string,
  entryId: string,
  entryType: string,
  title: string,
  tags: string[],
  source: string,
  importedAt: Date,
  hash: number
): VectorChunk[] {
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
