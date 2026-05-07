import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DEEPTHINK_ROOT } from "../config";

const MEMORY_DIR = join(DEEPTHINK_ROOT, "data", "agent-memory");

export interface AgentMemory {
  agentId: string;
  created: string;
  updated: string;
  observations: string[];
  corrections: string[];
  facts: Record<string, string>;
  interactionCount: number;
}

function memPath(agentId: string): string {
  return join(MEMORY_DIR, `${agentId}.json`);
}

const empty = (agentId: string): AgentMemory => ({
  agentId,
  created: new Date().toISOString(),
  updated: new Date().toISOString(),
  observations: [],
  corrections: [],
  facts: {},
  interactionCount: 0,
});

export function loadMemory(agentId: string): AgentMemory {
  mkdirSync(MEMORY_DIR, { recursive: true });
  const path = memPath(agentId);
  if (!existsSync(path)) return empty(agentId);
  try {
    return JSON.parse(readFileSync(path, "utf-8"));
  } catch {
    return empty(agentId);
  }
}

export function saveMemory(memory: AgentMemory): void {
  mkdirSync(MEMORY_DIR, { recursive: true });
  memory.updated = new Date().toISOString();
  writeFileSync(memPath(memory.agentId), JSON.stringify(memory, null, 2));
}

export function appendObservation(agentId: string, text: string): void {
  const mem = loadMemory(agentId);
  mem.observations = [text, ...mem.observations].slice(0, 20);
  mem.interactionCount++;
  saveMemory(mem);
}

export function appendCorrection(agentId: string, text: string): void {
  const mem = loadMemory(agentId);
  mem.corrections = [text, ...mem.corrections].slice(0, 10);
  saveMemory(mem);
}

export function setFact(agentId: string, key: string, value: string): void {
  const mem = loadMemory(agentId);
  mem.facts[key] = value;
  saveMemory(mem);
}

export function buildMemoryContext(agentId: string): string {
  const mem = loadMemory(agentId);
  const hasContent = mem.observations.length > 0 || mem.corrections.length > 0 || Object.keys(mem.facts).length > 0;
  if (!hasContent) return "";

  const lines: string[] = ["## Agent Memory\n"];
  if (Object.keys(mem.facts).length > 0) {
    lines.push("**Known facts:**");
    for (const [k, v] of Object.entries(mem.facts)) lines.push(`- ${k}: ${v}`);
    lines.push("");
  }
  if (mem.corrections.length > 0) {
    lines.push("**Past corrections (follow these):**");
    for (const c of mem.corrections.slice(0, 5)) lines.push(`- ${c}`);
    lines.push("");
  }
  if (mem.observations.length > 0) {
    lines.push("**Recent observations:**");
    for (const o of mem.observations.slice(0, 5)) lines.push(`- ${o}`);
    lines.push("");
  }
  return lines.join("\n");
}

export function listAllMemories(): { agentId: string; interactions: number; updated: string }[] {
  mkdirSync(MEMORY_DIR, { recursive: true });
  const { readdirSync } = require("node:fs");
  return readdirSync(MEMORY_DIR)
    .filter((f: string) => f.endsWith(".json"))
    .map((f: string) => {
      try {
        const m: AgentMemory = JSON.parse(readFileSync(join(MEMORY_DIR, f), "utf-8"));
        return { agentId: m.agentId, interactions: m.interactionCount, updated: m.updated };
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}
