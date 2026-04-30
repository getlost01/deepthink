import { Agent } from "./base";
import { writeFile } from "../tools/file";

export class Writer extends Agent {
  name = "writer";
  systemPrompt =
    "You are an expert documentation writer. You produce clear, well-structured " +
    "documents in markdown. Include headers, bullet points, and code blocks where appropriate. " +
    "Output only the document content.";

  async writeDoc(topic: string, context = "", filename?: string): Promise<string> {
    let prompt = `Write documentation about: ${topic}`;
    if (context) prompt += `\n\nContext and source material:\n${context}`;

    const content = await this.think(prompt);
    const fname = filename ?? `${topic.toLowerCase().replace(/\s+/g, "_").slice(0, 40)}.md`;
    return writeFile(content, fname, "docs");
  }

  async writeSummary(text: string, filename?: string): Promise<string> {
    const content = await this.think(`Summarize the following into a concise report:\n\n${text}`);
    return writeFile(content, filename ?? "summary.md", "docs");
  }

  async writeInsight(analysis: string, filename?: string): Promise<string> {
    const content = await this.think(
      "Based on this analysis, write a short insight document with: " +
        "key findings, implications, and recommended next steps.\n\n" +
        analysis
    );
    return writeFile(content, filename ?? "insight.md", "insights");
  }
}
