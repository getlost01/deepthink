import { Agent } from "./base";

interface PlanStep {
  step: number;
  action: string;
  tool: string | null;
  details: string;
}

export class Planner extends Agent {
  name = "planner";
  systemPrompt =
    "You are a task planner. Given a goal, break it into concrete, ordered steps. " +
    'Output a JSON array of step objects with "step" (int), "action" (str), ' +
    '"tool" (str or null), and "details" (str). Only output valid JSON.';

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
