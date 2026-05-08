import { unifiedSearch } from "../core/context-engine";
import * as db from "../core/db";
import { Agent } from "./base";

export class DailyBriefAgent extends Agent {
  name = "daily-brief";
  saveOutput = true;
  systemPrompt =
    "You write concise daily briefings for a developer. Markdown format. " +
    "Direct and actionable. One-line summary first, then Today's Focus, Overdue (if any), Quick Wins. No fluff.";

  async generate(): Promise<string> {
    const today = new Date();
    const todayStr = today.toISOString().slice(0, 10);
    const yesterdayStr = new Date(today.getTime() - 86_400_000).toISOString().slice(0, 10);

    const tasks = db.listTasks({ excludeArchived: true });
    const reminders = db.listReminders();
    const notes = db.listNotes({ excludeArchived: true });

    const todayDue = tasks.filter((t) => t.dueDate?.toISOString().slice(0, 10) === todayStr && t.status !== "Done");
    const overdue = tasks.filter(
      (t) => t.dueDate && t.dueDate < today && t.status !== "Done" && t.status !== "Cancelled"
    );
    const inProgress = tasks.filter((t) => t.status === "In Progress");
    const todayReminders = reminders.filter(
      (r) => !r.isCompleted && r.reminderDate?.toISOString().slice(0, 10) === todayStr
    );
    const recentNotes = notes
      .filter((n) => {
        const d = n.modifiedAt.toISOString().slice(0, 10);
        return d === todayStr || d === yesterdayStr;
      })
      .slice(0, 5);

    const enriched = unifiedSearch(`priorities deadlines important ${todayStr}`, {
      maxItems: 5,
      types: ["knowledge", "note"],
    });
    const enrichedStr =
      enriched.length > 0
        ? `Related context: ${enriched.map((r) => `"${r.title}" [${r.type}${r.source ? `/${r.source}` : ""}]`).join(", ")}`
        : "";

    const context = [
      `Date: ${todayStr}`,
      `Due today (${todayDue.length}): ${
        todayDue
          .slice(0, 5)
          .map((t) => `"${t.title}" [${t.priority}]`)
          .join(", ") || "none"
      }`,
      `Overdue (${overdue.length}): ${
        overdue
          .slice(0, 3)
          .map(
            (t) =>
              `"${t.title}" (${Math.floor((today.getTime() - (t.dueDate?.getTime() ?? today.getTime())) / 86_400_000)}d late)`
          )
          .join(", ") || "none"
      }`,
      `In Progress (${inProgress.length}): ${
        inProgress
          .slice(0, 5)
          .map((t) => `"${t.title}"`)
          .join(", ") || "none"
      }`,
      `Reminders today (${todayReminders.length}): ${todayReminders.map((r) => `"${r.title}"`).join(", ") || "none"}`,
      `Recent notes: ${recentNotes.map((n) => `"${n.title}"`).join(", ") || "none"}`,
      ...(enrichedStr ? [enrichedStr] : []),
    ].join("\n");

    const brief = await this.think(`Workspace state:\n\n${context}\n\nWrite the daily brief.`);
    const noteContent = `# Daily Brief — ${todayStr}\n\n${brief}`;

    const existing = db.listNotes().find((n) => n.title === "Daily Brief");
    if (existing) {
      db.updateNote(existing.pk, { content: noteContent, pinned: true });
    } else {
      db.createNote("Daily Brief", { content: noteContent, pinned: true });
    }

    return brief;
  }
}
