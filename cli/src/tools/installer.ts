import { execFileSync } from "node:child_process";
import {
  appendFileSync,
  chmodSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { SKILLS } from "../skills";

const HOME = homedir();
const USER_BIN = join(HOME, ".local", "bin");

// Substrings that identify a hook command as ours, so install/uninstall can find and
// replace our entries without disturbing the user's other hooks. Must be quote-
// independent — the binary path is quoted in the command (`"…/deepthink" session
// recall`), so a marker spanning the closing quote never matches. Match the unique
// subcommand tails instead.
const HOOK_MARKERS = ["session recall --quiet", "session autosync"];

function isOurHookCommand(command: unknown): boolean {
  return typeof command === "string" && HOOK_MARKERS.some((m) => command.includes(m));
}

// ── Public types ──

export type Scope = "global" | "local";
export type Capability = "commands" | "mcp" | "hooks";

export interface InstallStep {
  step: string;
  status: "done" | "skipped" | "failed";
  detail?: string;
}

export interface InstallOptions {
  /** Host ids to target (claude-code | claude-desktop | cursor | codex). Defaults to ["claude-code"]. */
  agents?: string[];
  /** Config scope. "global" → user home; "local" → the project at cwd. Default "global". */
  scope?: Scope;
  cwd?: string;
  // Back-compat flags (claude-code only): restrict which capabilities run.
  global?: boolean;
  skillsOnly?: boolean;
  binariesOnly?: boolean;
  mcpOnly?: boolean;
  quiet?: boolean;
}

// Everything an adapter needs to lay down (or remove) its integration.
export interface InstallContext {
  scope: Scope;
  cwd: string;
  cliPath: string;
  mcpPath: string;
  // When set, restrict to these capabilities (honors skillsOnly/mcpOnly). undefined = all.
  capabilities?: Capability[];
  steps: InstallStep[];
}

export interface HostAdapter {
  id: string;
  name: string;
  capabilities: Capability[];
  /** Heuristic: is this host present on the machine? */
  detect(): boolean;
  install(ctx: InstallContext): void;
  uninstall(ctx: InstallContext): void;
}

function wants(ctx: InstallContext, cap: Capability): boolean {
  return !ctx.capabilities || ctx.capabilities.includes(cap);
}

// ── Shared fs helpers ──

function sameFile(a: string, b: string): boolean {
  try {
    return statSync(a).ino === statSync(b).ino && statSync(a).dev === statSync(b).dev;
  } catch {
    return false;
  }
}

// A missing config is an empty object; a MALFORMED one must throw. Returning {} for
// unparseable JSON meant the follow-up writeJson replaced the user's entire
// settings.json / mcp.json with just our keys — silently destroying their config.
// Every caller wraps this and reports a failed step instead.
function readJson(path: string): Record<string, any> {
  if (!existsSync(path)) return {};
  const raw = readFileSync(path, "utf-8");
  if (raw.trim() === "") return {};
  try {
    const parsed = JSON.parse(raw);
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed))
      throw new Error("expected a JSON object");
    return parsed;
  } catch (e: any) {
    throw new Error(`${path} is not valid JSON (${e?.message ?? e}) — fix or move it, then re-run install`);
  }
}

function writeJson(path: string, obj: Record<string, any>): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(obj, null, 2)}\n`, "utf-8");
}

function findOnPath(name: string, extra: string[] = []): string | undefined {
  const candidates = [join(USER_BIN, name), `/usr/local/bin/${name}`, `/opt/homebrew/bin/${name}`, ...extra];
  const found = candidates.find((p) => existsSync(p));
  if (found) return found;
  try {
    return execFileSync("which", [name], { encoding: "utf-8" }).trim() || undefined;
  } catch {
    return undefined;
  }
}

// Locate the deepthink-mcp binary that ships alongside this CLI.
function findMcpSource(): string | undefined {
  const self = process.execPath;
  return [
    join(dirname(self), "deepthink-mcp"),
    join(process.cwd(), "out", "deepthink-mcp"),
    join(process.cwd(), "cli", "out", "deepthink-mcp"),
  ].find((p) => existsSync(p));
}

// ── Skills parsing (shared across hosts) ──

interface ParsedSkill {
  id: string; // "deepthink", "deepthink-recall", …
  relPath: string; // original SKILLS key, e.g. "deepthink/recall.md"
  description: string;
  body: string;
  raw: string;
}

function parsedSkills(): ParsedSkill[] {
  return Object.entries(SKILLS).map(([relPath, raw]) => {
    const id = relPath.replace(/\.md$/, "").replace(/\//g, "-");
    let description = "";
    let body = raw;
    if (raw.startsWith("---")) {
      const end = raw.indexOf("---", 3);
      if (end !== -1) {
        for (const line of raw.slice(3, end).split("\n")) {
          const idx = line.indexOf(":");
          if (idx > 0 && line.slice(0, idx).trim() === "description") {
            description = line.slice(idx + 1).trim();
          }
        }
        body = raw.slice(end + 3).trim();
      }
    }
    return { id, relPath, description, body, raw };
  });
}

// ── Binaries + PATH (host-agnostic; the MCP binary backs every host) ──

function installBinaries(steps: InstallStep[]): void {
  mkdirSync(USER_BIN, { recursive: true });

  const self = process.execPath;
  const cliDest = join(USER_BIN, "deepthink");
  if (sameFile(self, cliDest)) {
    steps.push({ step: "CLI binary", status: "skipped", detail: `already at ${cliDest}` });
  } else if (self.includes("/bun")) {
    steps.push({ step: "CLI binary", status: "skipped", detail: "dev mode (run via bun) — build first" });
  } else {
    try {
      rmSync(cliDest, { force: true });
      copyFileSync(self, cliDest);
      chmodSync(cliDest, 0o755);
      steps.push({ step: "CLI binary", status: "done", detail: cliDest });
    } catch (e: any) {
      steps.push({ step: "CLI binary", status: "failed", detail: e?.message ?? String(e) });
    }
  }

  const mcpSrc = findMcpSource();
  const mcpDest = join(USER_BIN, "deepthink-mcp");
  if (!mcpSrc) {
    steps.push({ step: "MCP binary", status: "skipped", detail: "deepthink-mcp not found next to CLI" });
  } else if (sameFile(mcpSrc, mcpDest)) {
    steps.push({ step: "MCP binary", status: "skipped", detail: `already at ${mcpDest}` });
  } else {
    try {
      rmSync(mcpDest, { force: true });
      copyFileSync(mcpSrc, mcpDest);
      chmodSync(mcpDest, 0o755);
      steps.push({ step: "MCP binary", status: "done", detail: mcpDest });
    } catch (e: any) {
      steps.push({ step: "MCP binary", status: "failed", detail: e?.message ?? String(e) });
    }
  }
}

function ensurePath(steps: InstallStep[]): void {
  const block = `\n# Added by DeepThink\nexport PATH="${USER_BIN}:$PATH"\n`;
  let touched = 0;
  for (const f of [join(HOME, ".zshrc"), join(HOME, ".bash_profile"), join(HOME, ".bashrc")]) {
    let existing = "";
    try {
      existing = readFileSync(f, "utf-8");
    } catch (err: any) {
      // Absent is fine — appendFileSync creates it. Anything else (unreadable, not UTF-8)
      // means we can't tell whether our export is already there, so skip it rather than
      // append a duplicate on every install.
      if (err?.code !== "ENOENT") continue;
    }
    if (existing.includes(USER_BIN)) continue;
    try {
      appendFileSync(f, block, "utf-8");
      touched++;
    } catch {}
  }
  steps.push({
    step: "PATH",
    status: "done",
    detail: touched ? `added ${USER_BIN} to ${touched} shell file(s)` : "already on PATH",
  });
}

// ── Generic config writers ──

// Upsert mcpServers.deepthink in a JSON config (Cursor, Claude Desktop). `entry`
// lets a host add host-specific fields (e.g. Cursor's `type: "stdio"`).
function upsertJsonMcp(path: string, entry: Record<string, any>, label: string, steps: InstallStep[]): void {
  try {
    const cfg = readJson(path);
    if (cfg.mcpServers !== undefined && (typeof cfg.mcpServers !== "object" || Array.isArray(cfg.mcpServers)))
      throw new Error(`${path} has an unexpected "mcpServers" shape — fix it, then re-run install`);
    cfg.mcpServers = cfg.mcpServers ?? {};
    cfg.mcpServers.deepthink = entry;
    writeJson(path, cfg);
    steps.push({ step: "MCP", status: "done", detail: label });
  } catch (e: any) {
    steps.push({ step: "MCP", status: "failed", detail: e?.message ?? String(e) });
  }
}

function removeJsonMcp(path: string, steps: InstallStep[]): void {
  if (!existsSync(path)) return;
  try {
    const cfg = readJson(path);
    if (cfg.mcpServers?.deepthink) {
      delete cfg.mcpServers.deepthink;
      writeJson(path, cfg);
      steps.push({ step: "MCP", status: "done", detail: "unregistered" });
    }
  } catch {}
}

// ── Adapter: Claude Code ──

function claudeBase(ctx: InstallContext): string {
  return ctx.scope === "global" ? join(HOME, ".claude") : join(ctx.cwd, ".claude");
}

function installFlatSkills(base: string, steps: InstallStep[]): void {
  try {
    let written = 0;
    for (const [relPath, content] of Object.entries(SKILLS)) {
      const path = join(base, relPath);
      mkdirSync(dirname(path), { recursive: true });
      let current = "";
      try {
        current = readFileSync(path, "utf-8");
      } catch {}
      if (current !== content) {
        writeFileSync(path, content, "utf-8");
        written++;
      }
    }
    steps.push({
      step: "Skills",
      status: "done",
      detail: `${Object.keys(SKILLS).length} → ${base}${written ? ` (${written} updated)` : " (up to date)"}`,
    });
  } catch (e: any) {
    steps.push({ step: "Skills", status: "failed", detail: e?.message ?? String(e) });
  }
}

function removeFlatSkills(base: string, steps: InstallStep[]): void {
  try {
    for (const relPath of Object.keys(SKILLS)) rmSync(join(base, relPath), { force: true });
    rmSync(join(base, "deepthink"), { recursive: true, force: true });
    steps.push({ step: "Skills", status: "done", detail: `removed from ${base}` });
  } catch (e: any) {
    steps.push({ step: "Skills", status: "failed", detail: e?.message ?? String(e) });
  }
}

// Strip prior DeepThink hook entries from a Claude-Code-shaped event array
// ([{ matcher?, hooks: [{ type, command }] }]), leaving user hooks untouched.
function stripNestedHooks(eventHooks: any[]): any[] {
  if (!Array.isArray(eventHooks)) return [];
  return eventHooks
    .map((group) => {
      if (!group || !Array.isArray(group.hooks)) return group;
      return { ...group, hooks: group.hooks.filter((h: any) => !(h && isOurHookCommand(h.command))) };
    })
    .filter((g) => !g || !Array.isArray(g.hooks) || g.hooks.length > 0);
}

function installNestedHooks(
  settingsPath: string,
  cliPath: string,
  steps: InstallStep[],
  recallOnly = false,
  agentId?: string
): void {
  try {
    const settings = readJson(settingsPath);
    if (settings.hooks !== undefined && (typeof settings.hooks !== "object" || Array.isArray(settings.hooks)))
      throw new Error(`${settingsPath} has an unexpected "hooks" shape — fix it, then re-run install`);
    const hooks = (settings.hooks ?? {}) as Record<string, any[]>;
    // Replacing a non-array event with our array would discard whatever the user had there.
    for (const event of ["SessionStart", "SessionEnd"]) {
      if (hooks[event] !== undefined && !Array.isArray(hooks[event]))
        throw new Error(`${settingsPath} hooks.${event} is not an array — fix it, then re-run install`);
    }
    const recall = { type: "command", command: `"${cliPath}" session recall --quiet` };
    // Attribute unattended captures to this host so multi-agent provenance is correct.
    const agentFlag = agentId ? ` --agent ${agentId}` : "";
    const autosync = { type: "command", command: `"${cliPath}" session autosync${agentFlag}` };

    hooks.SessionStart = [
      ...stripNestedHooks(hooks.SessionStart ?? []),
      { matcher: "startup|resume", hooks: [recall] },
    ];
    if (!recallOnly) hooks.SessionEnd = [...stripNestedHooks(hooks.SessionEnd ?? []), { hooks: [autosync] }];

    settings.hooks = hooks;
    writeJson(settingsPath, settings);
    steps.push({
      step: "Hooks",
      status: "done",
      detail: recallOnly
        ? "SessionStart recall (no session-end on this host)"
        : "SessionStart recall + SessionEnd autosync",
    });
  } catch (e: any) {
    steps.push({ step: "Hooks", status: "failed", detail: e?.message ?? String(e) });
  }
}

function removeNestedHooks(settingsPath: string, steps: InstallStep[]): void {
  if (!existsSync(settingsPath)) return;
  try {
    const settings = readJson(settingsPath);
    const hooks = (settings.hooks ?? {}) as Record<string, any[]>;
    for (const event of ["SessionStart", "SessionEnd"]) {
      if (!hooks[event]) continue;
      const filtered = stripNestedHooks(hooks[event]);
      if (filtered.length > 0) hooks[event] = filtered;
      else delete hooks[event];
    }
    if (Object.keys(hooks).length > 0) settings.hooks = hooks;
    else delete settings.hooks;
    writeJson(settingsPath, settings);
    steps.push({ step: "Hooks", status: "done", detail: "removed session hooks" });
  } catch {}
}

const claudeCodeAdapter: HostAdapter = {
  id: "claude-code",
  name: "Claude Code (CLI)",
  capabilities: ["commands", "mcp", "hooks"],
  detect: () => existsSync(join(HOME, ".claude")) || !!findOnPath("claude"),
  install(ctx) {
    const base = claudeBase(ctx);
    if (wants(ctx, "commands")) installFlatSkills(join(base, "commands"), ctx.steps);
    if (wants(ctx, "mcp")) {
      const claude = findOnPath("claude");
      if (!claude) {
        ctx.steps.push({ step: "MCP", status: "skipped", detail: "claude CLI not on PATH" });
      } else if (!existsSync(ctx.mcpPath)) {
        ctx.steps.push({ step: "MCP", status: "skipped", detail: "deepthink-mcp not installed yet" });
      } else {
        const mcpScope = ctx.scope === "global" ? "user" : "project";
        try {
          try {
            execFileSync(claude, ["mcp", "remove", "--scope", mcpScope, "deepthink"], {
              stdio: "ignore",
              cwd: ctx.cwd,
            });
          } catch {}
          execFileSync(
            claude,
            ["mcp", "add", "--transport", "stdio", "--scope", mcpScope, "deepthink", "--", ctx.mcpPath],
            { stdio: "ignore", timeout: 15000, cwd: ctx.cwd }
          );
          ctx.steps.push({ step: "MCP", status: "done", detail: `claude mcp add (${mcpScope} scope)` });
        } catch (e: any) {
          ctx.steps.push({ step: "MCP", status: "failed", detail: e?.message ?? String(e) });
        }
      }
    }
    if (wants(ctx, "hooks"))
      installNestedHooks(join(base, "settings.json"), ctx.cliPath, ctx.steps, false, "claude-code");
  },
  uninstall(ctx) {
    const base = claudeBase(ctx);
    const claude = findOnPath("claude");
    if (claude) {
      const mcpScope = ctx.scope === "global" ? "user" : "project";
      try {
        execFileSync(claude, ["mcp", "remove", "--scope", mcpScope, "deepthink"], { stdio: "ignore", cwd: ctx.cwd });
        ctx.steps.push({ step: "MCP", status: "done", detail: "unregistered" });
      } catch {
        ctx.steps.push({ step: "MCP", status: "skipped" });
      }
    }
    removeNestedHooks(join(base, "settings.json"), ctx.steps);
    removeFlatSkills(join(base, "commands"), ctx.steps);
  },
};

// ── Adapter: Cursor — MCP + Skills + sessionStart/sessionEnd hooks ──

function cursorBase(ctx: InstallContext): string {
  return ctx.scope === "global" ? join(HOME, ".cursor") : join(ctx.cwd, ".cursor");
}

// Cursor's hooks.json shape: { version, hooks: { sessionStart: [{ command }], … } }.
function stripFlatHooks(arr: any[]): any[] {
  return Array.isArray(arr) ? arr.filter((h) => !(h && isOurHookCommand(h.command))) : [];
}

function installCursorSkills(base: string, steps: InstallStep[]): void {
  try {
    for (const s of parsedSkills()) {
      const path = join(base, "skills", s.id, "SKILL.md");
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, `---\nname: ${s.id}\ndescription: ${s.description}\n---\n\n${s.body}\n`, "utf-8");
    }
    steps.push({ step: "Skills", status: "done", detail: `${parsedSkills().length} → ${join(base, "skills")}` });
  } catch (e: any) {
    steps.push({ step: "Skills", status: "failed", detail: e?.message ?? String(e) });
  }
}

const cursorAdapter: HostAdapter = {
  id: "cursor",
  name: "Cursor",
  capabilities: ["commands", "mcp", "hooks"],
  detect: () => existsSync(join(HOME, ".cursor")),
  install(ctx) {
    const base = cursorBase(ctx);
    if (wants(ctx, "commands")) installCursorSkills(base, ctx.steps);
    if (wants(ctx, "mcp")) {
      if (!existsSync(ctx.mcpPath))
        ctx.steps.push({ step: "MCP", status: "skipped", detail: "deepthink-mcp not installed yet" });
      else
        upsertJsonMcp(
          join(base, "mcp.json"),
          { type: "stdio", command: ctx.mcpPath, args: [], env: { DEEPTHINK_AGENT_ID: "cursor" } },
          "mcp.json",
          ctx.steps
        );
    }
    if (wants(ctx, "hooks")) {
      try {
        const path = join(base, "hooks.json");
        const cfg = readJson(path);
        cfg.version = cfg.version ?? 1;
        if (cfg.hooks !== undefined && (typeof cfg.hooks !== "object" || Array.isArray(cfg.hooks)))
          throw new Error(`${path} has an unexpected "hooks" shape — fix it, then re-run install`);
        cfg.hooks = cfg.hooks ?? {};
        for (const event of ["sessionStart", "sessionEnd"]) {
          if (cfg.hooks[event] !== undefined && !Array.isArray(cfg.hooks[event]))
            throw new Error(`${path} hooks.${event} is not an array — fix it, then re-run install`);
        }
        cfg.hooks.sessionStart = [
          ...stripFlatHooks(cfg.hooks.sessionStart),
          { command: `"${ctx.cliPath}" session recall --quiet` },
        ];
        cfg.hooks.sessionEnd = [
          ...stripFlatHooks(cfg.hooks.sessionEnd),
          { command: `"${ctx.cliPath}" session autosync --agent cursor` },
        ];
        writeJson(path, cfg);
        ctx.steps.push({ step: "Hooks", status: "done", detail: "sessionStart recall + sessionEnd autosync" });
      } catch (e: any) {
        ctx.steps.push({ step: "Hooks", status: "failed", detail: e?.message ?? String(e) });
      }
    }
  },
  uninstall(ctx) {
    const base = cursorBase(ctx);
    removeJsonMcp(join(base, "mcp.json"), ctx.steps);
    const hooksPath = join(base, "hooks.json");
    if (existsSync(hooksPath)) {
      try {
        const cfg = readJson(hooksPath);
        if (cfg.hooks) {
          cfg.hooks.sessionStart = stripFlatHooks(cfg.hooks.sessionStart);
          cfg.hooks.sessionEnd = stripFlatHooks(cfg.hooks.sessionEnd);
          for (const k of ["sessionStart", "sessionEnd"]) if (cfg.hooks[k]?.length === 0) delete cfg.hooks[k];
        }
        writeJson(hooksPath, cfg);
        ctx.steps.push({ step: "Hooks", status: "done", detail: "removed" });
      } catch {}
    }
    for (const s of parsedSkills()) rmSync(join(base, "skills", s.id), { recursive: true, force: true });
    ctx.steps.push({ step: "Skills", status: "done", detail: "removed" });
  },
};

// ── Adapter registry ──

export const ADAPTERS: HostAdapter[] = [claudeCodeAdapter, cursorAdapter];

export function listAdapters(): { id: string; name: string; capabilities: Capability[]; detected: boolean }[] {
  return ADAPTERS.map((a) => ({ id: a.id, name: a.name, capabilities: a.capabilities, detected: a.detect() }));
}

function resolveAgents(ids: string[]): { adapters: HostAdapter[]; unknown: string[] } {
  const adapters: HostAdapter[] = [];
  const unknown: string[] = [];
  for (const id of ids) {
    if (id === "all") {
      for (const a of ADAPTERS) if (!adapters.includes(a)) adapters.push(a);
      continue;
    }
    const a = ADAPTERS.find((x) => x.id === id);
    if (a) {
      if (!adapters.includes(a)) adapters.push(a);
    } else unknown.push(id);
  }
  return { adapters, unknown };
}

// Build the per-run context shared by every adapter.
function buildContext(opts: InstallOptions): InstallContext {
  const capabilities: Capability[] | undefined = opts.skillsOnly ? ["commands"] : opts.mcpOnly ? ["mcp"] : undefined;
  return {
    scope: opts.scope ?? (opts.global === false ? "local" : "global"),
    cwd: opts.cwd ?? process.cwd(),
    cliPath: join(USER_BIN, "deepthink"),
    mcpPath: join(USER_BIN, "deepthink-mcp"),
    capabilities,
    steps: [],
  };
}

// ── Portable export (for any host without a first-class adapter) ──

// The standard stdio MCP-server JSON every host understands — handed to the user so
// they can paste it into Windsurf, Gemini CLI, Zed, Continue, etc.
function portableMcpSnippet(mcpPath: string): string {
  return JSON.stringify({ mcpServers: { deepthink: { command: mcpPath, args: [] } } }, null, 2);
}

const PORTABLE_README = (mcpPath: string, skillNames: string[]) => `# DeepThink — portable install kit

Drop these into any AI coding agent that supports custom commands/prompts and MCP servers.

## 1. Skills / prompts
The \`skills/\` folder holds ${skillNames.length} markdown files: ${skillNames.join(", ")}.
Copy them into your agent's command/prompt/rules directory, e.g.:
- **Windsurf**: \`~/.codeium/windsurf/global_workflows/\` (or project \`.windsurf/workflows/\`)
- **Gemini CLI**: convert to \`~/.gemini/commands/*.toml\` (prompt = file body)
- **Zed / Continue / others**: their prompt or rules directory

## 2. MCP server
Register the DeepThink MCP server using your agent's config. The standard schema
(in \`mcp.json\`) is:

\`\`\`json
${portableMcpSnippet(mcpPath)}
\`\`\`

Most agents use this exact \`mcpServers\` shape (Cursor, Claude Desktop, Windsurf,
Gemini CLI). For TOML-based hosts (Codex) use:

\`\`\`toml
[mcp_servers.deepthink]
command = "${mcpPath}"
args = []
\`\`\`

## 3. Auto recall / save (optional)
If your agent has session hooks, wire:
- session start → \`"${mcpPath.replace(/-mcp$/, "")}" session recall --quiet\`
- session end   → \`"${mcpPath.replace(/-mcp$/, "")}" session autosync\`
`;

// Write a self-contained, copy-anywhere kit: raw skill files + an mcp.json snippet +
// a README explaining where each goes. Covers every host we don't ship an adapter for.
export function exportPortable(dir: string): InstallStep[] {
  const steps: InstallStep[] = [];
  const mcpPath = join(USER_BIN, "deepthink-mcp");
  try {
    const skillsDir = join(dir, "skills");
    mkdirSync(skillsDir, { recursive: true });
    const names: string[] = [];
    for (const s of parsedSkills()) {
      writeFileSync(join(skillsDir, `${s.id}.md`), s.raw, "utf-8");
      names.push(`${s.id}.md`);
    }
    steps.push({ step: "Skills", status: "done", detail: `${names.length} → ${skillsDir}` });

    writeFileSync(join(dir, "mcp.json"), `${portableMcpSnippet(mcpPath)}\n`, "utf-8");
    steps.push({ step: "MCP snippet", status: "done", detail: join(dir, "mcp.json") });

    writeFileSync(join(dir, "README.md"), PORTABLE_README(mcpPath, names), "utf-8");
    steps.push({ step: "Instructions", status: "done", detail: join(dir, "README.md") });
  } catch (e: any) {
    steps.push({ step: "Export", status: "failed", detail: e?.message ?? String(e) });
  }
  return steps;
}

// Per-host result so the CLI can print a section per agent.
export interface HostResult {
  id: string;
  name: string;
  steps: InstallStep[];
}

export function runInstall(opts: InstallOptions): InstallStep[] {
  return runInstallByHost(opts).flatMap((h) => h.steps);
}

export function runInstallByHost(opts: InstallOptions): HostResult[] {
  const { adapters, unknown } = resolveAgents(opts.agents ?? ["claude-code"]);
  const results: HostResult[] = [];

  // Shared binaries + PATH run once (every host's MCP server is the same binary),
  // unless the caller restricted to commands-only.
  const sharedSteps: InstallStep[] = [];
  if (!opts.skillsOnly) {
    installBinaries(sharedSteps);
    ensurePath(sharedSteps);
  }
  if (sharedSteps.length > 0) results.push({ id: "shared", name: "Binaries & PATH", steps: sharedSteps });

  for (const u of unknown) {
    results.push({ id: u, name: u, steps: [{ step: "Unknown host", status: "failed", detail: `no adapter '${u}'` }] });
  }

  for (const adapter of adapters) {
    const ctx = buildContext(opts);
    adapter.install(ctx);
    results.push({ id: adapter.id, name: adapter.name, steps: ctx.steps });
  }
  return results;
}

export function runUninstall(opts: InstallOptions): InstallStep[] {
  return runUninstallByHost(opts).flatMap((h) => h.steps);
}

export function runUninstallByHost(opts: InstallOptions): HostResult[] {
  const { adapters } = resolveAgents(opts.agents ?? ["claude-code"]);
  const results: HostResult[] = [];

  for (const adapter of adapters) {
    const ctx = buildContext(opts);
    adapter.uninstall(ctx);
    results.push({ id: adapter.id, name: adapter.name, steps: ctx.steps });
  }

  // Only touch the shared binaries on a global uninstall — a local (project) uninstall
  // must not delete the machine-wide binary other hosts/projects still depend on.
  if ((opts.scope ?? (opts.global === false ? "local" : "global")) === "global") {
    const binSteps: InstallStep[] = [];
    try {
      rmSync(join(USER_BIN, "deepthink-mcp"), { force: true });
      binSteps.push({ step: "MCP binary", status: "done" });
    } catch {
      binSteps.push({ step: "MCP binary", status: "skipped" });
    }
    // Leave the running CLI binary in place to avoid deleting ourselves mid-run.
    binSteps.push({ step: "CLI binary", status: "skipped", detail: `remove ${join(USER_BIN, "deepthink")} manually` });
    results.push({ id: "shared", name: "Binaries", steps: binSteps });
  }

  return results;
}
