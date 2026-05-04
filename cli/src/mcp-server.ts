#!/usr/bin/env bun
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { WORKSPACE_TOOLS, WORKSPACE_TOOL_MAP } from "./tools/workspace";
import { KNOWLEDGE_TOOLS, KNOWLEDGE_TOOL_MAP } from "./tools/knowledge-mcp";
import { CONFIG_TOOLS, CONFIG_TOOL_MAP } from "./tools/config-mcp";
import { SMART_TOOLS, SMART_TOOL_MAP } from "./tools/smart-mcp";
import * as db from "./core/db";
import * as knowledge from "./tools/knowledge";

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
  { uri: "deepthink://tasks", name: "Tasks", description: "All tasks", fn: () => db.listTasks() },
  { uri: "deepthink://notes", name: "Notes", description: "All notes", fn: () => db.listNotes() },
  { uri: "deepthink://projects", name: "Projects", description: "All projects", fn: () => db.listProjects() },
  { uri: "deepthink://reminders", name: "Reminders", description: "All reminders", fn: () => db.listReminders() },
  { uri: "deepthink://knowledge/stats", name: "Knowledge Stats", description: "Knowledge base overview", fn: () => knowledge.knowledgeStats() },
  { uri: "deepthink://knowledge/projects", name: "Knowledge Projects", description: "All knowledge projects", fn: () => knowledge.listProjects() },
  { uri: "deepthink://knowledge/integrations", name: "Integrations", description: "All integration sources and channels", fn: () => knowledge.listIntegrations() },
  { uri: "deepthink://overview", name: "Overview", description: "Compact system overview (~200 tokens)", fn: () => {
    const projects = db.listProjects();
    const tasks = db.listTasks();
    const ks = knowledge.knowledgeStats();
    const byStatus: Record<string, number> = {};
    for (const t of tasks) byStatus[t.status] = (byStatus[t.status] ?? 0) + 1;
    return { projects: projects.length, tasks: { total: tasks.length, byStatus }, notes: db.listNotes().length, reminders: db.listReminders().length, knowledge: ks, recentTasks: tasks.slice(0, 3).map(t => `[${t.status}] ${t.title}`) };
  }},
];

server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: RESOURCES.map((r) => ({ uri: r.uri, name: r.name, description: r.description, mimeType: "application/json" })),
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
