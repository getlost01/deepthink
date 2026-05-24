import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";

let claudePath: string | null = null;

export const CLAUDE_SEARCH_PATHS = [
  `${homedir()}/.local/bin/claude`,
  "/usr/local/bin/claude",
  "/opt/homebrew/bin/claude",
] as const;

export function findClaudePath(): { path: string | null; searched: string[] } {
  if (claudePath) return { path: claudePath, searched: [...CLAUDE_SEARCH_PATHS] };

  for (const p of CLAUDE_SEARCH_PATHS) {
    if (existsSync(p)) {
      claudePath = p;
      return { path: p, searched: [...CLAUDE_SEARCH_PATHS] };
    }
  }

  return { path: null, searched: [...CLAUDE_SEARCH_PATHS] };
}

function findClaude(): string {
  const { path } = findClaudePath();
  if (path) return path;
  throw new Error("Claude CLI not found. Install from https://claude.ai/code");
}

interface CLIResponse {
  type?: string;
  result?: string;
  is_error?: boolean;
  duration_ms?: number;
  total_cost_usd?: number;
}

export async function query(prompt: string, system: string = "", model: string = "claude-sonnet-4-6"): Promise<string> {
  const claude = findClaude();

  const args = [
    "-p",
    prompt,
    "--output-format",
    "json",
    "--no-session-persistence",
    "--dangerously-skip-permissions",
    "--model",
    model,
  ];

  if (system) {
    args.push("--append-system-prompt", system);
  }

  const escaped = args.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");

  const result = execSync(`${claude} ${escaped}`, {
    encoding: "utf-8",
    timeout: 120_000,
    maxBuffer: 10 * 1024 * 1024,
    env: {
      ...process.env,
      HOME: homedir(),
      PATH: `${homedir()}/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:${process.env.PATH ?? ""}`,
    },
  });

  try {
    const parsed: CLIResponse = JSON.parse(result);
    if (parsed.result) return parsed.result;
    return result.trim();
  } catch {
    return result.trim();
  }
}

export async function querySafe(
  prompt: string,
  system: string = ""
): Promise<{ ok: true; text: string } | { ok: false; error: string }> {
  try {
    const text = await query(prompt, system);
    return { ok: true, text };
  } catch (e: any) {
    return { ok: false, error: e.message ?? String(e) };
  }
}

export function isClaudeAvailable(): boolean {
  return findClaudePath().path !== null;
}
