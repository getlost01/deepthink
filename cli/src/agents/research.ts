import { retrieveContextHybrid } from "../core/context-engine";
import * as db from "../core/db";
import * as knowledge from "../tools/knowledge";
import * as search from "../tools/search";
import { Agent } from "./base";
import { Planner } from "./planner";
import { Writer } from "./writer";

interface ResearchQuestion {
  question: string;
  sources: { title: string; url?: string; content: string }[];
  findings: string;
}

export interface ResearchResult {
  topic: string;
  questions: ResearchQuestion[];
  synthesis: string;
  noteContent: string;
  savedTo?: string;
}

export class ResearchPipeline extends Agent {
  name = "research";
  systemPrompt =
    "You are a research assistant. Extract key facts, synthesize findings, and write clear structured notes.";

  private writer = new Writer();
  private planner = new Planner();

  async run(
    topic: string,
    opts: { depth?: "quick" | "deep"; project?: string; saveToKnowledge?: boolean } = {}
  ): Promise<ResearchResult> {
    const depth = opts.depth ?? "quick";
    const numQ = depth === "deep" ? 5 : 3;

    console.log(`[1/${numQ + 3}] Generating research questions for: "${topic}"`);
    const questions = await this.generateQuestions(topic, numQ);

    const researched: ResearchQuestion[] = [];
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      console.log(`[${i + 2}/${numQ + 3}] Researching: "${q}"`);
      const sources: ResearchQuestion["sources"] = [];

      const localCtx = retrieveContextHybrid(q, { topK: 3, maxTokens: 800 });
      if (localCtx.parts.length > 0) {
        sources.push({
          title: "Local Knowledge",
          content: localCtx.parts
            .map((p) => `**${p.title}**: ${p.content}`)
            .join("\n")
            .slice(0, 800),
        });
      }

      const webHits = await search.searchWeb(q, depth === "deep" ? 5 : 3);
      for (const r of webHits) {
        if (r.url && !r.title.includes("[Search placeholder]")) {
          sources.push({ title: r.title, url: r.url, content: r.snippet });
        }
      }

      const findings = await this.extractFindings(q, sources);
      researched.push({ question: q, sources, findings });
    }

    console.log(`[${numQ + 2}/${numQ + 3}] Synthesizing`);
    const synthesis = await this.synthesize(topic, researched);

    console.log(`[${numQ + 3}/${numQ + 3}] Writing note`);
    const noteContent = this.buildNote(topic, researched, synthesis);

    let savedTo: string | undefined;
    if (opts.saveToKnowledge !== false) {
      const channel = topic
        .toLowerCase()
        .replace(/\s+/g, "-")
        .replace(/[^a-z0-9-]/g, "")
        .slice(0, 40);
      knowledge.saveIntegrationData("research", channel, noteContent);
      savedTo = `research/${channel}`;

      if (opts.project) {
        db.createNote(`Research: ${topic}`, { content: noteContent, project: opts.project });
      }
    }

    return { topic, questions: researched, synthesis, noteContent, savedTo };
  }

  private async generateQuestions(topic: string, count: number): Promise<string[]> {
    const res = await this.planner.think(
      `Generate exactly ${count} focused research questions for: "${topic}"\nOutput ONLY a JSON array of strings.`
    );
    try {
      const s = res.indexOf("["),
        e = res.lastIndexOf("]") + 1;
      return (JSON.parse(res.slice(s, e)) as string[]).slice(0, count);
    } catch {
      return [topic, `What are the key aspects of ${topic}?`, `What are best practices for ${topic}?`].slice(0, count);
    }
  }

  private async extractFindings(q: string, sources: ResearchQuestion["sources"]): Promise<string> {
    if (sources.length === 0) return "No sources found.";
    const ctx = sources.map((s) => `**${s.title}**${s.url ? ` (${s.url})` : ""}:\n${s.content}`).join("\n\n");
    return this.think(`Q: ${q}\n\nSources:\n${ctx}\n\nExtract 3-5 key findings. Be specific and factual.`);
  }

  private async synthesize(topic: string, qs: ResearchQuestion[]): Promise<string> {
    const all = qs.map((q) => `**${q.question}**\n${q.findings}`).join("\n\n");
    return this.writer.think(
      `Topic: "${topic}"\n\nFindings:\n${all}\n\nWrite a 3-5 paragraph synthesis: key takeaways, patterns, recommended next steps.`
    );
  }

  private buildNote(topic: string, qs: ResearchQuestion[], synthesis: string): string {
    const date = new Date().toISOString().slice(0, 10);
    const lines = [`# Research: ${topic}`, `*${date}*\n`, `## Synthesis\n`, synthesis, `\n## Findings\n`];
    for (const q of qs) {
      lines.push(`### ${q.question}\n`, q.findings);
      const withUrl = q.sources.filter((s) => s.url);
      if (withUrl.length > 0) {
        lines.push("\n**Sources:**");
        for (const s of withUrl) lines.push(`- [${s.title}](${s.url})`);
      }
      lines.push("");
    }
    return lines.join("\n");
  }
}
