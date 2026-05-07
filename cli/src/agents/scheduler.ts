import { existsSync, readFileSync, writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { DEEPTHINK_ROOT } from "../config";

const STATE_PATH = join(DEEPTHINK_ROOT, "data", "schedule-state.json");

interface ScheduleState { lastRun: Record<string, string> }

function load(): ScheduleState {
  if (!existsSync(STATE_PATH)) return { lastRun: {} };
  try { return JSON.parse(readFileSync(STATE_PATH, "utf-8")); } catch { return { lastRun: {} }; }
}
function save(s: ScheduleState) {
  mkdirSync(join(DEEPTHINK_ROOT, "data"), { recursive: true });
  writeFileSync(STATE_PATH, JSON.stringify(s, null, 2));
}
function hoursSince(iso: string | undefined): number {
  if (!iso) return Infinity;
  return (Date.now() - new Date(iso).getTime()) / 3_600_000;
}

export interface JobResult { job: string; ran: boolean; result?: string; error?: string }

const JOBS = [
  { id: "daily-brief",   name: "Daily Brief",       hours: 20 },
  { id: "stale-tasks",   name: "Stale Task Scan",    hours: 7 * 24 },
  { id: "insight-scan",  name: "Proactive Insights", hours: 4 },
];

async function runJob(id: string): Promise<string> {
  if (id === "daily-brief") {
    const { DailyBriefAgent } = await import("./daily-brief");
    const brief = await new DailyBriefAgent().generate();
    return brief.slice(0, 200);
  }
  if (id === "stale-tasks") {
    const { StaleTaskAgent } = await import("./stale-task");
    const { count, report } = await new StaleTaskAgent().scan();
    return `${count} stale tasks. ${report.slice(0, 100)}`;
  }
  if (id === "insight-scan") {
    const { InsightAgent } = await import("./insight");
    const insights = await new InsightAgent().scan();
    return `${insights.length} insight${insights.length !== 1 ? "s" : ""} generated`;
  }
  throw new Error(`unknown job: ${id}`);
}

export async function runScheduledJobs(opts: { force?: boolean } = {}): Promise<JobResult[]> {
  const state = load();
  const results: JobResult[] = [];
  for (const job of JOBS) {
    const due = opts.force || hoursSince(state.lastRun[job.id]) >= job.hours;
    if (!due) { results.push({ job: job.name, ran: false }); continue; }
    console.log(`  Running: ${job.name}...`);
    try {
      const result = await runJob(job.id);
      state.lastRun[job.id] = new Date().toISOString();
      save(state);
      results.push({ job: job.name, ran: true, result });
    } catch (e: any) {
      results.push({ job: job.name, ran: true, error: e.message ?? String(e) });
    }
  }
  return results;
}

export function scheduleStatus(): Record<string, { lastRun: string | null; nextDueIn: string }> {
  const state = load();
  const out: Record<string, { lastRun: string | null; nextDueIn: string }> = {};
  for (const { id, hours } of JOBS) {
    const last = state.lastRun[id];
    const remainHours = last ? Math.max(0, hours - hoursSince(last)) : 0;
    out[id] = {
      lastRun: last ?? null,
      nextDueIn: remainHours < 1 ? "now" : `${Math.ceil(remainHours)}h`,
    };
  }
  return out;
}
