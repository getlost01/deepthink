import { execSync } from "node:child_process";
import {
  appendFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  renameSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { join, relative } from "node:path";
import { KNOWLEDGE_DIR, KNOWLEDGE_DIRS } from "../config";
import { extractRelevantWindow, tokenize } from "../core/context-engine";
import { indexEntry, removeEntry } from "../core/embedding-service";
import { query } from "../core/llm";
import { simpleHash } from "../core/vector-store";

// Index a knowledge file into the vector store at write time so it's retrievable
// immediately (no first-query indexing latency). entryId matches loadAllEntries.
function indexKnowledgeFile(
  filepath: string,
  title: string,
  body: string,
  tags: string[],
  source: string,
  importedAt: Date,
  provenance?: { agentId?: string | null; sessionId?: string | null; visibility?: "private" | "shared" | "handoff" }
): void {
  try {
    indexEntry({
      id: relative(KNOWLEDGE_DIR, filepath),
      type: "knowledge",
      title,
      content: body,
      tags,
      source,
      importedAt,
      agentId: provenance?.agentId,
      sessionId: provenance?.sessionId,
      visibility: provenance?.visibility,
    });
  } catch {}
}

function notifyAppSync(): void {
  try {
    execSync("notifyutil -p com.deepthink.workspace.changed 2>/dev/null || true", { stdio: "ignore" });
  } catch {}
}

function atomicWrite(targetPath: string, content: string): void {
  const tmp = `${targetPath}.tmp-${process.pid}-${Date.now()}`;
  writeFileSync(tmp, content, "utf-8");
  renameSync(tmp, targetPath);
}

function cleanupTempFiles(targetPath: string): void {
  const dir = targetPath.includes("/") ? targetPath.slice(0, targetPath.lastIndexOf("/")) : ".";
  const base = targetPath.includes("/") ? targetPath.slice(targetPath.lastIndexOf("/") + 1) : targetPath;
  try {
    for (const f of readdirSync(dir)) {
      if (f.startsWith(`${base}.tmp-`)) {
        try {
          unlinkSync(join(dir, f));
        } catch {}
      }
    }
  } catch {}
}

function slugify(s: string): string {
  return s
    .toLowerCase()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/g, "");
}

function timestamp(): string {
  return new Date().toISOString().replace(/[:.]/g, "").slice(0, 15);
}

function smartTitle(content: string): string {
  const lines = content.split("\n");
  for (const line of lines) {
    const clean = line
      .trim()
      .replace(/^#+\s*/, "")
      .replace(/^[-*>]+\s*/, "");
    if (clean.length <= 3) continue;
    if (clean.length <= 80) return clean;
    const truncated = clean.slice(0, 80);
    const lastSpace = truncated.lastIndexOf(" ");
    return lastSpace > 0 ? truncated.slice(0, lastSpace) : truncated;
  }
  return "";
}

// MARK: - Project Knowledge

export function saveProjectKnowledge(
  project: string,
  content: string,
  type: "context" | "decision" | "artifact" = "context"
): string {
  const projectDir = join(KNOWLEDGE_DIRS.projects, slugify(project));
  mkdirSync(projectDir, { recursive: true });

  let filename: string;
  if (type === "context") filename = "context.md";
  else if (type === "decision") filename = "decisions.md";
  else {
    const artDir = join(projectDir, "artifacts");
    mkdirSync(artDir, { recursive: true });
    filename = `artifacts/${timestamp()}_artifact.md`;
  }

  const filepath = join(projectDir, filename);
  const entry = `\n\n---\n_${new Date().toISOString()}_\n\n${content}`;

  if (existsSync(filepath)) {
    appendFileSync(filepath, entry, "utf-8");
  } else {
    writeFileSync(filepath, entry, "utf-8");
  }

  updateIndex(project);
  return filepath;
}

export function loadProjectKnowledge(project: string): { context: string; decisions: string; artifacts: string[] } {
  const projectDir = join(KNOWLEDGE_DIRS.projects, slugify(project));

  const contextFile = join(projectDir, "context.md");
  const decisionsFile = join(projectDir, "decisions.md");
  const artifactsDir = join(projectDir, "artifacts");

  const context = existsSync(contextFile) ? readFileSync(contextFile, "utf-8") : "";
  const decisions = existsSync(decisionsFile) ? readFileSync(decisionsFile, "utf-8") : "";
  const artifacts = existsSync(artifactsDir) ? readdirSync(artifactsDir) : [];

  return { context, decisions, artifacts };
}

export function listProjects(): string[] {
  const dir = KNOWLEDGE_DIRS.projects;
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((f) => {
    try {
      return readdirSync(join(dir, f)).length > 0;
    } catch {
      return false;
    }
  });
}

// MARK: - Integration Data

export function saveIntegrationData(
  source: string,
  channel: string,
  content: string,
  metadata: Record<string, string> = {},
  title?: string,
  tags?: string[],
  overwriteFilename?: string
): string {
  const channelDir = join(KNOWLEDGE_DIRS.integrations, source.toLowerCase(), slugify(channel));
  mkdirSync(channelDir, { recursive: true });

  const resolvedTitle = title || smartTitle(content) || `${source}/${channel}`;
  const ts = timestamp();
  const filename = overwriteFilename ?? `${slugify(resolvedTitle).slice(0, 50)}-${ts}.md`;
  const filepath = join(channelDir, filename);

  const frontmatter: Record<string, string> = {
    title: resolvedTitle,
    source,
    channel,
    captured_at: new Date().toISOString(),
    ...metadata,
  };
  if (tags && tags.length > 0) frontmatter.tags = `[${tags.join(", ")}]`;

  const meta = Object.entries(frontmatter)
    .map(([k, v]) => `${k}: ${v}`)
    .join("\n");
  const fullContent = `---\n${meta}\n---\n\n${content}`;

  writeFileSync(filepath, fullContent, "utf-8");
  // Provenance travels in `metadata` (→ frontmatter), so it survives re-indexing from
  // disk. Pull it back out here to stamp the chunks at write time too.
  const vis = metadata.visibility;
  indexKnowledgeFile(filepath, resolvedTitle, content, tags ?? [], "integrations", new Date(), {
    agentId: metadata.agent_id ?? null,
    sessionId: metadata.session_id ?? null,
    visibility: vis === "private" || vis === "handoff" || vis === "shared" ? vis : undefined,
  });
  updateIndex();
  return filepath;
}

export function loadIntegrationData(
  source: string,
  channel?: string,
  limit = 20
): { source: string; channel: string; file: string; content: string }[] {
  const sourceDir = join(KNOWLEDGE_DIRS.integrations, source.toLowerCase());
  if (!existsSync(sourceDir)) return [];

  const results: { source: string; channel: string; file: string; content: string }[] = [];
  const channels = channel
    ? [slugify(channel)]
    : readdirSync(sourceDir, { withFileTypes: true })
        .filter((d) => d.isDirectory())
        .map((d) => d.name);

  for (const ch of channels) {
    if (results.length >= limit) break;
    const chDir = join(sourceDir, ch);
    if (!existsSync(chDir)) continue;
    try {
      const files = readdirSync(chDir)
        .filter((f) => f.endsWith(".md"))
        .sort()
        .reverse();
      for (const f of files) {
        if (results.length >= limit) break;
        results.push({
          source,
          channel: ch,
          file: f,
          content: readFileSync(join(chDir, f), "utf-8"),
        });
      }
    } catch {}
  }

  return results.sort((a, b) => b.file.localeCompare(a.file));
}

export function listIntegrations(): { source: string; channels: string[] }[] {
  const dir = KNOWLEDGE_DIRS.integrations;
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => {
      const sourceDir = join(dir, d.name);
      try {
        const channels = readdirSync(sourceDir, { withFileTypes: true })
          .filter((c) => c.isDirectory())
          .map((c) => c.name);
        return { source: d.name, channels };
      } catch {
        return { source: d.name, channels: [] };
      }
    });
}

// MARK: - Archive & Compress

export async function compressKnowledge(source: string, channel: string): Promise<string> {
  let archiveFile = "";
  try {
    const entries = loadIntegrationData(source, channel, 50);
    if (entries.length === 0) return "No entries to compress.";

    const combined = entries.map((e) => e.content).join("\n\n---\n\n");
    const charLimit = 32000;
    if (combined.length > charLimit)
      console.warn(`[compress] Truncating ${combined.length} chars to ${charLimit} for ${source}/${channel}`);

    let compressed: string;
    try {
      compressed = await query(
        `Compress this knowledge into dense, structured bullet points. Keep all facts, dates, names, decisions. Remove filler:\n\n${combined.slice(0, charLimit)}`,
        "You compress information. Output structured markdown bullets. Preserve all key data."
      );
    } catch (err: any) {
      throw new Error(`compression failed for ${source}/${channel}: ${err?.message ?? String(err)}`);
    }

    mkdirSync(KNOWLEDGE_DIRS.archive, { recursive: true });
    archiveFile = join(KNOWLEDGE_DIRS.archive, `${source}_${slugify(channel)}_${timestamp()}.md`);
    const content = `# Compressed: ${source}/${channel}\nEntries: ${entries.length} | ${new Date().toISOString()}\n\n${compressed}`;
    atomicWrite(archiveFile, content);

    const chDir = join(KNOWLEDGE_DIRS.integrations, source.toLowerCase(), slugify(channel));
    for (const entry of entries) {
      try {
        unlinkSync(join(chDir, entry.file));
      } catch (err) {
        console.warn(`[compress] could not delete original ${entry.file}: ${err}`);
      }
    }

    notifyAppSync();
    return archiveFile;
  } catch (err) {
    if (archiveFile) cleanupTempFiles(archiveFile);
    throw err;
  }
}

export async function archiveProject(project: string): Promise<string> {
  let archiveFile = "";
  try {
    const k = loadProjectKnowledge(project);
    const hasContent = k.context || k.decisions || k.artifacts.length > 0;
    if (!hasContent) return "No content to archive.";

    const parts: string[] = [];
    if (k.context) parts.push(`## Context\n${k.context}`);
    if (k.decisions) parts.push(`## Decisions\n${k.decisions}`);
    if (k.artifacts.length > 0) {
      const artDir = join(KNOWLEDGE_DIRS.projects, slugify(project), "artifacts");
      const artContents = k.artifacts
        .map((f) => {
          try {
            return readFileSync(join(artDir, f), "utf-8");
          } catch {
            return "";
          }
        })
        .filter(Boolean);
      if (artContents.length > 0) parts.push(`## Artifacts\n${artContents.join("\n\n---\n\n")}`);
    }

    const combined = parts.join("\n\n");
    const charLimit = 32000;
    if (combined.length > charLimit)
      console.warn(`[archive] Truncating ${combined.length} chars to ${charLimit} for project ${project}`);

    let compressed: string;
    try {
      compressed = await query(
        `Compress this project knowledge into dense, structured summary. Keep all key decisions, facts, dates:\n\n${combined.slice(0, charLimit)}`,
        "You compress project knowledge. Output structured markdown. Preserve all key data."
      );
    } catch (err: any) {
      throw new Error(`compression failed for project ${project}: ${err?.message ?? String(err)}`);
    }

    mkdirSync(KNOWLEDGE_DIRS.archive, { recursive: true });
    archiveFile = join(KNOWLEDGE_DIRS.archive, `${slugify(project)}_${timestamp()}.md`);
    const content = `# Archived: ${project}\n${new Date().toISOString()}\n\n${compressed}`;
    atomicWrite(archiveFile, content);

    const projectDir = join(KNOWLEDGE_DIRS.projects, slugify(project));
    const contextPath = join(projectDir, "context.md");
    const decisionsPath = join(projectDir, "decisions.md");
    try {
      if (existsSync(contextPath)) unlinkSync(contextPath);
    } catch (err) {
      console.warn(`[archive] could not delete context.md: ${err}`);
    }
    try {
      if (existsSync(decisionsPath)) unlinkSync(decisionsPath);
    } catch (err) {
      console.warn(`[archive] could not delete decisions.md: ${err}`);
    }
    if (k.artifacts.length > 0) {
      const artDir = join(projectDir, "artifacts");
      for (const f of k.artifacts) {
        try {
          unlinkSync(join(artDir, f));
        } catch (err) {
          console.warn(`[archive] could not delete artifact ${f}: ${err}`);
        }
      }
    }

    notifyAppSync();
    return archiveFile;
  } catch (err) {
    if (archiveFile) cleanupTempFiles(archiveFile);
    throw err;
  }
}

// MARK: - Session Compaction

// Roll up a bucket's older session logs into a single dense summary, keeping the
// most recent `keepRecent` intact. Prevents per-bucket session sprawl from diluting
// retrieval. Returns the archive path, or null when nothing needed compacting.
export async function compactSessions(bucketId: string, keepRecent = 20): Promise<string | null> {
  const source = "sessions";
  const channelDir = join(KNOWLEDGE_DIRS.integrations, source, slugify(bucketId));
  if (!existsSync(channelDir)) return null;

  const files = readdirSync(channelDir)
    .filter((f) => f.endsWith(".md"))
    .sort()
    .reverse(); // newest first (timestamps sort lexically)
  if (files.length <= keepRecent) return null;

  const oldFiles = files.slice(keepRecent);

  // Deterministic archive name keyed on the exact set of rolled-up files. If a prior
  // run wrote the archive but crashed before deleting the sources, re-running lands on
  // the same filename (idempotent) — we skip recompaction and just finish the cleanup,
  // rather than minting a new timestamped duplicate.
  mkdirSync(KNOWLEDGE_DIRS.archive, { recursive: true });
  const setKey = simpleHash(oldFiles.slice().sort().join("|")).toString(36);
  const archiveFile = join(KNOWLEDGE_DIRS.archive, `sessions_${slugify(bucketId)}_${setKey}.md`);

  if (existsSync(archiveFile)) {
    for (const f of oldFiles) {
      const fp = join(channelDir, f);
      removeEntry(relative(KNOWLEDGE_DIR, fp));
      try {
        unlinkSync(fp);
      } catch {}
    }
    notifyAppSync();
    return archiveFile;
  }

  const combined = oldFiles
    .map((f) => {
      try {
        return readFileSync(join(channelDir, f), "utf-8");
      } catch {
        return "";
      }
    })
    .filter(Boolean)
    .join("\n\n---\n\n");
  if (!combined) return null;

  const charLimit = 32000;
  let compressed: string;
  try {
    compressed = await query(
      `Compress these older session logs into a dense, chronological summary. Preserve key decisions, recurring problems, and any still-open follow-ups:\n\n${combined.slice(0, charLimit)}`,
      "You compress engineering session history. Output structured markdown. Preserve decisions, dates, and open items."
    );
  } catch (err: any) {
    throw new Error(`session compaction failed for ${bucketId}: ${err?.message ?? String(err)}`);
  }

  const title = `Session history: ${bucketId} (rolled up ${oldFiles.length})`;
  const body = `# ${title}\n${new Date().toISOString()}\n\n${compressed}`;
  atomicWrite(archiveFile, body);
  indexKnowledgeFile(
    archiveFile,
    title,
    compressed,
    ["session-log", `bucket:${bucketId}`, "rollup"],
    "archive",
    new Date()
  );

  for (const f of oldFiles) {
    const fp = join(channelDir, f);
    removeEntry(relative(KNOWLEDGE_DIR, fp));
    try {
      unlinkSync(fp);
    } catch {}
  }

  notifyAppSync();
  return archiveFile;
}

// MARK: - Index

function updateIndex(project?: string): void {
  const indexFile = join(KNOWLEDGE_DIR, "index.json");
  let index: any = {};
  if (existsSync(indexFile)) {
    try {
      index = JSON.parse(readFileSync(indexFile, "utf-8"));
    } catch {}
  }

  index.version = index.version ?? 1;
  index.projects = index.projects ?? {};
  index.stats = index.stats ?? { totalEntries: 0 };

  if (project) {
    index.projects[project] = index.projects[project] ?? {};
    index.projects[project].lastUpdated = new Date().toISOString();
  }

  index.stats.totalEntries = (index.stats.totalEntries ?? 0) + 1;
  index.stats.lastUpdated = new Date().toISOString();

  writeFileSync(indexFile, JSON.stringify(index, null, 2), "utf-8");
  notifyAppSync();
}

// Snippet cap for search results — full content stays on disk at `file`; this tool only
// surfaces a relevance-windowed summary so a keyword hit can't dump a whole raw entry into
// context (prefer smart_query/unified_search for ranked, budget-aware retrieval).
const SEARCH_SNIPPET_MAX_LEN = 500;

export function searchIntegrationData(
  searchQuery: string,
  source?: string,
  limit = 20
): { source: string; channel: string; file: string; content: string; truncated: boolean }[] {
  const sources = source ? [source] : listIntegrations().map((i) => i.source);
  const results: { source: string; channel: string; file: string; content: string; truncated: boolean }[] = [];
  const q = searchQuery.toLowerCase();
  const queryTerms = new Set(tokenize(searchQuery));

  for (const src of sources) {
    const items = loadIntegrationData(src, undefined, 100);
    for (const item of items) {
      if (item.content.toLowerCase().includes(q)) {
        const truncated = item.content.length > SEARCH_SNIPPET_MAX_LEN;
        results.push({
          ...item,
          content: truncated ? extractRelevantWindow(item.content, queryTerms, SEARCH_SNIPPET_MAX_LEN) : item.content,
          truncated,
        });
      }
    }
  }

  return results.slice(0, limit);
}

export function knowledgeStats(): { projects: number; integrations: number; archives: number } {
  const projects = listProjects().length;
  const integrations = listIntegrations().reduce((sum, i) => sum + i.channels.length, 0);
  const archiveDir = KNOWLEDGE_DIRS.archive;
  const archives = existsSync(archiveDir) ? readdirSync(archiveDir).length : 0;
  return { projects, integrations, archives };
}
