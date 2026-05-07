import { query } from "../core/llm";
import { saveIntegrationData } from "../tools/knowledge";
import { buildMemoryContext, appendObservation } from "./memory";

interface LogEntry {
  agent: string;
  time: string;
  promptPreview: string;
  responsePreview: string;
}

export abstract class Agent {
  abstract name: string;
  abstract systemPrompt: string;
  log: LogEntry[] = [];

  async think(prompt: string): Promise<string> {
    const memCtx = buildMemoryContext(this.name);
    const sys = memCtx ? `${this.systemPrompt}\n\n${memCtx}` : this.systemPrompt;
    const response = await query(prompt, sys);
    this.record(prompt, response);
    appendObservation(this.name, `${prompt.slice(0, 80)} → ${response.slice(0, 120)}`);
    return response;
  }

  private record(prompt: string, response: string): void {
    this.log.push({
      agent: this.name,
      time: new Date().toISOString(),
      promptPreview: prompt.slice(0, 100),
      responsePreview: response.slice(0, 200),
    });
    saveIntegrationData("agent", this.name, response, { type: "agent-output" });
  }
}
