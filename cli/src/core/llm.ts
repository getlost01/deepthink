import { execSync } from "child_process";
import { homedir } from "os";
import { existsSync } from "fs";

let claudePath: string | null = null;

function findClaude(): string {
  if (claudePath) return claudePath;

  const candidates = [
    `${homedir()}/.local/bin/claude`,
    "/usr/local/bin/claude",
    "/opt/homebrew/bin/claude",
  ];

  for (const p of candidates) {
    if (existsSync(p)) {
      claudePath = p;
      return p;
    }
  }

  throw new Error("Claude CLI not found. Install from https://claude.ai/code");
}

interface CLIResponse {
  type?: string;
  result?: string;
  is_error?: boolean;
  duration_ms?: number;
  total_cost_usd?: number;
}

export async function query(
  prompt: string,
  system: string = "",
  model: string = "claude-sonnet-4-6"
): Promise<string> {
  const claude = findClaude();

  const args = [
    "-p", prompt,
    "--output-format", "json",
    "--no-session-persistence",
    "--dangerously-skip-permissions",
    "--model", model,
  ];

  if (system) {
    args.push("--append-system-prompt", system);
  }

  const escaped = args
    .map((a) => `'${a.replace(/'/g, "'\\''")}'`)
    .join(" ");

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
  try {
    findClaude();
    return true;
  } catch {
    return false;
  }
}
