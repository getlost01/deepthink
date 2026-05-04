import { Agent } from "./base";
import { WORKSPACE_TOOL_NAMES } from "../tools/workspace";

interface PlanStep {
  step: number;
  action: string;
  tool: string | null;
  details: string;
}

const BASE_TOOLS = ["write_file", "read_file", "search_web", "search_local", "analyze_file", "save_knowledge", "search_knowledge"];
const ALL_TOOLS = [...BASE_TOOLS, ...WORKSPACE_TOOL_NAMES];

export class Planner extends Agent {
  name = "planner";
  systemPrompt =
    "You are a task planner. Given a goal, break it into concrete, ordered steps. " +
    'Output a JSON array of step objects with "step" (int), "action" (str), ' +
    '"tool" (str or null), and "details" (str — for workspace tools, use JSON object string with params). ' +
    "Only output valid JSON.\n\n" +
    "Available tools: " + ALL_TOOLS.join(", ") + "\n\n" +
    "Workspace tools accept JSON details, e.g. {\"title\": \"...\", \"status\": \"To Do\", \"priority\": \"High\"}";

  async plan(task: string, context = ""): Promise<PlanStep[]> {
    let prompt = `Task: ${task}`;
    if (context) prompt += `\n\nContext:\n${context}`;

    const response = await this.think(prompt);

    try {
      const start = response.indexOf("[");
      const end = response.lastIndexOf("]") + 1;
      if (start === -1 || end === 0) throw new Error("no JSON array");
      return JSON.parse(response.slice(start, end));
    } catch {
      return [{ step: 1, action: task, tool: null, details: response }];
    }
  }
}
