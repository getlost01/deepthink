import { execSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { KNOWLEDGE_DIR } from "../config";

// A bucket is a stable, named container for session context. The common case is
// a code repo (resolved from its git remote so it survives renames/moves), but
// buckets can also be free-form topics or areas of work.

export type BucketType = "repo" | "topic" | "area";

export interface Bucket {
  id: string; // stable slug — channel key for session storage
  name: string; // display name
  type: BucketType;
  gitRemote?: string; // normalized remote (host/org/repo) when type === "repo"
  path?: string; // last-seen repo root on disk
  createdAt: string;
  lastSessionAt?: string;
  sessionCount: number;
  // Links to the workspace + knowledge "project" this bucket represents. Default to
  // `name`, but can be overridden so a bucket binds to differently-named projects.
  workspaceProject?: string;
  knowledgeProject?: string;
}

// The workspace/knowledge project name a bucket maps to (a bucket IS a project).
export function linkedProject(bucket: Bucket): string {
  return bucket.workspaceProject ?? bucket.name;
}

const REGISTRY = join(KNOWLEDGE_DIR, "buckets.json");

function slugify(s: string): string {
  return s
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9._-]/g, "")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64);
}

// github.com:org/repo.git, https://github.com/org/repo.git, ssh://git@h/o/r → host/org/repo
function normalizeRemote(url: string): string {
  let s = url.trim();
  s = s.replace(/^[a-z]+:\/\//i, ""); // strip scheme
  s = s.replace(/^[^@]+@/, ""); // strip user@
  s = s.replace(/:/g, "/"); // scp-style host:org → host/org
  s = s.replace(/\.git$/i, "");
  s = s.replace(/\/+$/, "");
  return s.toLowerCase();
}

function git(cwd: string, args: string): string | undefined {
  try {
    const out = execSync(`git -C "${cwd}" ${args}`, {
      stdio: ["ignore", "pipe", "ignore"],
      encoding: "utf-8",
    }).trim();
    return out || undefined;
  } catch {
    return undefined;
  }
}

export function gitInfo(cwd: string): { remote?: string; root?: string; branch?: string } {
  const root = git(cwd, "rev-parse --show-toplevel");
  const remoteRaw = git(cwd, "remote get-url origin");
  const branch = git(cwd, "rev-parse --abbrev-ref HEAD");
  return {
    remote: remoteRaw ? normalizeRemote(remoteRaw) : undefined,
    root,
    branch: branch && branch !== "HEAD" ? branch : undefined,
  };
}

function loadRegistry(): Record<string, Bucket> {
  if (!existsSync(REGISTRY)) return {};
  try {
    return JSON.parse(readFileSync(REGISTRY, "utf-8")) as Record<string, Bucket>;
  } catch {
    return {};
  }
}

function saveRegistry(reg: Record<string, Bucket>): void {
  mkdirSync(KNOWLEDGE_DIR, { recursive: true });
  const tmp = `${REGISTRY}.tmp-${process.pid}-${Date.now()}`;
  writeFileSync(tmp, JSON.stringify(reg, null, 2), "utf-8");
  renameSync(tmp, REGISTRY);
}

export function listBuckets(): Bucket[] {
  return Object.values(loadRegistry()).sort((a, b) =>
    (b.lastSessionAt ?? b.createdAt).localeCompare(a.lastSessionAt ?? a.createdAt)
  );
}

export function getBucket(id: string): Bucket | undefined {
  return loadRegistry()[id];
}

// Compute the id a request would resolve to and return the existing registry entry,
// WITHOUT registering anything. Used by read-only/quiet paths (e.g. the session-start
// hook) so merely opening a repo doesn't create a bucket.
export function peekBucket(opts: { cwd?: string; name?: string; type?: BucketType }): Bucket | undefined {
  const type: BucketType = opts.type ?? (opts.name && !opts.cwd ? "topic" : "repo");
  let id: string;
  if (type === "repo") {
    const cwd = opts.cwd ?? process.cwd();
    const info = gitInfo(cwd);
    const root = info.root ?? cwd;
    id = info.remote ? slugify(info.remote.replace(/\//g, "-")) : slugify(basename(root));
  } else {
    if (!opts.name) return undefined;
    id = `${type}-${slugify(opts.name)}`;
  }
  return loadRegistry()[id];
}

// Resolve (and register, if new) the bucket for a request. For repos the id is
// derived from the git remote, falling back to the repo basename when there is
// no remote. An explicit name/type override wins (used for topic/area buckets).
export function resolveBucket(opts: { cwd?: string; name?: string; type?: BucketType }): Bucket {
  const reg = loadRegistry();
  const type: BucketType = opts.type ?? (opts.name && !opts.cwd ? "topic" : "repo");

  let id: string;
  let name: string;
  let gitRemote: string | undefined;
  let path: string | undefined;

  if (type === "repo") {
    const cwd = opts.cwd ?? process.cwd();
    const info = gitInfo(cwd);
    path = info.root ?? cwd;
    gitRemote = info.remote;
    if (gitRemote) {
      id = slugify(gitRemote.replace(/\//g, "-"));
      name = opts.name ?? gitRemote.split("/").slice(-2).join("/");
    } else {
      const base = basename(path);
      id = slugify(base);
      name = opts.name ?? base;
    }
  } else {
    if (!opts.name) throw new Error(`'name' is required for ${type} buckets`);
    id = `${type}-${slugify(opts.name)}`;
    name = opts.name;
  }

  const existing = reg[id];
  const bucket: Bucket = existing ?? {
    id,
    name,
    type,
    gitRemote,
    path,
    createdAt: new Date().toISOString(),
    sessionCount: 0,
  };
  // Keep mutable fields fresh without clobbering history.
  bucket.name = name;
  if (gitRemote) bucket.gitRemote = gitRemote;
  if (path) bucket.path = path;
  reg[id] = bucket;
  saveRegistry(reg);
  return bucket;
}

export function touchBucket(id: string): void {
  const reg = loadRegistry();
  const b = reg[id];
  if (!b) return;
  b.lastSessionAt = new Date().toISOString();
  b.sessionCount = (b.sessionCount ?? 0) + 1;
  saveRegistry(reg);
}
