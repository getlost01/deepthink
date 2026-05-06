import { homedir } from "os";
import { join } from "path";

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
