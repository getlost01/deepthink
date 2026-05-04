import { Agent } from "./base";
import * as fileTools from "../tools/file";
import * as search from "../tools/search";
import * as analytics from "../tools/analytics";
import * as knowledge from "../tools/knowledge";
import { WORKSPACE_TOOL_MAP } from "../tools/workspace";

type ToolFn = (...args: any[]) => any;

const TOOL_MAP: Record<string, ToolFn> = {
  write_file: fileTools.writeFile,
  read_file: fileTools.readFile,
  search_web: search.searchWeb,
  search_local: search.searchLocal,
  analyze_file: analytics.analyzeFile,
  save_knowledge: (content: string) => knowledge.saveIntegrationData("agent", "executor", content),
  search_knowledge: (query: string) => knowledge.searchIntegrationData(query),
};

for (const [name, tool] of Object.entries(WORKSPACE_TOOL_MAP)) {
  TOOL_MAP[name] = (details: string) => {
    const params = typeof details === "string" && details.trim().startsWith("{")
      ? JSON.parse(details)
      : { ref: details };
    return tool.execute(params);
  };
}

interface PlanStep {
  step: number;
  action: string;
  tool: string | null;
  details: string;
}

interface StepResult {
  step: number;
  status: "done" | "error";
  result: string;
}

export class Executor extends Agent {
  name = "executor";
  systemPrompt = "You execute tasks step by step, using available tools when needed.";

  async executePlan(steps: PlanStep[]): Promise<StepResult[]> {
    const results: StepResult[] = [];

    for (const step of steps) {
      const toolName = step.tool;

      if (toolName && toolName in TOOL_MAP) {
        try {
          const result = await this.runTool(toolName, step.details);
          results.push({ step: step.step, status: "done", result: String(result).slice(0, 500) });
        } catch (e: any) {
          results.push({ step: step.step, status: "error", result: e.message ?? String(e) });
        }
      } else {
        const response = await this.think(`Execute: ${step.action}\nDetails: ${step.details}`);
        results.push({ step: step.step, status: "done", result: response.slice(0, 500) });
      }
    }

    return results;
  }

  private async runTool(toolName: string, details: string): Promise<any> {
    const fn = TOOL_MAP[toolName];

    let kwargs: Record<string, any> = {};
    try {
      if (details.trim().startsWith("{")) kwargs = JSON.parse(details);
    } catch {}

    if (Object.keys(kwargs).length > 0) return fn(kwargs);

    if (toolName === "search_web") return fn(details);
    if (toolName === "read_file") return fn(details);
    if (toolName === "recall") return fn(details);
    if (toolName === "analyze_file") return fn(details);

    return fn(details);
  }
}
