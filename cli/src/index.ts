#!/usr/bin/env bun
import { DEEPTHINK_ROOT, SANDBOX_ROOT, MEMORY_DIR, KNOWLEDGE_DIR } from "./config";
import { initSandbox, listFiles } from "./core/sandbox";
import { query, isClaudeAvailable } from "./core/llm";
import { Planner } from "./agents/planner";
import { Executor } from "./agents/executor";
import { Writer } from "./agents/writer";
import { Analyst } from "./agents/analyst";
import * as fileTools from "./tools/file";
import * as search from "./tools/search";
import * as memoryTools from "./tools/memory";
import * as knowledgeTools from "./tools/knowledge";
import * as db from "./core/db";

initSandbox();

const args = process.argv.slice(2);
const cmd = args[0];
const sub = args[1];

const p = (t: string) => console.log(t);
const ok = (t: string) => console.log(`✓ ${t}`);
const err = (t: string) => { console.error(`✗ ${t}`); process.exit(1); };
const flag = (f: string) => args.includes(f);
const flagVal = (f: string) => { const i = args.indexOf(f); return i !== -1 ? args[i + 1] : undefined; };

// ── deepthink status ──

function cmdStatus() {
  p("deepthink\n");
  p(`root:       ${DEEPTHINK_ROOT}`);
  p(`claude:     ${isClaudeAvailable() ? "connected" : "not found"}\n`);

  p("sandbox:");
  for (const cat of ["docs", "outputs", "analysis", "insights"] as const)
    p(`  ${cat}: ${listFiles(cat).length}`);

  const ms = memoryTools.memoryStats();
  p(`\nmemory:     ${ms.shortTerm} short, ${ms.longTerm} long`);

  const ks = knowledgeTools.knowledgeStats();
  p(`knowledge:  ${ks.projects} projects, ${ks.integrations} channels, ${ks.archives} archives`);
}

// ── deepthink ask ──

async function cmdAsk() {
  const question = args.slice(1).filter((a) => !a.startsWith("--")).join(" ");
  if (!question) err("usage: deepthink ask <question> [--file path] [--recall] [--project name]");

  let context = "";
  const file = flagVal("--file");
  if (file) context = fileTools.readFile(file);

  if (flag("--recall")) {
    const mem = memoryTools.recall(question);
    if (mem !== "No memories found.") context += `\n\nMemories:\n${mem}`;
  }

  const proj = flagVal("--project");
  if (proj) {
    const pk = knowledgeTools.loadProjectKnowledge(proj);
    if (pk.context) context += `\n\nProject knowledge:\n${pk.context.slice(0, 3000)}`;
  }

  const resp = context
    ? await query(`Context:\n${context}\n\nQuestion: ${question}`, "Answer based on context. Be concise.")
    : await query(question);
  p(resp);
}

// ── deepthink run ──

async function cmdRun() {
  const task = args.slice(1).filter((a) => !a.startsWith("--")).join(" ");
  if (!task) err("usage: deepthink run <task> [--project name] [--no-docs]");

  p(`task: ${task}\n`);

  const planner = new Planner();
  const steps = await planner.plan(task);
  steps.forEach((s) => p(`  ${s.step}. ${s.action}`));
  p("");

  const executor = new Executor();
  const results = await executor.executePlan(steps);
  results.forEach((r) => p(`  [${r.status}] ${r.step}: ${r.result.slice(0, 200)}`));

  const done = results.filter((r) => r.status === "done");
  const summaryText = done.map((r) => r.result).join("\n");

  if (summaryText && !flag("--no-docs")) {
    const writer = new Writer();
    const ts = new Date().toISOString().replace(/[:.]/g, "").slice(0, 15);
    const path = await writer.writeSummary(summaryText, `task_${ts}.md`);
    ok(`summary: ${path}`);
  }

  const proj = flagVal("--project");
  if (proj && summaryText) {
    knowledgeTools.saveProjectKnowledge(proj, `Task: ${task}\n\n${summaryText}`);
    ok(`saved to project: ${proj}`);
  }

  memoryTools.saveMemory(`Task: ${task} | ${done.length}/${steps.length} done`, ["task"], "short");
  ok("done");
}

// ── deepthink memory ──

function cmdMemory() {
  if (!sub || sub === "stats") {
    const s = memoryTools.memoryStats();
    p(`short-term: ${s.shortTerm}\nlong-term:  ${s.longTerm}`);
    return;
  }

  if (sub === "save") {
    const content = args[2];
    if (!content) err("usage: deepthink memory save <text> [--tags t1,t2] [--layer short|long]");
    const tags = flagVal("--tags")?.split(",").map((t) => t.trim()) ?? [];
    const layer = (flagVal("--layer") ?? "short") as "short" | "long";
    const id = memoryTools.saveMemory(content, tags, layer);
    ok(`saved (${id}) to ${layer}-term`);
    return;
  }

  if (sub === "recall") {
    const q = args.slice(2).join(" ");
    p(memoryTools.recall(q));
    return;
  }

  if (sub === "clear") {
    memoryTools.clearShortTerm();
    ok("short-term cleared");
    return;
  }

  err(`unknown: deepthink memory ${sub}`);
}

// ── deepthink knowledge ──

async function cmdKnowledge() {
  if (!sub || sub === "stats") {
    const s = knowledgeTools.knowledgeStats();
    p(`projects:     ${s.projects}\nintegrations: ${s.integrations}\narchives:     ${s.archives}`);
    return;
  }

  if (sub === "save") {
    const proj = args[2], content = args[3];
    if (!proj || !content) err("usage: deepthink knowledge save <project> <content> [--type context|decision|artifact]");
    const type = (flagVal("--type") ?? "context") as "context" | "decision" | "artifact";
    const path = knowledgeTools.saveProjectKnowledge(proj, content, type);
    ok(`${proj}: ${path}`);
    return;
  }

  if (sub === "load") {
    const proj = args[2];
    if (!proj) err("usage: deepthink knowledge load <project>");
    const pk = knowledgeTools.loadProjectKnowledge(proj);
    if (pk.context) p(pk.context.slice(0, 3000));
    if (pk.decisions) p(`\ndecisions:\n${pk.decisions.slice(0, 1000)}`);
    if (pk.artifacts.length > 0) p(`\nartifacts: ${pk.artifacts.join(", ")}`);
    if (!pk.context && !pk.decisions && pk.artifacts.length === 0) p("empty");
    return;
  }

  if (sub === "list") {
    const projects = knowledgeTools.listProjects();
    if (projects.length === 0) { p("no projects"); return; }
    projects.forEach((pr) => p(`  ${pr}`));
    return;
  }

  if (sub === "capture") {
    const source = args[2], channel = args[3], content = args[4];
    if (!source || !channel || !content) err("usage: deepthink knowledge capture <source> <channel> <content>");
    const path = knowledgeTools.saveIntegrationData(source, channel, content);
    ok(`${source}/${channel}: ${path}`);
    return;
  }

  if (sub === "integrations") {
    const list = knowledgeTools.listIntegrations();
    if (list.length === 0) { p("no integrations"); return; }
    for (const i of list) {
      p(`${i.source}/`);
      i.channels.forEach((ch) => p(`  ${ch}`));
    }
    return;
  }

  if (sub === "compress") {
    const source = args[2], channel = args[3];
    if (!source || !channel) err("usage: deepthink knowledge compress <source> <channel>");
    const path = await knowledgeTools.compressKnowledge(source, channel);
    ok(path);
    return;
  }

  if (sub === "archive") {
    const proj = args[2];
    if (!proj) err("usage: deepthink knowledge archive <project>");
    const path = await knowledgeTools.archiveProject(proj);
    ok(path);
    return;
  }

  err(`unknown: deepthink knowledge ${sub}`);
}

// ── deepthink search ──

async function cmdSearch() {
  if (sub === "local") {
    const q = args[2];
    if (!q) err("usage: deepthink search local <query> [--dir path]");
    const dir = flagVal("--dir") ?? ".";
    const results = search.searchLocal(q, dir);
    p(results.length > 0 ? results.map((r) => `  ${r}`).join("\n") : "no results");
    return;
  }

  const q = args.slice(1).filter((a) => !a.startsWith("--")).join(" ");
  if (!q) err("usage: deepthink search <query>");

  const results = await search.searchWeb(q);
  for (const r of results) {
    p(`${r.title}`);
    if (r.url) p(`  ${r.url}`);
    p(`  ${r.snippet}\n`);
  }
}

// ── deepthink analyze ──

async function cmdAnalyze() {
  const isQuick = sub === "quick";
  const file = isQuick ? args[2] : sub;
  if (!file) err("usage: deepthink analyze <file> [--question q] [--report]");

  const analyst = new Analyst();

  if (isQuick) {
    p(analyst.quickStats(file));
    return;
  }

  if (flag("--report")) {
    const title = flagVal("--title") ?? "Analysis";
    const result = await analyst.analyzeAndReport(file, title);
    p(result.analysis);
    ok(`report: ${result.report}`);
  } else {
    const question = flagVal("--question");
    p(await analyst.analyze(file, question));
  }
}

// ── deepthink docs ──

async function cmdDocs() {
  const topic = args.slice(1).filter((a) => !a.startsWith("--")).join(" ");
  if (!topic) err("usage: deepthink docs <topic> [--input file] [--output name]");

  const input = flagVal("--input");
  const output = flagVal("--output");
  const context = input ? fileTools.readFile(input) : "";

  const writer = new Writer();
  const path = await writer.writeDoc(topic, context, output);
  ok(`saved: ${path}`);
}

// ── deepthink task ──

function cmdTask() {
  if (!sub || sub === "list") {
    const status = flagVal("--status");
    const priority = flagVal("--priority");
    const project = flagVal("--project");
    const tasks = db.listTasks({ status: status ?? undefined, priority: priority ?? undefined, project: project ?? undefined });
    if (tasks.length === 0) { p("no tasks"); return; }
    for (const t of tasks) {
      const proj = t.projectName ? ` [${t.projectName}]` : "";
      const pts = t.storyPoints ? ` ${t.storyPoints}sp` : "";
      const due = t.dueDate ? ` due:${db.formatDate(t.dueDate).slice(0, 10)}` : "";
      p(`  #${t.pk}  ${t.status.padEnd(11)} ${t.priority.padEnd(6)} ${t.title}${proj}${pts}${due}`);
    }
    return;
  }

  if (sub === "add" || sub === "create") {
    const title = args[2];
    if (!title) err("usage: deepthink task add <title> [--status s] [--priority p] [--points n] [--due YYYY-MM-DD] [--project name]");
    const pk = db.createTask(title, {
      status: flagVal("--status") ?? undefined,
      priority: flagVal("--priority") ?? undefined,
      storyPoints: flagVal("--points") ? parseInt(flagVal("--points")!) : undefined,
      dueDate: flagVal("--due") ?? undefined,
      project: flagVal("--project") ?? undefined,
    });
    ok(`task #${pk}: ${title}`);
    return;
  }

  if (sub === "show") {
    const ref = args[2];
    if (!ref) err("usage: deepthink task show <id|name>");
    const t = db.getTask(ref);
    if (!t) err(`task not found: ${ref}`);
    p(`#${t!.pk}  ${t!.title}`);
    p(`  status:   ${t!.status}`);
    p(`  priority: ${t!.priority}`);
    if (t!.storyPoints) p(`  points:   ${t!.storyPoints}`);
    if (t!.dueDate) p(`  due:      ${db.formatDate(t!.dueDate!)}`);
    if (t!.projectName) p(`  project:  ${t!.projectName}`);
    if (t!.detail) p(`  detail:   ${t!.detail}`);
    p(`  created:  ${db.formatDate(t!.createdAt)}`);
    p(`  modified: ${db.formatDate(t!.modifiedAt)}`);
    return;
  }

  if (sub === "update" || sub === "edit") {
    const ref = args[2];
    if (!ref) err("usage: deepthink task update <id|name> [--title t] [--status s] [--priority p] [--points n] [--due date] [--detail d] [--project name]");
    const t = db.getTask(ref);
    if (!t) err(`task not found: ${ref}`);
    const fields: Record<string, any> = {};
    const title = flagVal("--title"); if (title) fields.title = title;
    const status = flagVal("--status"); if (status) fields.status = status;
    const priority = flagVal("--priority"); if (priority) fields.priority = priority;
    const points = flagVal("--points"); if (points) fields.storyPoints = parseInt(points);
    const due = flagVal("--due"); if (due) fields.dueDate = due === "none" ? null : due;
    const detail = flagVal("--detail"); if (detail) fields.detail = detail;
    const project = flagVal("--project"); if (project) fields.project = project;
    db.updateTask(t!.pk, fields);
    ok(`task #${t!.pk} updated`);
    return;
  }

  if (sub === "done") {
    const ref = args[2];
    if (!ref) err("usage: deepthink task done <id|name>");
    const t = db.getTask(ref);
    if (!t) err(`task not found: ${ref}`);
    db.updateTask(t!.pk, { status: "Done" });
    ok(`task #${t!.pk} done`);
    return;
  }

  if (sub === "delete" || sub === "rm") {
    const ref = args[2];
    if (!ref) err("usage: deepthink task delete <id|name>");
    const t = db.getTask(ref);
    if (!t) err(`task not found: ${ref}`);
    db.deleteTask(t!.pk);
    ok(`task #${t!.pk} deleted`);
    return;
  }

  err(`unknown: deepthink task ${sub}`);
}

// ── deepthink note ──

function cmdNote() {
  if (!sub || sub === "list") {
    const project = flagVal("--project");
    const pinned = flag("--pinned") ? true : undefined;
    const notes = db.listNotes({ project: project ?? undefined, pinned });
    if (notes.length === 0) { p("no notes"); return; }
    for (const n of notes) {
      const proj = n.projectName ? ` [${n.projectName}]` : "";
      const pin = n.isPinned ? " 📌" : "";
      p(`  #${n.pk}  ${n.title}${proj}${pin}`);
    }
    return;
  }

  if (sub === "add" || sub === "create") {
    const title = args[2];
    if (!title) err("usage: deepthink note add <title> [--content text] [--pinned] [--project name]");
    const pk = db.createNote(title, {
      content: flagVal("--content") ?? undefined,
      pinned: flag("--pinned"),
      project: flagVal("--project") ?? undefined,
    });
    ok(`note #${pk}: ${title}`);
    return;
  }

  if (sub === "show") {
    const ref = args[2];
    if (!ref) err("usage: deepthink note show <id|name>");
    const n = db.getNote(ref);
    if (!n) err(`note not found: ${ref}`);
    p(`#${n!.pk}  ${n!.title}${n!.isPinned ? " (pinned)" : ""}`);
    if (n!.projectName) p(`  project:  ${n!.projectName}`);
    p(`  created:  ${db.formatDate(n!.createdAt)}`);
    p(`  modified: ${db.formatDate(n!.modifiedAt)}`);
    if (n!.content) { p(""); p(n!.content); }
    return;
  }

  if (sub === "update" || sub === "edit") {
    const ref = args[2];
    if (!ref) err("usage: deepthink note update <id|name> [--title t] [--content text] [--pinned] [--unpinned] [--project name]");
    const n = db.getNote(ref);
    if (!n) err(`note not found: ${ref}`);
    const fields: Record<string, any> = {};
    const title = flagVal("--title"); if (title) fields.title = title;
    const content = flagVal("--content"); if (content) fields.content = content;
    if (flag("--pinned")) fields.pinned = true;
    if (flag("--unpinned")) fields.pinned = false;
    const project = flagVal("--project"); if (project) fields.project = project;
    db.updateNote(n!.pk, fields);
    ok(`note #${n!.pk} updated`);
    return;
  }

  if (sub === "delete" || sub === "rm") {
    const ref = args[2];
    if (!ref) err("usage: deepthink note delete <id|name>");
    const n = db.getNote(ref);
    if (!n) err(`note not found: ${ref}`);
    db.deleteNote(n!.pk);
    ok(`note #${n!.pk} deleted`);
    return;
  }

  err(`unknown: deepthink note ${sub}`);
}

// ── deepthink project ──

function cmdProject() {
  if (!sub || sub === "list") {
    const projects = db.listProjects();
    if (projects.length === 0) { p("no projects"); return; }
    for (const pr of projects) {
      const archived = pr.isArchived ? " (archived)" : "";
      p(`  #${pr.pk}  ${pr.name}  ${pr.taskCount}t ${pr.noteCount}n${archived}`);
    }
    return;
  }

  if (sub === "add" || sub === "create") {
    const name = args[2];
    if (!name) err("usage: deepthink project add <name> [--summary text] [--color hex]");
    const pk = db.createProject(name, {
      summary: flagVal("--summary") ?? undefined,
      color: flagVal("--color") ?? undefined,
    });
    ok(`project #${pk}: ${name}`);
    return;
  }

  if (sub === "show") {
    const ref = args[2];
    if (!ref) err("usage: deepthink project show <id|name>");
    const pr = db.getProject(ref);
    if (!pr) err(`project not found: ${ref}`);
    p(`#${pr!.pk}  ${pr!.name}`);
    if (pr!.summary) p(`  summary:  ${pr!.summary}`);
    p(`  color:    ${pr!.color}`);
    p(`  tasks:    ${pr!.taskCount}`);
    p(`  notes:    ${pr!.noteCount}`);
    p(`  archived: ${pr!.isArchived}`);
    p(`  created:  ${db.formatDate(pr!.createdAt)}`);
    p(`  modified: ${db.formatDate(pr!.modifiedAt)}`);
    return;
  }

  if (sub === "update" || sub === "edit") {
    const ref = args[2];
    if (!ref) err("usage: deepthink project update <id|name> [--name n] [--summary s] [--color hex] [--archive] [--unarchive]");
    const pr = db.getProject(ref);
    if (!pr) err(`project not found: ${ref}`);
    const fields: Record<string, any> = {};
    const name = flagVal("--name"); if (name) fields.name = name;
    const summary = flagVal("--summary"); if (summary) fields.summary = summary;
    const color = flagVal("--color"); if (color) fields.color = color;
    if (flag("--archive")) fields.archived = true;
    if (flag("--unarchive")) fields.archived = false;
    db.updateProject(pr!.pk, fields);
    ok(`project #${pr!.pk} updated`);
    return;
  }

  if (sub === "delete" || sub === "rm") {
    const ref = args[2];
    if (!ref) err("usage: deepthink project delete <id|name>");
    const pr = db.getProject(ref);
    if (!pr) err(`project not found: ${ref}`);
    db.deleteProject(pr!.pk);
    ok(`project #${pr!.pk} deleted`);
    return;
  }

  err(`unknown: deepthink project ${sub}`);
}

// ── deepthink workspace ──

async function cmdWorkspace() {
  const { WorkspaceAgent } = await import("./agents/workspace");
  const request = args.slice(1).filter((a) => !a.startsWith("--")).join(" ");
  if (!request) err("usage: deepthink workspace <natural language request>\n  example: deepthink workspace \"create a high-priority task for API migration due Friday\"");

  const agent = new WorkspaceAgent();
  const result = await agent.handle(request);
  p(result);
}

// ── help ──

function cmdHelp() {
  p(`deepthink — local AI workspace

  deepthink status                                system overview
  deepthink ask <question>                        ask anything
    --file <path>  --recall  --project <name>

  deepthink run <task>                            multi-step task
    --project <name>  --no-docs

  deepthink memory save <text>                    save memory
    --tags t1,t2  --layer short|long
  deepthink memory recall <query>                 search memories
  deepthink memory stats                          counts
  deepthink memory clear                          clear short-term

  deepthink knowledge save <proj> <content>       save to project
    --type context|decision|artifact
  deepthink knowledge load <proj>                 view project
  deepthink knowledge list                        list projects
  deepthink knowledge capture <src> <ch> <text>   capture data
  deepthink knowledge integrations                list sources
  deepthink knowledge compress <src> <ch>         compress data
  deepthink knowledge archive <proj>              archive project
  deepthink knowledge stats                       overview

  deepthink task list                              list tasks
    --status <s>  --priority <p>  --project <name>
  deepthink task add <title>                      create task
    --status <s>  --priority <p>  --points <n>
    --due <YYYY-MM-DD>  --project <name>
  deepthink task show <id|name>                   view task
  deepthink task update <id|name>                 update task
    --title  --status  --priority  --points
    --due  --detail  --project
  deepthink task done <id|name>                   mark done
  deepthink task delete <id|name>                 delete task

  deepthink note list                             list notes
    --project <name>  --pinned
  deepthink note add <title>                      create note
    --content <text>  --pinned  --project <name>
  deepthink note show <id|name>                   view note
  deepthink note update <id|name>                 update note
    --title  --content  --pinned  --unpinned  --project
  deepthink note delete <id|name>                 delete note

  deepthink project list                          list projects
  deepthink project add <name>                    create project
    --summary <text>  --color <hex>
  deepthink project show <id|name>                view project
  deepthink project update <id|name>              update project
    --name  --summary  --color  --archive  --unarchive
  deepthink project delete <id|name>              delete project

  deepthink workspace <request>                    AI workspace agent
  deepthink ws <request>                          (alias)
    natural language task/note/project management

  deepthink search <query>                        web search
  deepthink search local <query>                  local files
    --dir <path>

  deepthink analyze <file>                        AI analysis
    --question <q>  --report  --title <t>
  deepthink analyze quick <file>                  local stats

  deepthink docs <topic>                          generate docs
    --input <file>  --output <name>
`);
}

// ── dispatch ──

const dispatch: Record<string, () => Promise<void> | void> = {
  status: cmdStatus,
  ask: cmdAsk,
  run: cmdRun,
  memory: cmdMemory,
  knowledge: cmdKnowledge,
  task: cmdTask,
  note: cmdNote,
  project: cmdProject,
  workspace: cmdWorkspace,
  ws: cmdWorkspace,
  search: cmdSearch,
  analyze: cmdAnalyze,
  docs: cmdDocs,
  help: cmdHelp,
  "--help": cmdHelp,
  "-h": cmdHelp,
};

async function main() {
  if (!cmd || !(cmd in dispatch)) {
    cmdHelp();
    process.exit(cmd ? 1 : 0);
  }
  try {
    await dispatch[cmd]();
  } catch (e: any) {
    console.error(`✗ ${e.message ?? e}`);
    process.exit(1);
  }
}

main();
