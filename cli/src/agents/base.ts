import { query } from "../core/llm";
import { saveIntegrationData } from "../tools/knowledge";
import { appendObservation, buildMemoryContext } from "./memory";

interface LogEntry {
  agent: string;
  time: string;
  promptPreview: string;
  responsePreview: string;
}

export abstract class Agent {
  abstract name: string;
  abstract systemPrompt: string;
  saveOutput: boolean = false;
  log: LogEntry[] = [];

  async think(prompt: string, retries = 1): Promise<string> {
    const memCtx = buildMemoryContext(this.name);
    const sys = memCtx ? `${this.systemPrompt}\n\n${memCtx}` : this.systemPrompt;
    let lastError: unknown;
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        const response = await query(prompt, sys);
        this.record(prompt, response);
        appendObservation(this.name, `${prompt.slice(0, 80)} → ${response.slice(0, 120)}`);
        return response;
      } catch (e) {
        lastError = e;
        if (attempt < retries) await new Promise((r) => setTimeout(r, 2000 * (attempt + 1)));
      }
    }
    throw lastError;
  }

  private record(prompt: string, response: string): void {
    this.log.push({
      agent: this.name,
      time: new Date().toISOString(),
      promptPreview: prompt.slice(0, 100),
      responsePreview: response.slice(0, 200),
    });
    if (this.saveOutput) {
      saveIntegrationData("agent", this.name, response, { type: "agent-output" }, undefined, undefined, "latest.md");
    }
  }
}
