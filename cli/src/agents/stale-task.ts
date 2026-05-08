import { unifiedSearch } from "../core/context-engine";
import * as db from "../core/db";
import { saveIntegrationData } from "../tools/knowledge";
import { Agent } from "./base";

export class StaleTaskAgent extends Agent {
  name = "stale-task";
  saveOutput = true;
  systemPrompt = "You analyze stale tasks and produce short, actionable triage reports.";

  async scan(staleDays = 14): Promise<{ count: number; report: string }> {
    const tasks = db.listTasks({ excludeArchived: true });
    const now = new Date();
    const stale = tasks.filter(
      (t) =>
        t.status !== "Done" &&
        t.status !== "Cancelled" &&
        (now.getTime() - t.modifiedAt.getTime()) / 86_400_000 > staleDays
    );

    if (stale.length === 0) {
      const report = `No tasks stale for ${staleDays}+ days. ✓`;
      saveIntegrationData("agent", this.name, report, { type: "agent-output" }, undefined, undefined, "latest.md");
      return { count: 0, report };
    }

    const byProject: Record<string, typeof stale> = {};
    for (const t of stale) {
      const key = t.projectName ?? "(no project)";
      if (!byProject[key]) byProject[key] = [];
      byProject[key].push(t);
    }

    const ctx = Object.entries(byProject)
      .map(
        ([proj, ts]) =>
          `**${proj}** (${ts.length}):\n` +
          ts
            .map(
              (t) =>
                `  - "${t.title}" [${t.status}] — ${Math.floor((now.getTime() - t.modifiedAt.getTime()) / 86_400_000)}d stale`
            )
            .join("\n")
      )
      .join("\n\n");

    const knCtx = unifiedSearch(
      stale
        .slice(0, 8)
        .map((t) => t.title)
        .join(" "),
      { maxItems: 4, types: ["knowledge", "note"] }
    );
    const knowledgeStr =
      knCtx.length > 0
        ? `\nRelated notes/knowledge:\n${knCtx.map((r) => `- "${r.title}" [${r.type}]`).join("\n")}\n`
        : "";

    const report = await this.think(
      `Tasks not updated in ${staleDays}+ days:\n\n${ctx}${knowledgeStr}\n` +
        "Write a 2-3 paragraph triage: what to archive, reschedule, or prioritize. Be specific."
    );

    db.createNote(`Stale Task Report ${now.toISOString().slice(0, 10)}`, {
      content: `# Stale Task Report — ${now.toISOString().slice(0, 10)}\n\n${report}`,
    });

    return { count: stale.length, report };
  }
}
