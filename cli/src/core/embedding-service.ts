import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join } from "path";
import { execSync, execFileSync } from "child_process";
import { DEEPTHINK_ROOT } from "../config";

const DATA_DIR = join(DEEPTHINK_ROOT, "data");
const EMBEDDINGS_PATH = join(DATA_DIR, "embeddings.json");
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

interface EmbeddingEntry {
  id: string;
  v: string;
}

let cachedEmbeddings: Map<string, number[]> | null = null;
let cachedMtime: number = 0;

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

function loadEmbeddings(): Map<string, number[]> {
  if (!existsSync(EMBEDDINGS_PATH)) return new Map();

  try {
    const stat = Bun.file(EMBEDDINGS_PATH);
    const mtime = stat.lastModified;

    if (cachedEmbeddings && mtime === cachedMtime) return cachedEmbeddings;

    const raw = readFileSync(EMBEDDINGS_PATH, "utf-8");
    const pairs: EmbeddingEntry[] = JSON.parse(raw);
    const map = new Map<string, number[]>();

    for (const pair of pairs) {
      if (!pair.id || !pair.v) continue;
      const values = pair.v.split(",").map(Number);
      if (values.length > 0 && !values.some(isNaN)) {
        map.set(pair.id, values);
      }
    }

    cachedEmbeddings = map;
    cachedMtime = mtime;
    return map;
  } catch {
    return new Map();
  }
}

function embedQuery(text: string): number[] | null {
  if (!ensureHelper()) return null;

  try {
    const result = execFileSync(HELPER_BIN, [text], {
      timeout: 5000,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    const values = result.trim().split(",").map(Number);
    if (values.length > 0 && !values.some(isNaN)) return values;
    return null;
  } catch {
    return null;
  }
}

function cosineSimilarity(a: number[], b: number[]): number {
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

export interface SemanticResult {
  entryID: string;
  score: number;
}

export function semanticSearch(
  query: string,
  topK: number = 10,
  scope?: string[]
): SemanticResult[] {
  const embeddings = loadEmbeddings();
  if (embeddings.size === 0) return [];

  const queryVector = embedQuery(query);
  if (!queryVector) return [];

  const results: SemanticResult[] = [];

  for (const [entryID, vector] of embeddings) {
    if (scope?.length) {
      const matches = scope.some((s) => entryID.toLowerCase().includes(s.toLowerCase()));
      if (!matches) continue;
    }

    const similarity = cosineSimilarity(queryVector, vector);
    if (similarity > 0.3) {
      results.push({ entryID, score: similarity });
    }
  }

  return results
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
}

export function embeddingStats(): { indexed: number; available: boolean } {
  const embeddings = loadEmbeddings();
  const available = ensureHelper();
  return { indexed: embeddings.size, available };
}
