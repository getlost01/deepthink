import { MemoryManager } from "../memory/manager";

let mgr: MemoryManager | null = null;

function getMgr(): MemoryManager {
  if (!mgr) mgr = new MemoryManager();
  return mgr;
}

export function saveMemory(content: string, tags: string[] = [], layer: "short" | "long" = "short"): string {
  return getMgr().save(content, tags, layer);
}

export function loadMemory(query?: string, layer?: "short" | "long", limit = 10): any[] {
  return getMgr().search(query, layer, limit);
}

export function recall(q: string): string {
  return getMgr().recall(q);
}

export function recallJSON(q: string): { entries: any[] } {
  return getMgr().recallJSON(q);
}

export function memoryStats(): { shortTerm: number; longTerm: number } {
  return getMgr().stats();
}

export function promoteMemory(entryId: string): boolean {
  return getMgr().promote(entryId);
}

export function clearShortTerm(): void {
  getMgr().clearShortTerm();
}
