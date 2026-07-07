import { homedir } from "node:os";
import { join } from "node:path";

export const HOME = homedir();
export const DEEPTHINK_ROOT = join(HOME, "DeepThink");
export const SANDBOX_ROOT = join(DEEPTHINK_ROOT, "sandbox");
export const MEMORY_DIR = join(DEEPTHINK_ROOT, "memory");
export const LOGS_DIR = join(DEEPTHINK_ROOT, "logs");
export const KNOWLEDGE_DIR = join(DEEPTHINK_ROOT, "knowledge");

export const SANDBOX_DIRS = {
  docs: join(SANDBOX_ROOT, "docs"),
  outputs: join(SANDBOX_ROOT, "outputs"),
  analysis: join(SANDBOX_ROOT, "analysis"),
  insights: join(SANDBOX_ROOT, "insights"),
} as const;

export const KNOWLEDGE_DIRS = {
  projects: join(KNOWLEDGE_DIR, "projects"),
  integrations: join(KNOWLEDGE_DIR, "integrations"),
  archive: join(KNOWLEDGE_DIR, "archive"),
} as const;

export const DEFAULT_MODEL = "claude-sonnet-4-6";

// Multi-agent identity. Any agent (Claude Code, Cursor, Codex, …) identifies itself
// by exporting DEEPTHINK_AGENT_ID; the MCP server process inherits it, so every
// capture is stamped with who wrote it. Falls back to "default" so single-agent
// setups behave exactly as before.
export function currentAgentId(explicit?: string): string {
  const id = (explicit ?? process.env.DEEPTHINK_AGENT_ID ?? process.env.DEEPTHINK_AGENT ?? "").trim();
  return id || "default";
}

// Best-effort session identity for grouping a run's captures. Claude Code exports
// CLAUDE_SESSION_ID; other agents can set DEEPTHINK_SESSION_ID.
export function currentSessionId(explicit?: string): string | undefined {
  return explicit ?? process.env.DEEPTHINK_SESSION_ID ?? process.env.CLAUDE_SESSION_ID ?? undefined;
}
