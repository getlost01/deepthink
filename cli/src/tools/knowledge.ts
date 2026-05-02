import { readFileSync, writeFileSync, appendFileSync, readdirSync, existsSync, mkdirSync } from "fs";
import { join } from "path";
import { KNOWLEDGE_DIRS, KNOWLEDGE_DIR } from "../config";
import { query } from "../core/llm";

function slugify(s: string): string {
  return s.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
}

function timestamp(): string {
  return new Date().toISOString().replace(/[:.]/g, "").slice(0, 15);
}

// MARK: - Project Knowledge

export function saveProjectKnowledge(project: string, content: string, type: "context" | "decision" | "artifact" = "context"): string {
  const projectDir = join(KNOWLEDGE_DIRS.projects, slugify(project));
  mkdirSync(projectDir, { recursive: true });

  let filename: string;
  if (type === "context") filename = "context.md";
  else if (type === "decision") filename = "decisions.json";
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
  const decisionsFile = join(projectDir, "decisions.json");
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
    try { return readdirSync(join(dir, f)).length > 0; } catch { return false; }
  });
}

// MARK: - Integration Data

export function saveIntegrationData(source: string, channel: string, content: string, metadata: Record<string, string> = {}): string {
  const channelDir = join(KNOWLEDGE_DIRS.integrations, source.toLowerCase(), slugify(channel));
  mkdirSync(channelDir, { recursive: true });

  const filename = `${timestamp()}.md`;
  const filepath = join(channelDir, filename);

  let fullContent = "";
  if (Object.keys(metadata).length > 0) {
    const meta = Object.entries(metadata).map(([k, v]) => `- **${k}**: ${v}`).join("\n");
    fullContent = `---\n${meta}\n---\n\n`;
  }
  fullContent += content;

  writeFileSync(filepath, fullContent, "utf-8");
  return filepath;
}

export function loadIntegrationData(source: string, channel?: string, limit = 20): { source: string; channel: string; file: string; content: string }[] {
  const sourceDir = join(KNOWLEDGE_DIRS.integrations, source.toLowerCase());
  if (!existsSync(sourceDir)) return [];

  const results: { source: string; channel: string; file: string; content: string }[] = [];
  const channels = channel ? [slugify(channel)] : readdirSync(sourceDir);

  for (const ch of channels) {
    const chDir = join(sourceDir, ch);
    if (!existsSync(chDir)) continue;
    try {
      const files = readdirSync(chDir).filter((f) => f.endsWith(".md")).sort().reverse();
      for (const f of files.slice(0, limit)) {
        results.push({
          source,
          channel: ch,
          file: f,
          content: readFileSync(join(chDir, f), "utf-8"),
        });
      }
    } catch {}
  }

  return results.sort((a, b) => b.file.localeCompare(a.file)).slice(0, limit);
}

export function listIntegrations(): { source: string; channels: string[] }[] {
  const dir = KNOWLEDGE_DIRS.integrations;
  if (!existsSync(dir)) return [];
  return readdirSync(dir).map((source) => {
    const sourceDir = join(dir, source);
    try {
      const channels = readdirSync(sourceDir);
      return { source, channels };
    } catch {
      return { source, channels: [] };
    }
  });
}

// MARK: - Archive & Compress

export async function compressKnowledge(source: string, channel: string): Promise<string> {
  const entries = loadIntegrationData(source, channel, 50);
  if (entries.length === 0) return "No entries to compress.";

  const combined = entries.map((e) => e.content).join("\n\n---\n\n");
  const compressed = await query(
    `Compress this knowledge into dense, structured bullet points. Keep all facts, dates, names, decisions. Remove filler:\n\n${combined.slice(0, 8000)}`,
    "You compress information. Output structured markdown bullets. Preserve all key data."
  );

  const archiveFile = join(KNOWLEDGE_DIRS.archive, `${source}_${slugify(channel)}_${timestamp()}.md`);
  const content = `# Compressed: ${source}/${channel}\nEntries: ${entries.length} | ${new Date().toISOString()}\n\n${compressed}`;
  writeFileSync(archiveFile, content, "utf-8");
  return archiveFile;
}

export async function archiveProject(project: string): Promise<string> {
  const knowledge = loadProjectKnowledge(project);
  if (!knowledge.context) return "No context to archive.";

  const compressed = await query(
    `Compress this project knowledge into dense, structured summary. Keep all key decisions, facts, dates:\n\n${knowledge.context.slice(0, 8000)}`,
    "You compress project knowledge. Output structured markdown. Preserve all key data."
  );

  const archiveFile = join(KNOWLEDGE_DIRS.archive, `${slugify(project)}_${timestamp()}.md`);
  const content = `# Archived: ${project}\n${new Date().toISOString()}\n\n${compressed}`;
  writeFileSync(archiveFile, content, "utf-8");
  return archiveFile;
}

// MARK: - Index

function updateIndex(project?: string): void {
  const indexFile = join(KNOWLEDGE_DIR, "index.json");
  let index: any = {};
  if (existsSync(indexFile)) {
    try { index = JSON.parse(readFileSync(indexFile, "utf-8")); } catch {}
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
}

export function searchIntegrationData(query: string, source?: string, limit = 20): { source: string; channel: string; file: string; content: string }[] {
  const sources = source ? [source] : listIntegrations().map((i) => i.source);
  const results: { source: string; channel: string; file: string; content: string }[] = [];
  const q = query.toLowerCase();

  for (const src of sources) {
    const items = loadIntegrationData(src, undefined, 100);
    for (const item of items) {
      if (item.content.toLowerCase().includes(q)) {
        results.push(item);
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
