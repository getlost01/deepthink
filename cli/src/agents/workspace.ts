import { Agent } from "./base";
import { WORKSPACE_TOOLS, WORKSPACE_TOOL_MAP } from "../tools/workspace";

function buildSystemPrompt(): string {
  const today = new Date().toISOString().slice(0, 10);
  const toolDocs = WORKSPACE_TOOLS.map((t) =>
    `### ${t.name}\n${t.description}\nInput: ${JSON.stringify(t.inputSchema, null, 2)}`
  ).join("\n\n");

  return `You are a workspace management agent for DeepThink. You manage tasks, notes, and projects.

Today's date: ${today}

## Workspace Schema
- Tasks: title, detail, status (Backlog/To Do/In Progress/Done/Cancelled), priority (None/Low/Medium/High/Urgent), storyPoints (number), dueDate (YYYY-MM-DD), project
- Notes: title, content (markdown), isPinned, project
- Projects: name, summary, color (hex like #007AFF), isArchived

## Available Tools

${toolDocs}

## Instructions
Given a natural language request, respond with ONLY a JSON array of tool calls:
[{"tool": "workspace_create_task", "params": {"title": "...", ...}}]

Rules:
- If you need to read before writing (e.g. "move all backlog tasks"), emit reads first.
- For relative dates ("Friday", "next week"), compute the absolute YYYY-MM-DD date.
- For "done" or "complete" requests, set status to "Done".
- When referencing existing items, use the "ref" param with ID or name.
- Output ONLY valid JSON. No explanation, no markdown fences.`;
}

interface ToolAction {
  tool: string;
  params: Record<string, any>;
}

function parseActions(response: string): ToolAction[] {
  const cleaned = response.replace(/```json?\n?/g, "").replace(/```/g, "").trim();
  const start = cleaned.indexOf("[");
  const end = cleaned.lastIndexOf("]") + 1;
  if (start === -1 || end === 0) {
    if (cleaned.startsWith("{")) return [JSON.parse(cleaned)];
    throw new Error("no JSON actions found in response");
  }
  return JSON.parse(cleaned.slice(start, end));
}

export class WorkspaceAgent extends Agent {
  name = "workspace";
  systemPrompt = buildSystemPrompt();

  async handle(request: string): Promise<string> {
    const summary = WORKSPACE_TOOL_MAP["workspace_summary"].execute({});
    const prompt = `Current workspace state:\n${JSON.stringify(summary, null, 2)}\n\nUser request: ${request}`;

    const response = await this.think(prompt);
    let actions: ToolAction[];

    try {
      actions = parseActions(response);
    } catch {
      return `Could not parse actions from AI response:\n${response}`;
    }

    const results: string[] = [];

    for (const action of actions) {
      const tool = WORKSPACE_TOOL_MAP[action.tool];
      if (!tool) {
        results.push(`✗ unknown tool: ${action.tool}`);
        continue;
      }
      try {
        const result = tool.execute(action.params);
        const summary = formatResult(action.tool, result);
        results.push(`✓ ${summary}`);
      } catch (e: any) {
        results.push(`✗ ${action.tool}: ${e.message}`);
      }
    }

    return results.join("\n");
  }
}

function formatResult(toolName: string, result: any): string {
  if (toolName.includes("create")) {
    return `created ${toolName.replace("workspace_create_", "")} #${result.pk}: ${result.title ?? result.name}`;
  }
  if (toolName.includes("update")) {
    return `updated ${toolName.replace("workspace_update_", "")} #${result.pk} (${result.updated.join(", ")})`;
  }
  if (toolName.includes("delete")) {
    return `deleted ${toolName.replace("workspace_delete_", "")} #${result.pk}`;
  }
  if (toolName.includes("list")) {
    const items = Array.isArray(result) ? result : [];
    return `${items.length} ${toolName.replace("workspace_list_", "")} found`;
  }
  if (toolName.includes("get")) {
    return `${toolName.replace("workspace_get_", "")}: ${result.title ?? result.name} (#${result.pk})`;
  }
  return JSON.stringify(result);
}
