#!/usr/bin/env bun
import { version as pkgVersion } from "../package.json";
import { Analyst } from "./agents/analyst";
import { Executor } from "./agents/executor";
import { Planner } from "./agents/planner";
import { Writer } from "./agents/writer";
import { DEEPTHINK_ROOT } from "./config";
import { retrieveContext, retrieveContextHybrid, workspaceContext } from "./core/context-engine";
import * as db from "./core/db";
import { indexEntry, semanticSearch } from "./core/embedding-service";
import { isClaudeAvailable, query } from "./core/llm";
import { initSandbox, listFiles } from "./core/sandbox";
import * as fileTools from "./tools/file";
import * as knowledgeTools from "./tools/knowledge";
import * as search from "./tools/search";

initSandbox();

const args = process.argv.slice(2);
const cmd = args[0];
const sub = args[1];

const p = (t: string) => console.log(t);
const ok = (t: string) => console.log(`✓ ${t}`);
function err(t: string): never {
  console.error(`✗ ${t}`);
  process.exit(1);
}
const flag = (f: string) => args.includes(f);
const flagVal = (f: string) => {
  const i = args.indexOf(f);
  return i !== -1 ? args[i + 1] : undefined;
};

// ── deepthink status ──

function cmdStatus() {
  p("deepthink\n");
  p(`root:       ${DEEPTHINK_ROOT}`);
  p(`claude:     ${isClaudeAvailable() ? "connected" : "not found"}\n`);

  p("sandbox:");
  for (const cat of ["docs", "outputs", "analysis", "insights"] as const) p(`  ${cat}: ${listFiles(cat).length}`);

  const ks = knowledgeTools.knowledgeStats();
  p(`\nknowledge:  ${ks.projects} projects, ${ks.integrations} channels, ${ks.archives} archives`);
}

// ── deepthink ask ──

async function cmdAsk() {
  const question = args
    .slice(1)
    .filter((a) => !a.startsWith("--"))
    .join(" ");
  if (!question) err("usage: deepthink ask <question> [--file path] [--recall] [--project name]");

  let context = "";
  const file = flagVal("--file");
  if (file) context = fileTools.readFile(file);

  if (flag("--recall")) {
    const kr = retrieveContextHybrid(question, { maxTokens: 3000 });
    if (kr.parts.length > 0) {
      context += `\n\nKnowledge:\n${kr.parts.map((p) => `## ${p.title}\n${p.content}`).join("\n\n")}`;
    }
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
  const task = args
    .slice(1)
    .filter((a) => !a.startsWith("--"))
    .join(" ");
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

  knowledgeTools.saveIntegrationData("agent", "task-runs", `Task: ${task} | ${done.length}/${steps.length} done`);
  ok("done");
}

// ── deepthink knowledge ──

async function cmdKnowledge() {
  const json = flag("--json");

  if (!sub || sub === "stats") {
    const s = knowledgeTools.knowledgeStats();
    if (json) {
      p(JSON.stringify(s));
      return;
    }
    p(`projects:     ${s.projects}\nintegrations: ${s.integrations}\narchives:     ${s.archives}`);
    return;
  }

  if (sub === "search") {
    const q = args
      .slice(2)
      .filter((a) => !a.startsWith("--"))
      .join(" ");
    if (!q) err("usage: deepthink knowledge search <query> [--source s] [--limit n] [--json]");
    const source = flagVal("--source");
    const limit = flagVal("--limit") ? parseInt(flagVal("--limit")!, 10) : 20;
    const results = knowledgeTools.searchIntegrationData(q, source ?? undefined, limit);
    if (json) {
      p(JSON.stringify(results));
      return;
    }
    for (const r of results) {
      p(`${r.source}/${r.channel}: ${r.file}`);
      p(`  ${r.content.slice(0, 100)}...\n`);
    }
    return;
  }

  if (sub === "save") {
    const proj = args[2],
      content = args[3];
    if (!proj || !content)
      err("usage: deepthink knowledge save <project> <content> [--type context|decision|artifact]");
    const type = (flagVal("--type") ?? "context") as "context" | "decision" | "artifact";
    const path = knowledgeTools.saveProjectKnowledge(proj, content, type);
    if (json) {
      p(JSON.stringify({ project: proj, path }));
      return;
    }
    ok(`${proj}: ${path}`);
    return;
  }

  if (sub === "load") {
    const proj = args[2];
    if (!proj) err("usage: deepthink knowledge load <project>");
    const pk = knowledgeTools.loadProjectKnowledge(proj);
    if (json) {
      p(JSON.stringify(pk));
      return;
    }
    if (pk.context) p(pk.context.slice(0, 3000));
    if (pk.decisions) p(`\ndecisions:\n${pk.decisions.slice(0, 1000)}`);
    if (pk.artifacts.length > 0) p(`\nartifacts: ${pk.artifacts.join(", ")}`);
    if (!pk.context && !pk.decisions && pk.artifacts.length === 0) p("empty");
    return;
  }

  if (sub === "list") {
    const projects = knowledgeTools.listProjects();
    if (json) {
      p(JSON.stringify(projects));
      return;
    }
    if (projects.length === 0) {
      p("no projects");
      return;
    }
    projects.forEach((pr) => p(`  ${pr}`));
    return;
  }

  if (sub === "capture") {
    const source = args[2],
      channel = args[3],
      content = args[4];
    if (!source || !channel || !content)
      err("usage: deepthink knowledge capture <source> <channel> <content> [--title t] [--tags t1,t2]");
    const title = flagVal("--title");
    const tagsRaw = flagVal("--tags");
    const tags = tagsRaw
      ? tagsRaw
          .split(",")
          .map((t) => t.trim())
          .filter(Boolean)
      : undefined;
    const path = knowledgeTools.saveIntegrationData(source, channel, content, {}, title, tags);
    if (json) {
      p(JSON.stringify({ source, channel, title, path }));
      return;
    }
    ok(`${source}/${channel}: ${path}`);
    return;
  }

  if (sub === "integrations") {
    const list = knowledgeTools.listIntegrations();
    if (json) {
      p(JSON.stringify(list));
      return;
    }
    if (list.length === 0) {
      p("no integrations");
      return;
    }
    for (const i of list) {
      p(`${i.source}/`);
      i.channels.forEach((ch) => p(`  ${ch}`));
    }
    return;
  }

  if (sub === "compress") {
    const source = args[2],
      channel = args[3];
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

// ── deepthink context ──

function cmdContext() {
  const json = flag("--json");
  const q = args
    .slice(1)
    .filter((a) => !a.startsWith("--"))
    .join(" ");

  if (!sub || sub === "overview") {
    const ws = {
      projects: db.listProjects(),
      tasks: db.listTasks(),
      notes: db.listNotes(),
      reminders: db.listReminders(),
    };
    const ks = knowledgeTools.knowledgeStats();

    if (json) {
      p(
        JSON.stringify({
          workspace: {
            projects: ws.projects.length,
            tasks: {
              total: ws.tasks.length,
              byStatus: ws.tasks.reduce(
                (a, t) => {
                  a[t.status] = (a[t.status] ?? 0) + 1;
                  return a;
                },
                {} as Record<string, number>
              ),
            },
            notes: ws.notes.length,
            reminders: ws.reminders.length,
            recentTasks: ws.tasks.slice(0, 3).map((t) => `[${t.status}] ${t.title}`),
          },
          knowledge: ks,
        })
      );
      return;
    }

    p("deepthink overview\n");
    p(`  projects:  ${ws.projects.length}`);
    const byStatus = ws.tasks.reduce(
      (a, t) => {
        a[t.status] = (a[t.status] ?? 0) + 1;
        return a;
      },
      {} as Record<string, number>
    );
    p(
      `  tasks:     ${ws.tasks.length} (${Object.entries(byStatus)
        .map(([k, v]) => `${v} ${k}`)
        .join(", ")})`
    );
    p(`  notes:     ${ws.notes.length}`);
    p(`  reminders: ${ws.reminders.length}`);
    p(`  knowledge: ${ks.projects} projects, ${ks.integrations} channels, ${ks.archives} archives`);
    if (ws.tasks.length > 0) {
      p("\n  recent tasks:");
      ws.tasks.slice(0, 5).forEach((t) => p(`    [${t.status.padEnd(11)}] ${t.title}`));
    }
    return;
  }

  if (sub === "semantic" || sub === "sem") {
    if (!q) err("usage: deepthink context semantic <query> [--top n] [--json]");
    const topK = flagVal("--top") ? parseInt(flagVal("--top")!, 10) : 10;
    const results = semanticSearch(q, topK);
    if (json) {
      p(JSON.stringify(results));
      return;
    }
    if (results.length === 0) {
      p("semantic: no results (embeddings may not be indexed yet)");
      return;
    }
    p(`semantic search (${results.length} results):\n`);
    for (const r of results) {
      p(`  [${r.score.toFixed(4)}] ${r.entryID}`);
    }
    return;
  }

  if (sub === "query" || sub === "q") {
    if (!q) err("usage: deepthink context query <question> [--tokens n] [--project name] [--bm25] [--json]");
    const maxTokens = flagVal("--tokens") ? parseInt(flagVal("--tokens")!, 10) : 4000;
    const projectScope = flagVal("--project") ?? undefined;
    const bm25Only = flag("--bm25");

    const kr = bm25Only
      ? retrieveContext(q, { maxTokens, projectScope })
      : retrieveContextHybrid(q, { maxTokens, projectScope });
    const ws = workspaceContext(q, 5);

    if (json) {
      p(JSON.stringify({ knowledge: kr, workspace: ws }));
      return;
    }

    if (kr.parts.length > 0) {
      p(`knowledge (${kr.entriesReturned}/${kr.entriesScanned} entries, ~${kr.totalTokensEstimate} tokens):\n`);
      for (const part of kr.parts) {
        p(`  [${part.score}] ${part.title}`);
        if (part.tags.length > 0) p(`    tags: ${part.tags.join(", ")}`);
        p(`    ${part.content.slice(0, 150)}...`);
        p("");
      }
    } else {
      p("knowledge: no relevant entries\n");
    }

    if (ws.tasks.length > 0) {
      p("relevant tasks:");
      ws.tasks.forEach((t) => p(`  [${t.score}] ${t.status.padEnd(11)} ${t.title}`));
    }
    if (ws.notes.length > 0) {
      p("relevant notes:");
      ws.notes.forEach((n) => p(`  [${n.score}] ${n.title}`));
    }
    return;
  }

  if (sub === "workspace" || sub === "ws") {
    if (!q) err("usage: deepthink context workspace <query> [--limit n] [--json]");
    const maxItems = flagVal("--limit") ? parseInt(flagVal("--limit")!, 10) : 5;
    const ws = workspaceContext(q, maxItems);
    if (json) {
      p(JSON.stringify(ws));
      return;
    }
    p(`workspace context (~${ws.totalTokensEstimate} tokens):\n`);
    if (ws.tasks.length > 0) {
      p("  tasks:");
      ws.tasks.forEach((t) => p(`    [${t.score}] ${t.status.padEnd(11)} ${t.priority.padEnd(6)} ${t.title}`));
    }
    if (ws.notes.length > 0) {
      p("  notes:");
      ws.notes.forEach((n) => p(`    [${n.score}] ${n.title}${n.project ? ` (${n.project})` : ""}`));
    }
    if (ws.reminders.length > 0) {
      p("  reminders:");
      ws.reminders.forEach((r) => p(`    [${r.score}] ${r.title}`));
    }
    return;
  }

  if (sub === "knowledge" || sub === "kb") {
    if (!q) err("usage: deepthink context knowledge <query> [--tokens n] [--project name] [--top n] [--json]");
    const maxTokens = flagVal("--tokens") ? parseInt(flagVal("--tokens")!, 10) : 4000;
    const projectScope = flagVal("--project") ?? undefined;
    const topK = flagVal("--top") ? parseInt(flagVal("--top")!, 10) : 10;
    const kr = retrieveContext(q, { maxTokens, projectScope, topK });
    if (json) {
      p(JSON.stringify(kr));
      return;
    }
    p(`knowledge context (${kr.entriesReturned}/${kr.entriesScanned} entries, ~${kr.totalTokensEstimate} tokens):\n`);
    for (const part of kr.parts) {
      p(`  [${part.score}] ${part.title} (${part.source})`);
      if (part.tags.length > 0) p(`    tags: ${part.tags.join(", ")}`);
      p(`    ${part.content.slice(0, 200)}...`);
      p("");
    }
    if (kr.parts.length === 0) p("  no relevant entries");
    return;
  }

  err(`unknown: deepthink context ${sub}`);
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

  const q = args
    .slice(1)
    .filter((a) => !a.startsWith("--"))
    .join(" ");
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
  const topic = args
    .slice(1)
    .filter((a) => !a.startsWith("--"))
    .join(" ");
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
    const tasks = db.listTasks({
      status: status ?? undefined,
      priority: priority ?? undefined,
      project: project ?? undefined,
    });
    if (tasks.length === 0) {
      p("no tasks");
      return;
    }
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
    if (!title)
      err(
        "usage: deepthink task add <title> [--status s] [--priority p] [--points n] [--due YYYY-MM-DD] [--project name]"
      );
    const pk = db.createTask(title, {
      status: flagVal("--status") ?? undefined,
      priority: flagVal("--priority") ?? undefined,
      storyPoints: flagVal("--points") ? parseInt(flagVal("--points")!, 10) : undefined,
      dueDate: flagVal("--due") ?? undefined,
      project: flagVal("--project") ?? undefined,
    });
    indexEntry({
      id: `task:${pk}`,
      type: "task",
      title,
      content: flagVal("--detail") ?? "",
      tags: [],
      source: "task",
      importedAt: new Date(),
    });
    ok(`task #${pk}: ${title}`);
    return;
  }

  if (sub === "show") {
    const ref = args[2];
    if (!ref) err("usage: deepthink task show <id|name>");
    const t = db.getTask(ref);
    if (!t) err(`task not found: ${ref}`);
    p(`#${t.pk}  ${t.title}`);
    p(`  status:   ${t.status}`);
    p(`  priority: ${t.priority}`);
    if (t.storyPoints) p(`  points:   ${t.storyPoints}`);
    if (t.dueDate) p(`  due:      ${db.formatDate(t.dueDate)}`);
    if (t.projectName) p(`  project:  ${t.projectName}`);
    if (t.detail) p(`  detail:   ${t.detail}`);
    p(`  created:  ${db.formatDate(t.createdAt)}`);
    p(`  modified: ${db.formatDate(t.modifiedAt)}`);
    return;
  }

  if (sub === "update" || sub === "edit") {
    const ref = args[2];
    if (!ref)
      err(
        "usage: deepthink task update <id|name> [--title t] [--status s] [--priority p] [--points n] [--due date] [--detail d] [--project name]"
      );
    const t = db.getTask(ref);
    if (!t) err(`task not found: ${ref}`);
    if (t?.isArchived) err(`task is archived and cannot be edited. Unarchive it first.`);
    const fields: Record<string, any> = {};
    const title = flagVal("--title");
    if (title) fields.title = title;
    const status = flagVal("--status");
    if (status) fields.status = status;
    const priority = flagVal("--priority");
    if (priority) fields.priority = priority;
    const points = flagVal("--points");
    if (points) fields.storyPoints = parseInt(points, 10);
    const due = flagVal("--due");
    if (due) fields.dueDate = due === "none" ? null : due;
    const detail = flagVal("--detail");
    if (detail) fields.detail = detail;
    const project = flagVal("--project");
    if (project) fields.project = project;
    db.updateTask(t.pk, fields);
    const updatedTask = db.getTask(t.pk.toString());
    if (updatedTask)
      indexEntry({
        id: `task:${updatedTask.pk}`,
        type: "task",
        title: updatedTask.title,
        content: updatedTask.detail,
        tags: [],
        source: "task",
        importedAt: updatedTask.modifiedAt,
      });
    ok(`task #${t.pk} updated`);
    return;
  }

  if (sub === "done") {
    const ref = args[2];
    if (!ref) err("usage: deepthink task done <id|name>");
    const t = db.getTask(ref);
    if (!t) err(`task not found: ${ref}`);
    db.updateTask(t.pk, { status: "Done" });
    ok(`task #${t.pk} done`);
    return;
  }

  if (sub === "delete" || sub === "rm") {
    const ref = args[2];
    if (!ref) err("usage: deepthink task delete <id|name>");
    const t = db.getTask(ref);
    if (!t) err(`task not found: ${ref}`);
    db.deleteTask(t.pk);
    ok(`task #${t.pk} deleted`);
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
    if (notes.length === 0) {
      p("no notes");
      return;
    }
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
    indexEntry({
      id: `note:${pk}`,
      type: "note",
      title,
      content: flagVal("--content") ?? "",
      tags: [],
      source: "note",
      importedAt: new Date(),
    });
    ok(`note #${pk}: ${title}`);
    return;
  }

  if (sub === "show") {
    const ref = args[2];
    if (!ref) err("usage: deepthink note show <id|name>");
    const n = db.getNote(ref);
    if (!n) err(`note not found: ${ref}`);
    p(`#${n.pk}  ${n.title}${n.isPinned ? " (pinned)" : ""}`);
    if (n.projectName) p(`  project:  ${n.projectName}`);
    p(`  created:  ${db.formatDate(n.createdAt)}`);
    p(`  modified: ${db.formatDate(n.modifiedAt)}`);
    if (n.content) {
      p("");
      p(n.content);
    }
    return;
  }

  if (sub === "update" || sub === "edit") {
    const ref = args[2];
    if (!ref)
      err(
        "usage: deepthink note update <id|name> [--title t] [--content text] [--pinned] [--unpinned] [--project name]"
      );
    const n = db.getNote(ref);
    if (!n) err(`note not found: ${ref}`);
    if (n?.isArchived) err(`note is archived and cannot be edited. Unarchive it first.`);
    const fields: Record<string, any> = {};
    const title = flagVal("--title");
    if (title) fields.title = title;
    const content = flagVal("--content");
    if (content) fields.content = content;
    if (flag("--pinned")) fields.pinned = true;
    if (flag("--unpinned")) fields.pinned = false;
    const project = flagVal("--project");
    if (project) fields.project = project;
    db.updateNote(n.pk, fields);
    const updatedNote = db.getNote(n.pk.toString());
    if (updatedNote)
      indexEntry({
        id: `note:${updatedNote.pk}`,
        type: "note",
        title: updatedNote.title,
        content: updatedNote.content,
        tags: [],
        source: "note",
        importedAt: updatedNote.modifiedAt,
      });
    ok(`note #${n.pk} updated`);
    return;
  }

  if (sub === "delete" || sub === "rm") {
    const ref = args[2];
    if (!ref) err("usage: deepthink note delete <id|name>");
    const n = db.getNote(ref);
    if (!n) err(`note not found: ${ref}`);
    db.deleteNote(n.pk);
    ok(`note #${n.pk} deleted`);
    return;
  }

  err(`unknown: deepthink note ${sub}`);
}

// ── deepthink project ──

function cmdProject() {
  if (!sub || sub === "list") {
    const projects = db.listProjects();
    if (projects.length === 0) {
      p("no projects");
      return;
    }
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
    indexEntry({
      id: `project:${pk}`,
      type: "project",
      title: name,
      content: flagVal("--summary") ?? "",
      tags: [],
      source: "project",
      importedAt: new Date(),
    });
    ok(`project #${pk}: ${name}`);
    return;
  }

  if (sub === "show") {
    const ref = args[2];
    if (!ref) err("usage: deepthink project show <id|name>");
    const pr = db.getProject(ref);
    if (!pr) err(`project not found: ${ref}`);
    p(`#${pr.pk}  ${pr.name}`);
    if (pr.summary) p(`  summary:  ${pr.summary}`);
    p(`  color:    ${pr.color}`);
    p(`  tasks:    ${pr.taskCount}`);
    p(`  notes:    ${pr.noteCount}`);
    p(`  archived: ${pr.isArchived}`);
    p(`  created:  ${db.formatDate(pr.createdAt)}`);
    p(`  modified: ${db.formatDate(pr.modifiedAt)}`);
    return;
  }

  if (sub === "update" || sub === "edit") {
    const ref = args[2];
    if (!ref)
      err("usage: deepthink project update <id|name> [--name n] [--summary s] [--color hex] [--archive] [--unarchive]");
    const pr = db.getProject(ref);
    if (!pr) err(`project not found: ${ref}`);
    const fields: Record<string, any> = {};
    const name = flagVal("--name");
    if (name) fields.name = name;
    const summary = flagVal("--summary");
    if (summary) fields.summary = summary;
    const color = flagVal("--color");
    if (color) fields.color = color;
    if (flag("--archive")) fields.archived = true;
    if (flag("--unarchive")) fields.archived = false;
    db.updateProject(pr.pk, fields);
    const updatedProj = db.getProject(pr.pk.toString());
    if (updatedProj)
      indexEntry({
        id: `project:${updatedProj.pk}`,
        type: "project",
        title: updatedProj.name,
        content: updatedProj.summary,
        tags: [],
        source: "project",
        importedAt: updatedProj.modifiedAt,
      });
    ok(`project #${pr.pk} updated`);
    return;
  }

  if (sub === "delete" || sub === "rm") {
    const ref = args[2];
    if (!ref) err("usage: deepthink project delete <id|name>");
    const pr = db.getProject(ref);
    if (!pr) err(`project not found: ${ref}`);
    db.deleteProject(pr.pk);
    ok(`project #${pr.pk} deleted`);
    return;
  }

  err(`unknown: deepthink project ${sub}`);
}

// ── deepthink react ──

async function cmdReact() {
  const { ReactAgent } = await import("./agents/react");
  const goal = args
    .slice(1)
    .filter((a) => !a.startsWith("--"))
    .join(" ");
  if (!goal) err("usage: deepthink react <goal>");
  const agent = new ReactAgent();
  const { steps, result } = await agent.run(goal);
  for (const s of steps) {
    p(`  [${s.action}] ${s.thought.slice(0, 80)}`);
    if (s.error) p(`    ✗ ${s.observation}`);
  }
  p(`\n✓ ${result}`);
}

// ── deepthink insight ──

async function cmdInsight() {
  const { InsightAgent } = await import("./agents/insight");
  const agent = new InsightAgent();
  if (!sub || sub === "scan") {
    p("Scanning workspace...");
    const insights = await agent.scan();
    if (insights.length === 0) {
      ok("No insights — workspace looks healthy");
      return;
    }
    for (const i of insights) {
      const icon = i.severity === "action" ? "⚡" : i.severity === "warning" ? "⚠" : "ℹ";
      p(`\n${icon} ${i.title}`);
      p(`  ${i.description}`);
      if (i.suggestedAction) p(`  → ${i.suggestedAction}`);
    }
    return;
  }
  if (sub === "list") {
    const insights = agent.listInsights();
    if (insights.length === 0) {
      p("No saved insights. Run: deepthink insight scan");
      return;
    }
    for (const i of insights) p(`[${i.severity}] ${i.title} — ${i.description}`);
    return;
  }
  if (sub === "clear") {
    agent.clearInsights();
    ok("Insights cleared");
    return;
  }
  err(`unknown: deepthink insight ${sub}`);
}

// ── deepthink research ──

async function cmdResearch() {
  const { ResearchPipeline } = await import("./agents/research");
  const topic = args
    .slice(1)
    .filter((a) => !a.startsWith("--"))
    .join(" ");
  if (!topic) err("usage: deepthink research <topic> [--deep] [--project name]");
  const depth = flag("--deep") ? "deep" : "quick";
  const project = flagVal("--project");
  const pipeline = new ResearchPipeline();
  const result = await pipeline.run(topic, { depth, project, saveToKnowledge: true });
  p(`\n## Synthesis\n${result.synthesis}`);
  if (result.savedTo) ok(`Saved to: ${result.savedTo}`);
}

// ── deepthink schedule ──

async function cmdSchedule() {
  const { runScheduledJobs, scheduleStatus } = await import("./agents/scheduler");
  if (!sub || sub === "run") {
    const force = flag("--force");
    p(`Running scheduled jobs${force ? " (forced)" : ""}...`);
    const results = await runScheduledJobs({ force });
    for (const r of results) {
      if (!r.ran) {
        p(`  [skip] ${r.job}`);
        continue;
      }
      if (r.error) p(`  [✗] ${r.job}: ${r.error}`);
      else p(`  [✓] ${r.job}: ${r.result}`);
    }
    return;
  }
  if (sub === "status") {
    const status = scheduleStatus();
    for (const [id, s] of Object.entries(status)) {
      p(`  ${id}: last=${s.lastRun ? s.lastRun.slice(0, 16) : "never"}, next=${s.nextDueIn}`);
    }
    return;
  }
  err(`unknown: deepthink schedule ${sub}`);
}

// ── deepthink workspace ──

async function cmdWorkspace() {
  const { WorkspaceAgent } = await import("./agents/workspace");
  const request = args
    .slice(1)
    .filter((a) => !a.startsWith("--"))
    .join(" ");
  if (!request)
    err(
      'usage: deepthink workspace <natural language request>\n  example: deepthink workspace "create a high-priority task for API migration due Friday"'
    );

  const agent = new WorkspaceAgent();
  const result = await agent.handle(request);
  p(result);
}

// ── help ──

function cmdHelp() {
  p(`deepthink — local AI workspace

  SMART CONTEXT (token-efficient retrieval)
  ─────────────────────────────────────────
  deepthink context overview                      compact system overview (~200 tokens)
  deepthink context query <question>              hybrid retrieval (BM25 + semantic)
    --tokens <n>  --project <name>  --bm25  --json
  deepthink context semantic <query>              pure semantic vector search
    --top <n>  --json
  deepthink context workspace <query>             relevant tasks/notes/reminders only
    --limit <n>  --json
  deepthink context knowledge <query>             BM25-scored knowledge chunks
    --tokens <n>  --project <name>  --top <n>  --json

  GENERAL
  ──────
  deepthink status                                system overview (full)
  deepthink ask <question>                        ask anything
    --file <path>  --recall  --project <name>
  deepthink run <task>                            multi-step task
    --project <name>  --no-docs

  KNOWLEDGE (full data)
  ─────────────────────
  deepthink knowledge save <proj> <content>       save to project
    --type context|decision|artifact
  deepthink knowledge load <proj>                 view project
  deepthink knowledge list                        list projects
  deepthink knowledge search <query>              keyword search
    --source <s>  --limit <n>
  deepthink knowledge capture <src> <ch> <text>   capture data
  deepthink knowledge integrations                list sources
  deepthink knowledge compress <src> <ch>         compress data
  deepthink knowledge archive <proj>              archive project
  deepthink knowledge stats                       overview

  TASKS
  ─────
  deepthink task list                             list tasks
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

  NOTES
  ─────
  deepthink note list                             list notes
    --project <name>  --pinned
  deepthink note add <title>                      create note
    --content <text>  --pinned  --project <name>
  deepthink note show <id|name>                   view note
  deepthink note update <id|name>                 update note
    --title  --content  --pinned  --unpinned  --project
  deepthink note delete <id|name>                 delete note

  PROJECTS
  ────────
  deepthink project list                          list projects
  deepthink project add <name>                    create project
    --summary <text>  --color <hex>
  deepthink project show <id|name>                view project
  deepthink project update <id|name>              update project
    --name  --summary  --color  --archive  --unarchive
  deepthink project delete <id|name>              delete project

  WORKSPACE AGENT
  ───────────────
  deepthink workspace <request>                   AI workspace agent
  deepthink ws <request>                          (alias)
    natural language task/note/project management

  SEARCH
  ──────
  deepthink search <query>                        web search
  deepthink search local <query>                  local files
    --dir <path>

  ANALYSIS
  ────────
  deepthink analyze <file>                        AI analysis
    --question <q>  --report  --title <t>
  deepthink analyze quick <file>                  local stats

  DOCS
  ────
  deepthink docs <topic>                          generate docs
    --input <file>  --output <name>

  MCP TOOLS (via deepthink-mcp)
  ─────────────────────────────
  smart_query          auto-routes: hybrid retrieval (BM25 + semantic)
  knowledge_context    hybrid knowledge retrieval (~90% token savings)
  workspace_context    query-relevant workspace snapshot
  deepthink_overview   compact counts + top items (~200 tokens)
  + all workspace_*, knowledge_*, agent_*, rule_*, skill_* tools
`);
}

// ── dispatch ──

const dispatch: Record<string, () => Promise<void> | void> = {
  status: cmdStatus,
  context: cmdContext,
  ctx: cmdContext,
  ask: cmdAsk,
  run: cmdRun,
  knowledge: cmdKnowledge,
  task: cmdTask,
  note: cmdNote,
  project: cmdProject,
  workspace: cmdWorkspace,
  ws: cmdWorkspace,
  react: cmdReact,
  insight: cmdInsight,
  research: cmdResearch,
  schedule: cmdSchedule,
  search: cmdSearch,
  analyze: cmdAnalyze,
  docs: cmdDocs,
  help: cmdHelp,
  "--help": cmdHelp,
  "-h": cmdHelp,
  version: () => {
    console.log(pkgVersion);
  },
  "--version": () => {
    console.log(pkgVersion);
  },
  "-v": () => {
    console.log(pkgVersion);
  },
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
