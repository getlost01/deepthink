import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DEEPTHINK_ROOT } from "../config";
import { unifiedSearch } from "../core/context-engine";
import * as db from "../core/db";
import { Agent } from "./base";

const INSIGHTS_PATH = join(DEEPTHINK_ROOT, "data", "insights.json");

export type InsightType =
  | "overdue_tasks"
  | "stale_tasks"
  | "stale_project"
  | "blocked_tasks"
  | "task_cluster"
  | "high_priority_stale";

export interface Insight {
  id: string;
  type: InsightType;
  severity: "info" | "warning" | "action";
  title: string;
  description: string;
  suggestedAction?: string;
  relatedRefs?: string[];
  generatedAt: string;
}

function loadInsights(): Insight[] {
  if (!existsSync(INSIGHTS_PATH)) return [];
  try {
    return JSON.parse(readFileSync(INSIGHTS_PATH, "utf-8"));
  } catch {
    return [];
  }
}

function saveInsights(insights: Insight[]): void {
  mkdirSync(join(DEEPTHINK_ROOT, "data"), { recursive: true });
  writeFileSync(INSIGHTS_PATH, JSON.stringify(insights, null, 2));
}

function daysSince(d: Date): number {
  return (Date.now() - d.getTime()) / 86_400_000;
}

export class InsightAgent extends Agent {
  name = "insight";
  systemPrompt = "You analyze workspace data and identify patterns requiring attention. Be specific and concise.";

  async scan(): Promise<Insight[]> {
    const insights: Insight[] = [];
    const now = new Date().toISOString();
    const today = new Date();
    const _todayStr = today.toISOString().slice(0, 10);

    const tasks = db.listTasks({ excludeArchived: true });
    const projects = db.listProjects().filter((p) => !p.isArchived);

    // 1. Overdue tasks
    const overdue = tasks.filter(
      (t) => t.dueDate && t.dueDate < today && t.status !== "Done" && t.status !== "Cancelled"
    );
    if (overdue.length > 0) {
      insights.push({
        id: `overdue-${crypto.randomUUID()}`,
        type: "overdue_tasks",
        severity: "action",
        title: `${overdue.length} overdue task${overdue.length > 1 ? "s" : ""}`,
        description:
          overdue
            .slice(0, 3)
            .map((t) => `"${t.title}"`)
            .join(", ") + (overdue.length > 3 ? ` and ${overdue.length - 3} more` : ""),
        suggestedAction: "Reschedule or close overdue tasks",
        relatedRefs: overdue.map((t) => String(t.pk)),
        generatedAt: now,
      });
    }

    // 2. High-priority stale
    const hpStale = tasks.filter(
      (t) =>
        (t.priority === "High" || t.priority === "Urgent") &&
        t.status !== "Done" &&
        t.status !== "Cancelled" &&
        daysSince(t.modifiedAt) > 7
    );
    if (hpStale.length > 0) {
      insights.push({
        id: `hp-stale-${crypto.randomUUID()}`,
        type: "high_priority_stale",
        severity: "warning",
        title: `${hpStale.length} high-priority task${hpStale.length > 1 ? "s" : ""} untouched 7+ days`,
        description: hpStale
          .slice(0, 3)
          .map((t) => `"${t.title}"`)
          .join(", "),
        suggestedAction: "Update status or reduce priority",
        relatedRefs: hpStale.map((t) => String(t.pk)),
        generatedAt: now,
      });
    }

    // 3. In-Progress stuck
    const stuck = tasks.filter((t) => t.status === "In Progress" && daysSince(t.modifiedAt) > 5);
    if (stuck.length > 0) {
      insights.push({
        id: `stuck-${crypto.randomUUID()}`,
        type: "blocked_tasks",
        severity: "warning",
        title: `${stuck.length} "In Progress" task${stuck.length > 1 ? "s" : ""} stuck 5+ days`,
        description: stuck
          .slice(0, 3)
          .map((t) => `"${t.title}"`)
          .join(", "),
        suggestedAction: "Mark blocked, reassign, or update status",
        relatedRefs: stuck.map((t) => String(t.pk)),
        generatedAt: now,
      });
    }

    // 4. Stale projects with open tasks
    const notes = db.listNotes({ excludeArchived: true });
    for (const proj of projects) {
      const projTasks = tasks.filter((t) => t.projectPk === proj.pk);
      const projNotes = notes.filter((n) => n.projectPk === proj.pk);
      const items = [...projTasks, ...projNotes];
      const lastActivity = items.reduce<Date | null>(
        (acc, i) => (!acc || i.modifiedAt > acc ? i.modifiedAt : acc),
        null
      );
      if (!lastActivity || daysSince(lastActivity) > 21) {
        const open = projTasks.filter((t) => t.status !== "Done" && t.status !== "Cancelled");
        if (open.length > 0) {
          insights.push({
            id: `stale-proj-${proj.pk}-${crypto.randomUUID()}`,
            type: "stale_project",
            severity: "info",
            title: `Project "${proj.name}" inactive 21+ days`,
            description: `${open.length} open task${open.length > 1 ? "s" : ""} with no recent activity`,
            suggestedAction: `Resume or archive "${proj.name}"`,
            relatedRefs: [String(proj.pk)],
            generatedAt: now,
          });
        }
      }
    }

    // 5. AI: unassigned task cluster
    const unassigned = tasks.filter((t) => !t.projectPk && t.status !== "Done" && t.status !== "Cancelled");
    if (unassigned.length >= 5) {
      const clusterInsight = await this.detectCluster(unassigned);
      if (clusterInsight) insights.push({ ...clusterInsight, id: `cluster-${crypto.randomUUID()}`, generatedAt: now });
    }

    saveInsights(insights);
    return insights;
  }

  listInsights(): Insight[] {
    return loadInsights();
  }
  clearInsights(): void {
    saveInsights([]);
  }

  private async detectCluster(tasks: db.TaskRow[]): Promise<Omit<Insight, "id" | "generatedAt"> | null> {
    const list = tasks
      .slice(0, 20)
      .map((t) => `- ${t.title}`)
      .join("\n");
    const knCtx = unifiedSearch(
      tasks
        .slice(0, 5)
        .map((t) => t.title)
        .join(" "),
      { maxItems: 3, types: ["knowledge", "note"] }
    );
    const knowledgeStr =
      knCtx.length > 0 ? `\nRelated knowledge/notes: ${knCtx.map((r) => `"${r.title}"`).join(", ")}` : "";
    try {
      const res = await this.think(
        `These ${tasks.length} tasks have no project:\n${list}${knowledgeStr}\n\n` +
          `Do they cluster into a theme suggesting a new project? ` +
          `Respond ONLY with JSON: {"cluster": bool, "theme": "...", "suggestion": "..."}`
      );
      const j = JSON.parse(res.slice(res.indexOf("{"), res.lastIndexOf("}") + 1));
      if (!j.cluster) return null;
      return {
        type: "task_cluster",
        severity: "info",
        title: `${tasks.length} unassigned tasks may belong to a new project`,
        description: `Theme: "${j.theme}"`,
        suggestedAction: j.suggestion,
        relatedRefs: tasks.map((t) => String(t.pk)),
      };
    } catch {
      return null;
    }
  }
}
