import { retrieveContextHybrid, unifiedSearch } from "../core/context-engine";
import * as fileTools from "../tools/file";
import * as knowledge from "../tools/knowledge";
import * as search from "../tools/search";
import { WORKSPACE_TOOL_MAP } from "../tools/workspace";
import { Agent } from "./base";

const REACT_TOOLS: Record<string, { description: string; fn: (p: any) => any }> = {};

for (const [name, tool] of Object.entries(WORKSPACE_TOOL_MAP)) {
  REACT_TOOLS[name] = { description: tool.description, fn: (p) => tool.execute(p) };
}

REACT_TOOLS.knowledge_search = {
  description: "Hybrid search (BM25 + semantic) on knowledge base. params: {query: string, topK?: number}",
  fn: (p: { query: string; topK?: number }) => retrieveContextHybrid(p.query, { topK: p.topK ?? 5 }),
};
REACT_TOOLS.unified_search = {
  description:
    "Search across tasks, notes, reminders, and knowledge in one ranked list. params: {query: string, maxItems?: number, types?: string[]}",
  fn: (p: { query: string; maxItems?: number; types?: Array<"task" | "note" | "reminder" | "knowledge"> }) =>
    unifiedSearch(p.query, { maxItems: p.maxItems ?? 8, types: p.types }),
};
REACT_TOOLS.knowledge_save = {
  description: "Save content to knowledge base. params: {source: string, channel: string, content: string}",
  fn: (p: { source: string; channel: string; content: string }) =>
    knowledge.saveIntegrationData(p.source, p.channel, p.content),
};
REACT_TOOLS.read_file = {
  description: "Read a sandbox file. params: {path: string}",
  fn: (p: { path: string }) => fileTools.readFile(p.path),
};
REACT_TOOLS.write_file = {
  description: "Write a sandbox file. params: {content: string, filename: string, category?: string}",
  fn: (p: { content: string; filename: string; category?: string }) =>
    fileTools.writeFile(p.content, p.filename, (p.category as any) ?? "outputs"),
};
REACT_TOOLS.search_web = {
  description: "Search the web. Requires DEEPTHINK_SEARCH_API. params: {query: string, numResults?: number}",
  fn: (p: { query: string; numResults?: number }) => search.searchWeb(p.query, p.numResults ?? 5),
};

function toolDocs(): string {
  return Object.entries(REACT_TOOLS)
    .map(([name, t]) => `- ${name}: ${t.description}`)
    .join("\n");
}

interface ReActStep {
  thought: string;
  action: string;
  params: Record<string, any>;
  observation: string;
  error?: boolean;
}

function parseStep(text: string): { thought: string; action: string; params: Record<string, any> } | null {
  const thought = text.match(/THOUGHT:\s*(.+?)(?=ACTION:|$)/s)?.[1]?.trim();
  const action = text.match(/ACTION:\s*(\S+)/)?.[1]?.trim();
  const paramsRaw = text.match(/PARAMS:\s*(\{[\s\S]*?\})(?=\n[A-Z]|$)/)?.[1];
  if (!thought || !action) return null;
  let params: Record<string, any> = {};
  if (paramsRaw) {
    try {
      params = JSON.parse(paramsRaw);
    } catch {}
  }
  return { thought, action, params };
}

export class ReactAgent extends Agent {
  name = "react";
  systemPrompt = `You are a ReAct (Reason+Act) agent. Each step output exactly:

THOUGHT: your reasoning
ACTION: tool_name_or_DONE
PARAMS: {"key": "value"}

If ACTION is DONE, set PARAMS to {"summary": "what was accomplished"}.

Available tools:
${toolDocs()}

Rules:
- Always reason before acting
- Use tool results to inform next steps
- Call DONE only when goal is fully achieved
- Never repeat the same tool call with identical params`;

  async run(goal: string, context = "", maxSteps = 12): Promise<{ steps: ReActStep[]; result: string }> {
    const steps: ReActStep[] = [];
    let history = `Goal: ${goal}`;
    if (context) history += `\n\nContext:\n${context}`;

    for (let i = 0; i < maxSteps; i++) {
      const response = await this.think(`${history}\n\nStep ${i + 1}:`);
      const parsed = parseStep(response);

      if (!parsed) {
        steps.push({ thought: "parse failed", action: "DONE", params: { summary: response }, observation: "" });
        return { steps, result: response };
      }

      const { thought, action, params } = parsed;

      if (action === "DONE") {
        const summary = params.summary ?? "Task completed.";
        steps.push({ thought, action, params, observation: summary });
        return { steps, result: summary };
      }

      const tool = REACT_TOOLS[action];
      let observation: string;
      let isError = false;

      if (!tool) {
        observation = `Error: unknown tool '${action}'`;
        isError = true;
      } else {
        try {
          const r = await tool.fn(params);
          observation = typeof r === "string" ? r.slice(0, 1200) : JSON.stringify(r).slice(0, 1200);
        } catch (e: any) {
          observation = `Error: ${e.message ?? String(e)}`;
          isError = true;
        }
      }

      steps.push({ thought, action, params, observation, error: isError });
      history += `\n\nStep ${i + 1}:\nTHOUGHT: ${thought}\nACTION: ${action}\nPARAMS: ${JSON.stringify(params)}\nOBSERVATION: ${observation}`;
    }

    return { steps, result: "Max steps reached." };
  }
}
