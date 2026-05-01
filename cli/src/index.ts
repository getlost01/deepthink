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
