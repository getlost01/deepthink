import { homedir } from "os";
import { join } from "path";

export const HOME = homedir();
export const DEEPTHINK_ROOT = join(HOME, "deepthink");
export const SANDBOX_ROOT = join(DEEPTHINK_ROOT, "sandbox");
export const MEMORY_DIR = join(DEEPTHINK_ROOT, "memory");
export const LOGS_DIR = join(DEEPTHINK_ROOT, "logs");

export const SANDBOX_DIRS = {
  docs: join(SANDBOX_ROOT, "docs"),
  outputs: join(SANDBOX_ROOT, "outputs"),
  projects: join(SANDBOX_ROOT, "projects"),
  insights: join(SANDBOX_ROOT, "insights"),
} as const;

export const DEFAULT_MODEL = "claude-sonnet-4-6";
export const MAX_TOKENS = 4096;
