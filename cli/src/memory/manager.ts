import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join } from "path";
import { randomUUID } from "crypto";
import { MEMORY_DIR } from "../config";

interface MemoryEntry {
  id: string;
  content: string;
  tags: string[];
  timestamp: string;
  layer: "short" | "long";
  promotedAt?: string;
}

export class MemoryManager {
  private shortFile: string;
  private longFile: string;

  constructor() {
    mkdirSync(MEMORY_DIR, { recursive: true });
    this.shortFile = join(MEMORY_DIR, "short_term.json");
    this.longFile = join(MEMORY_DIR, "long_term.json");
    this.ensureFiles();
  }

  private ensureFiles(): void {
    for (const f of [this.shortFile, this.longFile]) {
      if (!existsSync(f)) writeFileSync(f, "[]", "utf-8");
    }
  }

  private load(layer: "short" | "long"): MemoryEntry[] {
    const f = layer === "short" ? this.shortFile : this.longFile;
    return JSON.parse(readFileSync(f, "utf-8"));
  }

  private persist(layer: "short" | "long", entries: MemoryEntry[]): void {
    const f = layer === "short" ? this.shortFile : this.longFile;
    writeFileSync(f, JSON.stringify(entries, null, 2), "utf-8");
  }

  save(content: string, tags: string[] = [], layer: "short" | "long" = "short"): string {
    const entries = this.load(layer);
    const id = randomUUID().slice(0, 8);
    entries.push({
      id,
      content,
      tags,
      timestamp: new Date().toISOString(),
      layer,
    });

    if (layer === "short" && entries.length > 100) {
      entries.splice(0, entries.length - 100);
    }

    this.persist(layer, entries);
    return id;
  }

  search(query?: string, layer?: "short" | "long", limit = 10): MemoryEntry[] {
    const layers: ("short" | "long")[] = layer ? [layer] : ["short", "long"];
    let results: MemoryEntry[] = [];

    for (const l of layers) {
      let entries = this.load(l);
      if (query) {
        const q = query.toLowerCase();
        entries = entries.filter(
          (e) =>
            e.content.toLowerCase().includes(q) ||
            e.tags.some((t) => t.toLowerCase().includes(q))
        );
      }
      results.push(...entries);
    }

    results.sort((a, b) => b.timestamp.localeCompare(a.timestamp));
    return results.slice(0, limit);
  }

  recall(query: string): string {
    const results = this.search(query || undefined, undefined, 10);
    if (results.length === 0) return "No memories found.";

    return results
      .map((r) => {
        const ts = r.timestamp.slice(0, 16);
        const tags = r.tags.length > 0 ? r.tags.join(", ") : "none";
        return `[${ts}] (${r.layer}, tags: ${tags}) ${r.content.slice(0, 200)}`;
      })
      .join("\n");
  }

  recallJSON(query: string): { entries: MemoryEntry[] } {
    const results = this.search(query || undefined, undefined, 10);
    return { entries: results };
  }

  statsJSON(): { shortTerm: number; longTerm: number } {
    return this.stats();
  }

  promote(entryId: string): boolean {
    const short = this.load("short");
    const idx = short.findIndex((e) => e.id === entryId);
    if (idx === -1) return false;

    const [target] = short.splice(idx, 1);
    target.layer = "long";
    target.promotedAt = new Date().toISOString();
    this.persist("short", short);

    const long = this.load("long");
    long.push(target);
    this.persist("long", long);
    return true;
  }

  clearShortTerm(): void {
    this.persist("short", []);
  }

  stats(): { shortTerm: number; longTerm: number } {
    return {
      shortTerm: this.load("short").length,
      longTerm: this.load("long").length,
    };
  }
}
