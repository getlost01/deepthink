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

function extractJson(text: string): Record<string, any> {
  const start = text.indexOf("{");
  if (start === -1) return {};
  let depth = 0;
  for (let i = start; i < text.length; i++) {
    if (text[i] === "{") depth++;
    else if (text[i] === "}") {
      depth--;
      if (depth === 0) {
        try {
          return JSON.parse(text.slice(start, i + 1));
        } catch {
          return {};
        }
      }
    }
  }
  return {};
}

function parseStep(text: string): { thought: string; action: string; params: Record<string, any> } | null {
  const normalized = text.trim().replace(/\r\n/g, "\n");
  const thoughtMatch = normalized.match(/THOUGHT[:\s]+(.+?)(?=\s*ACTION[:\s]|$)/is);
  const actionMatch = normalized.match(/ACTION[:\s]+(\S+)/i);
  const paramsMatch = normalized.match(/PARAMS[:\s]+([\s\S]*?)(?=\s*(?:THOUGHT|ACTION)\b|$)/i);

  const action = actionMatch?.[1]?.trim();
  if (!action) return null;

  const thought = thoughtMatch?.[1]?.trim() ?? "(no thought)";
  const params = paramsMatch ? extractJson(paramsMatch[1]) : {};
  const normalizedAction = action.toUpperCase() === "DONE" ? "DONE" : action;

  return { thought, action: normalizedAction, params };
}

function progressSummary(steps: ReActStep[]): string {
  const done = steps.filter((s) => !s.error && s.action !== "DONE");
  if (done.length === 0) return "No steps completed.";
  const last = done[done.length - 1];
  return `Completed ${done.length} step(s). Last: ${last.action} → ${last.observation.slice(0, 200)}`;
}

export class ReactAgent extends Agent {
  name = "react";
  systemPrompt = `You are a ReAct (Reason+Act) agent. Each step output exactly:

THOUGHT: your reasoning
ACTION: tool_name_or_DONE
PARAMS: {"key": "value"}

If ACTION is DONE, set PARAMS to {"summary": "what was accomplished"}.
If a tool returns an error, try a different approach rather than repeating the same call.

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
    const seen = new Set<string>();
    let parseFailures = 0;

    for (let i = 0; i < maxSteps; i++) {
      let response: string;
      try {
        response = await this.think(`${history}\n\nStep ${i + 1}:`);
      } catch (e: any) {
        const summary = progressSummary(steps);
        steps.push({
          thought: "llm error",
          action: "DONE",
          params: {},
          observation: e.message ?? String(e),
          error: true,
        });
        return { steps, result: `LLM error: ${e.message ?? String(e)}. ${summary}` };
      }

      const parsed = parseStep(response);

      if (!parsed) {
        parseFailures++;
        if (parseFailures >= 2) {
          const summary = progressSummary(steps);
          steps.push({ thought: "parse failed", action: "DONE", params: { summary }, observation: "" });
          return { steps, result: summary };
        }
        history += `\n\nStep ${i + 1}: [Response did not follow the required format. Output exactly:\nTHOUGHT: ...\nACTION: ...\nPARAMS: {...}]`;
        i--;
        continue;
      }

      parseFailures = 0;
      const { thought, action, params } = parsed;

      if (action === "DONE") {
        const summary = params.summary ?? progressSummary(steps);
        steps.push({ thought, action, params, observation: summary });
        return { steps, result: summary };
      }

      const callKey = `${action}:${JSON.stringify(params)}`;
      if (seen.has(callKey)) {
        const obs = `[Skipped: identical call already made. Choose a different tool or params.]`;
        steps.push({ thought, action, params, observation: obs, error: true });
        history += `\n\nStep ${i + 1}:\nTHOUGHT: ${thought}\nACTION: ${action}\nPARAMS: ${JSON.stringify(params)}\nOBSERVATION: ${obs}`;
        continue;
      }
      seen.add(callKey);

      const tool = REACT_TOOLS[action];
      let observation: string;
      let isError = false;

      if (!tool) {
        observation = `Error: unknown tool '${action}'. Available: ${Object.keys(REACT_TOOLS).join(", ")}`;
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

    return { steps, result: progressSummary(steps) };
  }
}
