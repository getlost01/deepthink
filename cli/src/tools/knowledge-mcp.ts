import * as knowledge from "./knowledge";

export interface MCPTool {
  name: string;
  description: string;
  inputSchema: Record<string, any>;
  execute: (params: Record<string, any>) => any;
}

function clampInt(value: unknown, fallback: number, min: number, max: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.min(Math.max(Math.trunc(value), min), max);
}

function requireText(p: Record<string, any>, field: string, action: string): string {
  const v = p[field];
  if (typeof v !== "string" || v.trim() === "")
    throw new Error(`'${field}' is required for action '${action}' and must be a non-empty string`);
  return v;
}

// context.md / decisions.md are append-only, so they grow without bound; `load` used to
// return them whole. Keep the newest material (the tail) up to this cap and flag the clip.
const PROJECT_LOAD_MAX_CHARS = 20000;

function tailCap(text: string, max: number): { text: string; truncated: boolean } {
  return text.length > max ? { text: text.slice(-max), truncated: true } : { text, truncated: false };
}

// ── Knowledge Base Tools ──

const KNOWLEDGE_TYPES = ["context", "decision", "artifact"];

export const KNOWLEDGE_TOOLS: MCPTool[] = [
  {
    name: "knowledge_project",
    description:
      "Work with knowledge projects (context, decisions, artifacts). Set `action`:\n" +
      "- list: all knowledge projects\n" +
      "- load: requires project → its context, decisions, and artifact filenames. context/decisions are " +
      "append-only files; only the newest ~20000 chars of each are returned (`contextTruncated` / " +
      "`decisionsTruncated` flag the clip)\n" +
      "- save: requires project, content; optional type (context|decision|artifact, default context)\n" +
      "- archive: requires project → compress its knowledge into a summary file",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["list", "load", "save", "archive"], description: "Operation to perform" },
        project: { type: "string", description: "Project name (load/save/archive)" },
        content: { type: "string", description: "Knowledge content, markdown (save)" },
        type: {
          type: "string",
          enum: ["context", "decision", "artifact"],
          description: "Knowledge type for save (default: context)",
        },
      },
      required: ["action"],
    },
    execute: async (p) => {
      switch (p.action) {
        case "list": {
          const projects = knowledge.listProjects();
          return { projects, count: projects.length };
        }
        case "load": {
          requireText(p, "project", "load");
          const k = knowledge.loadProjectKnowledge(p.project);
          const context = tailCap(k.context, PROJECT_LOAD_MAX_CHARS);
          const decisions = tailCap(k.decisions, PROJECT_LOAD_MAX_CHARS);
          return {
            context: context.text,
            decisions: decisions.text,
            artifacts: k.artifacts,
            ...(context.truncated ? { contextTruncated: true } : {}),
            ...(decisions.truncated ? { decisionsTruncated: true } : {}),
          };
        }
        case "save": {
          requireText(p, "project", "save");
          requireText(p, "content", "save");
          if (p.type !== undefined && !KNOWLEDGE_TYPES.includes(p.type))
            throw new Error(`unknown type: ${p.type}. Use one of: ${KNOWLEDGE_TYPES.join(", ")}`);
          const path = knowledge.saveProjectKnowledge(p.project, p.content, p.type ?? "context");
          return { project: p.project, type: p.type ?? "context", path };
        }
        case "archive": {
          requireText(p, "project", "archive");
          const path = await knowledge.archiveProject(p.project);
          return { project: p.project, path };
        }
        default:
          throw new Error(`unknown action: ${p.action}. Use one of: list, load, save, archive`);
      }
    },
  },
  {
    name: "knowledge_integration",
    description:
      "Work with integration data captured from external sources (slack, github, web, …). Set `action`:\n" +
      "- list: all integration sources and their channels\n" +
      "- load: requires source; optional channel, limit (default 20, max 100) → recent entries\n" +
      "- capture: requires source, channel, content; optional title, tags, metadata\n" +
      "- compress: requires source, channel → compress a channel's entries into a dense archive and delete originals",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["list", "load", "capture", "compress"], description: "Operation to perform" },
        source: { type: "string", description: "Integration source, e.g. 'slack', 'github', 'web'" },
        channel: { type: "string", description: "Channel/category name" },
        content: { type: "string", description: "Content to capture, markdown (capture)" },
        title: { type: "string", description: "Descriptive title (capture; auto-derived if omitted)" },
        tags: { type: "array", items: { type: "string" }, description: "Optional tags (capture)" },
        metadata: {
          type: "object",
          description: "Optional key-value metadata (capture)",
          additionalProperties: { type: "string" },
        },
        limit: { type: "number", description: "Max entries for load (default 20, max 100)" },
      },
      required: ["action"],
    },
    execute: async (p) => {
      switch (p.action) {
        case "list":
          return knowledge.listIntegrations();
        case "load": {
          requireText(p, "source", "load");
          const entries = knowledge.loadIntegrationData(p.source, p.channel, clampInt(p.limit, 20, 0, 100));
          return { entries, count: entries.length };
        }
        case "capture": {
          requireText(p, "source", "capture");
          requireText(p, "channel", "capture");
          requireText(p, "content", "capture");
          const path = knowledge.saveIntegrationData(p.source, p.channel, p.content, p.metadata ?? {}, p.title, p.tags);
          return { source: p.source, channel: p.channel, title: p.title, path };
        }
        case "compress": {
          requireText(p, "source", "compress");
          requireText(p, "channel", "compress");
          const path = await knowledge.compressKnowledge(p.source, p.channel);
          return { source: p.source, channel: p.channel, path };
        }
        default:
          throw new Error(`unknown action: ${p.action}. Use one of: list, load, capture, compress`);
      }
    },
  },
  {
    name: "knowledge_search",
    description:
      "Legacy keyword search over captured integration data only (slack/github/web imports) — returns a " +
      "relevance-windowed snippet per hit (full content stays on disk at the returned `file` path). Prefer " +
      "`smart_query` or `unified_search` for anything else: they cover tasks/notes/projects/knowledge together, " +
      "rank by relevance, and are budget-aware.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search query" },
        source: { type: "string", description: "Filter by source (e.g. 'slack', 'github')" },
        limit: { type: "number", description: "Max results (default: 20, max 100)" },
      },
      required: ["query"],
    },
    execute: (p) => {
      requireText(p, "query", "search");
      const results = knowledge.searchIntegrationData(p.query, p.source, clampInt(p.limit, 20, 0, 100));
      return { results, count: results.length };
    },
  },
  {
    name: "knowledge_stats",
    description: "Get knowledge base overview: project count, integration channels, archives.",
    inputSchema: { type: "object", properties: {} },
    execute: () => knowledge.knowledgeStats(),
  },
];

export const KNOWLEDGE_TOOL_MAP: Record<string, MCPTool> = Object.fromEntries(KNOWLEDGE_TOOLS.map((t) => [t.name, t]));
