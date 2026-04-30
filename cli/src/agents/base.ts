import { query } from "../core/llm";
import { saveMemory } from "../tools/memory";

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
    const response = await query(prompt, this.systemPrompt);
    this.record(prompt, response);
    return response;
  }

  private record(prompt: string, response: string): void {
    this.log.push({
      agent: this.name,
      time: new Date().toISOString(),
      promptPreview: prompt.slice(0, 100),
      responsePreview: response.slice(0, 200),
    });
    saveMemory(`[${this.name}] ${response.slice(0, 300)}`, [this.name, "agent-output"], "short");
  }
}
