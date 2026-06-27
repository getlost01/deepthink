import * as knowledge from "./knowledge";

export interface MCPTool {
  name: string;
  description: string;
  inputSchema: Record<string, any>;
  execute: (params: Record<string, any>) => any;
}

// ── Knowledge Base Tools ──

export const KNOWLEDGE_TOOLS: MCPTool[] = [
  {
    name: "knowledge_project",
    description:
      "Work with knowledge projects (context, decisions, artifacts). Set `action`:\n" +
      "- list: all knowledge projects\n" +
      "- load: requires project → all context, decisions, and artifacts for it\n" +
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
        case "load":
          if (!p.project) throw new Error(`'project' is required for action 'load'`);
          return knowledge.loadProjectKnowledge(p.project);
        case "save": {
          if (!p.project || !p.content) throw new Error(`'project' and 'content' are required for action 'save'`);
          const path = knowledge.saveProjectKnowledge(p.project, p.content, p.type ?? "context");
          return { project: p.project, type: p.type ?? "context", path };
        }
        case "archive": {
          if (!p.project) throw new Error(`'project' is required for action 'archive'`);
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
      "- load: requires source; optional channel, limit (default 20) → recent entries\n" +
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
        limit: { type: "number", description: "Max entries for load (default 20)" },
      },
      required: ["action"],
    },
    execute: async (p) => {
      switch (p.action) {
        case "list":
          return knowledge.listIntegrations();
        case "load": {
          if (!p.source) throw new Error(`'source' is required for action 'load'`);
          const entries = knowledge.loadIntegrationData(p.source, p.channel, p.limit ?? 20);
          return { entries, count: entries.length };
        }
        case "capture": {
          if (!p.source || !p.channel || !p.content)
            throw new Error(`'source', 'channel', and 'content' are required for action 'capture'`);
          const path = knowledge.saveIntegrationData(p.source, p.channel, p.content, p.metadata ?? {}, p.title, p.tags);
          return { source: p.source, channel: p.channel, title: p.title, path };
        }
        case "compress": {
          if (!p.source || !p.channel) throw new Error(`'source' and 'channel' are required for action 'compress'`);
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
    description: "Search across all integration data by keyword. Searches content of all captured entries.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search query" },
        source: { type: "string", description: "Filter by source (e.g. 'slack', 'github')" },
        limit: { type: "number", description: "Max results (default: 20)" },
      },
      required: ["query"],
    },
    execute: (p) => {
      const results = knowledge.searchIntegrationData(p.query, p.source, p.limit ?? 20);
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
