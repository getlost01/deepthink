import { analyzeFile, analyzeJSON, computeNumericStats, summarizeData } from "../tools/analytics";
import { readFile, writeFile } from "../tools/file";
import { Agent } from "./base";

export class Analyst extends Agent {
  name = "analyst";
  systemPrompt =
    "You are a data analyst. You analyze data, find patterns, and produce insights. " +
    "When given data, describe key statistics, trends, outliers, and actionable findings. " +
    "Be precise with numbers.";

  async analyze(filepath: string, question?: string): Promise<string> {
    return analyzeFile(filepath, question);
  }

  async analyzeAndReport(filepath: string, title = "Analysis"): Promise<{ analysis: string; report: string }> {
    const analysis = await this.analyze(filepath);
    const reportContent = `# ${title}\n\n${analysis}`;
    const report = writeFile(reportContent, `${title.toLowerCase().replace(/\s+/g, "_")}_report.md`, "docs");
    return { analysis, report };
  }

  quickStats(filepath: string): string {
    if (filepath.endsWith(".csv")) {
      const summary = summarizeData(filepath);
      const numericCols = summary.columns.filter((c) => c.type === "numeric");
      const stats = numericCols.map((c) => ({
        column: c.name,
        ...computeNumericStats(filepath, c.name),
      }));

      const lines = [
        `Rows: ${summary.rowCount}, Columns: ${summary.columnCount}`,
        "",
        ...summary.columns.map((c) => `  ${c.name}: ${c.type}, ${c.nullCount} nulls, ${c.uniqueCount} unique`),
      ];

      if (stats.length > 0) {
        lines.push("", "Numeric stats:");
        for (const s of stats) {
          if (s.min !== undefined) {
            lines.push(
              `  ${s.column}: min=${s.min}, max=${s.max}, mean=${s.mean}, median=${s.median}, stddev=${s.stddev}`
            );
          }
        }
      }

      return lines.join("\n");
    }

    if (filepath.endsWith(".json")) {
      const info = analyzeJSON(filepath);
      return JSON.stringify(info, null, 2);
    }

    const content = readFile(filepath);
    const lines = content.split("\n").length;
    const chars = content.length;
    return `File: ${filepath}\nLines: ${lines}, Characters: ${chars}`;
  }
}
