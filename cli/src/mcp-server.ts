#!/usr/bin/env bun
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import * as db from "./core/db";
import { startReconciler } from "./core/embedding-service";
import { CONFIG_TOOL_MAP, CONFIG_TOOLS } from "./tools/config-mcp";
import * as knowledge from "./tools/knowledge";
import { KNOWLEDGE_TOOL_MAP, KNOWLEDGE_TOOLS } from "./tools/knowledge-mcp";
import { SMART_TOOL_MAP, SMART_TOOLS } from "./tools/smart-mcp";
import { WORKSPACE_TOOL_MAP, WORKSPACE_TOOLS } from "./tools/workspace";

const ALL_TOOLS = [...SMART_TOOLS, ...WORKSPACE_TOOLS, ...KNOWLEDGE_TOOLS, ...CONFIG_TOOLS];
const ALL_TOOL_MAP = { ...SMART_TOOL_MAP, ...WORKSPACE_TOOL_MAP, ...KNOWLEDGE_TOOL_MAP, ...CONFIG_TOOL_MAP };

const server = new Server(
  { name: "deepthink-workspace", version: "2.1.0" },
  { capabilities: { tools: {}, resources: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: ALL_TOOLS.map((t) => ({
    name: t.name,
    description: t.description,
    inputSchema: t.inputSchema,
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const tool = ALL_TOOL_MAP[request.params.name];
  if (!tool) {
    return {
      content: [{ type: "text", text: `unknown tool: ${request.params.name}` }],
      isError: true,
    };
  }
  try {
    const result = tool.execute(request.params.arguments ?? {});
    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
    };
  } catch (e: any) {
    return {
      content: [{ type: "text", text: e.message ?? String(e) }],
      isError: true,
    };
  }
});

const RESOURCES = [
  {
    uri: "deepthink://tasks",
    name: "Tasks",
    description: "Active (non-archived) tasks",
    fn: () => db.listTasks({ excludeArchived: true }),
  },
  {
    uri: "deepthink://notes",
    name: "Notes",
    description: "Active (non-archived) notes",
    fn: () => db.listNotes({ excludeArchived: true }),
  },
  {
    uri: "deepthink://projects",
    name: "Projects",
    description: "Active (non-archived) projects",
    fn: () => db.listProjects().filter((p) => !p.isArchived),
  },
  { uri: "deepthink://reminders", name: "Reminders", description: "All reminders", fn: () => db.listReminders() },
  {
    uri: "deepthink://knowledge/stats",
    name: "Knowledge Stats",
    description: "Knowledge base overview",
    fn: () => knowledge.knowledgeStats(),
  },
  {
    uri: "deepthink://knowledge/projects",
    name: "Knowledge Projects",
    description: "All knowledge projects",
    fn: () => knowledge.listProjects(),
  },
  {
    uri: "deepthink://knowledge/integrations",
    name: "Integrations",
    description: "All integration sources and channels",
    fn: () => knowledge.listIntegrations(),
  },
  {
    uri: "deepthink://overview",
    name: "Overview",
    description: "Compact system overview (~200 tokens)",
    fn: () => {
      const projects = db.listProjects().filter((p) => !p.isArchived);
      const tasks = db.listTasks({ excludeArchived: true });
      const ks = knowledge.knowledgeStats();
      const byStatus: Record<string, number> = {};
      for (const t of tasks) byStatus[t.status] = (byStatus[t.status] ?? 0) + 1;
      return {
        projects: projects.length,
        tasks: { total: tasks.length, byStatus },
        notes: db.listNotes({ excludeArchived: true }).length,
        reminders: db.listReminders().length,
        knowledge: ks,
        recentTasks: tasks.slice(0, 3).map((t) => `[${t.status}] ${t.title}`),
      };
    },
  },
];

server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: RESOURCES.map((r) => ({
    uri: r.uri,
    name: r.name,
    description: r.description,
    mimeType: "application/json",
  })),
}));

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const resource = RESOURCES.find((r) => r.uri === request.params.uri);
  if (!resource) throw new Error(`unknown resource: ${request.params.uri}`);
  return {
    contents: [{ uri: resource.uri, mimeType: "application/json", text: JSON.stringify(resource.fn(), null, 2) }],
  };
});

const transport = new StdioServerTransport();
await server.connect(transport);
startReconciler();
