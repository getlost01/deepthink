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
    name: "knowledge_stats",
    description: "Get knowledge base overview: project count, integration channels, archives.",
    inputSchema: { type: "object", properties: {} },
    execute: () => knowledge.knowledgeStats(),
  },
  {
    name: "knowledge_list_projects",
    description: "List all knowledge projects.",
    inputSchema: { type: "object", properties: {} },
    execute: () => {
      const projects = knowledge.listProjects();
      return { projects, count: projects.length };
    },
  },
  {
    name: "knowledge_load_project",
    description: "Load all knowledge for a project: context, decisions, and artifacts.",
    inputSchema: {
      type: "object",
      properties: {
        project: { type: "string", description: "Project name" },
      },
      required: ["project"],
    },
    execute: (p) => knowledge.loadProjectKnowledge(p.project),
  },
  {
    name: "knowledge_save_project",
    description: "Save knowledge to a project. Types: 'context' (general info), 'decision' (decisions log), 'artifact' (timestamped artifact).",
    inputSchema: {
      type: "object",
      properties: {
        project: { type: "string", description: "Project name" },
        content: { type: "string", description: "Knowledge content (markdown)" },
        type: { type: "string", enum: ["context", "decision", "artifact"], description: "Knowledge type (default: context)" },
      },
      required: ["project", "content"],
    },
    execute: (p) => {
      const path = knowledge.saveProjectKnowledge(p.project, p.content, p.type ?? "context");
      return { project: p.project, type: p.type ?? "context", path };
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
    name: "knowledge_list_integrations",
    description: "List all integration sources and their channels.",
    inputSchema: { type: "object", properties: {} },
    execute: () => knowledge.listIntegrations(),
  },
  {
    name: "knowledge_load_integration",
    description: "Load recent entries from an integration source/channel.",
    inputSchema: {
      type: "object",
      properties: {
        source: { type: "string", description: "Integration source (e.g. 'slack', 'github')" },
        channel: { type: "string", description: "Channel name (optional, loads all if omitted)" },
        limit: { type: "number", description: "Max entries (default: 20)" },
      },
      required: ["source"],
    },
    execute: (p) => {
      const entries = knowledge.loadIntegrationData(p.source, p.channel, p.limit ?? 20);
      return { entries, count: entries.length };
    },
  },
  {
    name: "knowledge_capture",
    description: "Capture data from an external source into the knowledge base.",
    inputSchema: {
      type: "object",
      properties: {
        source: { type: "string", description: "Source name (e.g. 'slack', 'github', 'web')" },
        channel: { type: "string", description: "Channel/category name" },
        content: { type: "string", description: "Content to capture (markdown)" },
        title: { type: "string", description: "Descriptive title for this entry (auto-derived from content if omitted)" },
        tags: { type: "array", items: { type: "string" }, description: "Optional tags for categorisation" },
        metadata: {
          type: "object",
          description: "Optional key-value metadata",
          additionalProperties: { type: "string" },
        },
      },
      required: ["source", "channel", "content"],
    },
    execute: (p) => {
      const path = knowledge.saveIntegrationData(p.source, p.channel, p.content, p.metadata ?? {}, p.title, p.tags);
      return { source: p.source, channel: p.channel, title: p.title, path };
    },
  },

];

export const KNOWLEDGE_TOOL_MAP: Record<string, MCPTool> = Object.fromEntries(
  KNOWLEDGE_TOOLS.map((t) => [t.name, t])
);
