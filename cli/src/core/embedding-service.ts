import { existsSync, mkdirSync, writeFileSync } from "fs";
import { join } from "path";
import { execSync, execFileSync } from "child_process";
import { DEEPTHINK_ROOT } from "../config";
import {
  type VectorChunk,
  chunksWithEmbeddings,
  upsertChunks,
  deleteChunksForEntry,
  contentHash as getContentHash,
  pruneStaleEntries,
  embeddedCount,
  simpleHash,
  semanticChunk,
} from "./vector-store";

const CACHE_DIR = join(DEEPTHINK_ROOT, ".cache");
const HELPER_BIN = join(CACHE_DIR, "embed-helper");
const HELPER_SRC = join(CACHE_DIR, "embed-helper.swift");

const SWIFT_SOURCE = `import NaturalLanguage
import Foundation

guard CommandLine.arguments.count > 1 else {
    fputs("usage: embed-helper <text>\\n", stderr)
    exit(1)
}
let text = CommandLine.arguments.dropFirst().joined(separator: " ")
guard let embedding = NLEmbedding.sentenceEmbedding(for: .english),
      let vector = embedding.vector(for: text) else {
    fputs("error: NLEmbedding unavailable\\n", stderr)
    exit(1)
}
print(vector.map { String($0) }.joined(separator: ","))
`;

function ensureHelper(): boolean {
  if (existsSync(HELPER_BIN)) return true;
  try {
    if (!existsSync(CACHE_DIR)) mkdirSync(CACHE_DIR, { recursive: true });
    writeFileSync(HELPER_SRC, SWIFT_SOURCE);
    execSync(`swiftc -O -o '${HELPER_BIN}' '${HELPER_SRC}'`, {
      timeout: 30000,
      stdio: ["pipe", "pipe", "pipe"],
    });
    return true;
  } catch {
    return false;
  }
}

function embedQuery(text: string): Float32Array | null {
  if (!ensureHelper()) return null;
  try {
    const result = execFileSync(HELPER_BIN, [text], {
      timeout: 5000,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    const values = result.trim().split(",").map(Number);
    if (values.length > 0 && !values.some(isNaN)) return new Float32Array(values);
    return null;
  } catch {
    return null;
  }
}

function cosineSimilarity(a: number[] | Float32Array, b: number[] | Float32Array): number {
  if (a.length !== b.length || a.length === 0) return 0;
  let dot = 0, normA = 0, normB = 0;
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

export function indexEntry(entry: IndexableEntry): void {
  const hash = simpleHash(entry.content);
  const existing = getContentHash(entry.id);
  if (existing !== null && existing === hash) return;

  const chunks = semanticChunk(
    entry.content, entry.id, entry.type, entry.title,
    entry.tags, entry.source, entry.importedAt, hash
  );

  const withEmbeddings = chunks.map(chunk => {
    const text = `${entry.title}. ${chunk.content.slice(0, 500)}`;
    const embedding = embedQuery(text);
    return { ...chunk, embedding };
  });

  deleteChunksForEntry(entry.id);
  upsertChunks(withEmbeddings);
}

export function indexEntries(entries: IndexableEntry[]): void {
  for (const entry of entries) {
    indexEntry(entry);
  }
  const validIds = new Set(entries.map(e => e.id));
  pruneStaleEntries(validIds, entries[0]?.type ?? "knowledge");
}

export function removeEntry(entryId: string): void {
  deleteChunksForEntry(entryId);
}

// MARK: - Search

export interface SemanticResult {
  entryID: string;
  score: number;
}

export function semanticSearch(
  query: string,
  topK: number = 10,
  scope?: string[]
): SemanticResult[] {
  const queryVector = embedQuery(query);
  if (!queryVector) return [];

  const entries = chunksWithEmbeddings({ scope });
  const seen = new Set<string>();
  const results: SemanticResult[] = [];

  for (const { chunk, embedding } of entries) {
    const similarity = cosineSimilarity(queryVector, embedding);
    if (similarity > 0.3 && !seen.has(chunk.entryId)) {
      results.push({ entryID: chunk.entryId, score: similarity });
      seen.add(chunk.entryId);
    }
  }

  return results
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
}

export function embeddingStats(): { indexed: number; available: boolean } {
  const available = ensureHelper();
  return { indexed: embeddedCount(), available };
}
