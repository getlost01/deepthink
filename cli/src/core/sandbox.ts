import { mkdirSync, readdirSync, existsSync } from "fs";
import { join } from "path";
import { SANDBOX_ROOT, SANDBOX_DIRS, KNOWLEDGE_DIRS, LOGS_DIR } from "../config";

export function initSandbox(): void {
  const dirs = [
    ...Object.values(SANDBOX_DIRS),
    ...Object.values(KNOWLEDGE_DIRS),
    LOGS_DIR,
    join(KNOWLEDGE_DIRS.integrations, "slack"),
    join(KNOWLEDGE_DIRS.integrations, "github"),
    join(KNOWLEDGE_DIRS.integrations, "linear"),
    join(KNOWLEDGE_DIRS.integrations, "web"),
  ];
  for (const d of dirs) {
    mkdirSync(d, { recursive: true });
  }
}

export function getPath(category: keyof typeof SANDBOX_DIRS, filename: string): string {
  return join(SANDBOX_DIRS[category], filename);
}

export function listFiles(category?: keyof typeof SANDBOX_DIRS): string[] {
  const base = category ? SANDBOX_DIRS[category] : SANDBOX_ROOT;
  if (!existsSync(base)) return [];
  try {
    return readdirSync(base).map((f) => join(base, f));
  } catch {
    return [];
  }
}

initSandbox();
