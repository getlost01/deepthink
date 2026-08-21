import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { KNOWLEDGE_DIR } from "../config";

// A handoff is an explicit "here's where I left off" record one agent writes for
// the next. Unlike a plain note it has lifecycle: open → claimed. Kept in a small
// JSON registry so listing/claiming is O(1) and doesn't require rewriting markdown
// frontmatter. The human-readable content is ALSO saved as a session-note (visibility
// "handoff") so it still surfaces in normal retrieval.

export type HandoffStatus = "open" | "claimed";

export interface Handoff {
  id: string;
  bucket: string;
  fromAgent: string;
  toAgent?: string; // optional target; open handoffs with no target can be claimed by anyone
  title: string;
  content: string;
  status: HandoffStatus;
  createdAt: string;
  claimedBy?: string;
  claimedAt?: string;
  notePath?: string; // relative entryId of the backing session-note, for retrieval
}

const REGISTRY = join(KNOWLEDGE_DIR, "handoffs.json");

function load(): Record<string, Handoff> {
  if (!existsSync(REGISTRY)) return {};
  try {
    return JSON.parse(readFileSync(REGISTRY, "utf-8")) as Record<string, Handoff>;
  } catch {
    return {};
  }
}

function save(reg: Record<string, Handoff>): void {
  mkdirSync(KNOWLEDGE_DIR, { recursive: true });
  const tmp = `${REGISTRY}.tmp-${process.pid}-${Date.now()}`;
  writeFileSync(tmp, JSON.stringify(reg, null, 2), "utf-8");
  renameSync(tmp, REGISTRY);
}

export function create(h: Omit<Handoff, "id" | "createdAt" | "status">): Handoff {
  const reg = load();
  const id = `${h.bucket}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 6)}`;
  const handoff: Handoff = { ...h, id, status: "open", createdAt: new Date().toISOString() };
  reg[id] = handoff;
  save(reg);
  return handoff;
}

// Open handoffs for a bucket, newest first. Optionally restrict to those addressed to
// `agent` (or unaddressed, claimable by anyone).
export function open(bucket: string, agent?: string): Handoff[] {
  return Object.values(load())
    .filter((h) => h.bucket === bucket && h.status === "open")
    .filter((h) => !agent || !h.toAgent || h.toAgent === agent)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

export function get(id: string): Handoff | undefined {
  return load()[id];
}

// Claim a handoff so two agents don't both pick up the same baton. Returns the updated
// record, or throws if it's missing or already claimed by someone else.
export function claim(id: string, agent: string): Handoff {
  const reg = load();
  const h = reg[id];
  if (!h) throw new Error(`handoff not found: ${id}`);
  if (h.status === "claimed" && h.claimedBy !== agent) {
    throw new Error(`handoff ${id} already claimed by ${h.claimedBy}`);
  }
  h.status = "claimed";
  h.claimedBy = agent;
  h.claimedAt = new Date().toISOString();
  reg[id] = h;
  save(reg);
  return h;
}
