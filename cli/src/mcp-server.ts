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
import * as db from "./core/db";

const server = new Server(
  { name: "deepthink-workspace", version: "1.0.0" },
  { capabilities: { tools: {}, resources: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: WORKSPACE_TOOLS.map((t) => ({
    name: t.name,
    description: t.description,
    inputSchema: t.inputSchema,
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const tool = WORKSPACE_TOOL_MAP[request.params.name];
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
