#!/usr/bin/env bun
import { SANDBOX_ROOT, MEMORY_DIR } from "./config";
import { initSandbox, listFiles } from "./core/sandbox";
import { query } from "./core/llm";
import { Planner } from "./agents/planner";
import { Executor } from "./agents/executor";
import { Writer } from "./agents/writer";
import { Analyst } from "./agents/analyst";
import * as fileTools from "./tools/file";
import * as search from "./tools/search";
import * as analytics from "./tools/analytics";
import * as memoryTools from "./tools/memory";

initSandbox();

const args = process.argv.slice(2);
const command = args[0];

function print(text: string) {
  console.log(text);
}

function printError(text: string) {
  console.error(`ERROR: ${text}`);
}

function printOk(text: string) {
  console.log(`OK: ${text}`);
}

async function cmdAnalyze() {
  const file = args[1];
  if (!file) { printError("Usage: deepthink analyze <file> [--question <q>]"); process.exit(1); }

  const qIdx = args.indexOf("--question");
  const question = qIdx !== -1 ? args[qIdx + 1] : undefined;

  const hasReport = args.includes("--report");
  const title = args.includes("--title") ? args[args.indexOf("--title") + 1] : "Analysis";

  const analyst = new Analyst();

  if (hasReport) {
    const result = await analyst.analyzeAndReport(file, title);
    print(result.analysis);
    printOk(`Report saved: ${result.report}`);
  } else if (args.includes("--quick")) {
    print(analyst.quickStats(file));
  } else {
    const result = await analyst.analyze(file, question);
    print(result);
  }
}

async function cmdWriteDocs() {
  const topic = args[1];
  if (!topic) { printError("Usage: deepthink write-docs <topic> [--input <file>] [--output <name>]"); process.exit(1); }

  const inputIdx = args.indexOf("--input");
  const outputIdx = args.indexOf("--output");
  const context = inputIdx !== -1 ? fileTools.readFile(args[inputIdx + 1]) : "";
  const output = outputIdx !== -1 ? args[outputIdx + 1] : undefined;

  const writer = new Writer();
  const path = await writer.writeDoc(topic, context, output);
  printOk(`Doc saved: ${path}`);
}

function cmdRecall() {
  const q = args.slice(1).join(" ");
  print(memoryTools.recall(q));
}

function cmdRemember() {
  const content = args[1];
  if (!content) { printError("Usage: deepthink remember <content> [--tags t1,t2] [--layer short|long]"); process.exit(1); }

  const tagsIdx = args.indexOf("--tags");
  const tags = tagsIdx !== -1 ? args[tagsIdx + 1].split(",").map((t) => t.trim()) : [];
  const layerIdx = args.indexOf("--layer");
  const layer = (layerIdx !== -1 ? args[layerIdx + 1] : "short") as "short" | "long";

  const id = memoryTools.saveMemory(content, tags, layer);
  printOk(`Saved to ${layer}-term memory (id: ${id})`);
}

async function cmdSearch() {
  const q = args[1];
  if (!q) { printError("Usage: deepthink search <query> [--local] [--dir <path>]"); process.exit(1); }

  if (args.includes("--local")) {
    const dirIdx = args.indexOf("--dir");
    const dir = dirIdx !== -1 ? args[dirIdx + 1] : ".";
    const results = search.searchLocal(q, dir);
    if (results.length > 0) {
      print(results.map((r) => `- ${r}`).join("\n"));
    } else {
      print("No local results found.");
    }
  } else {
    const results = await search.searchWeb(q);
    for (const r of results) {
      print(`**${r.title}**`);
      if (r.url) print(`  ${r.url}`);
      print(`  ${r.snippet}\n`);
    }
  }
}

async function cmdRun() {
  const taskWords = args.slice(1).filter((a) => !a.startsWith("--"));
  const task = taskWords.join(" ");
  if (!task) { printError("Usage: deepthink run <task description>"); process.exit(1); }

  const noDocs = args.includes("--no-docs");

  print(`## Task: ${task}\n`);

  print("**Planning...**");
  const planner = new Planner();
  const steps = await planner.plan(task);
  for (const s of steps) {
    print(`  ${s.step}. ${s.action}`);
  }
  print("");

  print("**Executing...**");
  const executor = new Executor();
  const results = await executor.executePlan(steps);
  for (const r of results) {
    const status = r.status === "done" ? "done" : "FAIL";
    print(`  [${status}] Step ${r.step}: ${r.result.slice(0, 200)}`);
  }
  print("");

  const summaryText = results
    .filter((r) => r.status === "done")
    .map((r) => r.result)
    .join("\n");

  if (summaryText && !noDocs) {
    print("**Writing summary...**");
    const writer = new Writer();
    const ts = new Date().toISOString().replace(/[:.]/g, "").slice(0, 15);
    const path = await writer.writeSummary(summaryText, `task_${ts}.md`);
    printOk(`Summary: ${path}`);
  }

  memoryTools.saveMemory(
    `Task: ${task} | Steps: ${steps.length} | Done: ${results.filter((r) => r.status === "done").length}`,
    ["task"],
    "short"
  );
  printOk("Done.");
}

async function cmdAsk() {
  const question = args.slice(1).filter((a) => !a.startsWith("--")).join(" ");
  if (!question) { printError("Usage: deepthink ask <question> [--file <path>] [--recall]"); process.exit(1); }

  let context = "";

  const fileIdx = args.indexOf("--file");
  if (fileIdx !== -1) context = fileTools.readFile(args[fileIdx + 1]);

  if (args.includes("--recall")) {
    const mem = memoryTools.recall(question);
    if (mem !== "No memories found.") context += `\n\nRelevant memories:\n${mem}`;
  }

  const response = context
    ? await query(`Context:\n${context}\n\nQuestion: ${question}`, "Answer based on provided context. Be concise and accurate.")
    : await query(question);

  print(response);
}

function cmdMemory() {
  const stats = memoryTools.memoryStats();
  print(`Short-term: ${stats.shortTerm} entries`);
  print(`Long-term: ${stats.longTerm} entries`);
}

function cmdStatus() {
  print("## DeepThink Status\n");
  print(`Sandbox: ${SANDBOX_ROOT}`);
  print(`Memory: ${MEMORY_DIR}\n`);
  for (const cat of ["docs", "outputs", "projects", "insights"] as const) {
    const files = listFiles(cat);
    print(`  ${cat}/: ${files.length} files`);
  }
}

function cmdHelp() {
  print(`deepthink — local AI operating environment

Commands:
  analyze <file>          Analyze file (CSV, JSON, text, code)
    --quick               Quick local stats (no AI)
    --report              Generate report doc
    --question <q>        Ask specific question
    --title <t>           Report title

  write-docs <topic>      Generate documentation
    --input <file>        Source file for context
    --output <name>       Output filename

  recall <query>          Search memory
  remember <text>         Save to memory
    --tags t1,t2          Comma-separated tags
    --layer short|long    Memory layer

  search <query>          Search web or local
    --local               Search local files
    --dir <path>          Directory for local search

  run <task>              Plan + execute multi-step task
    --no-docs             Skip doc generation

  ask <question>          Ask a question
    --file <path>         Context file
    --recall              Include memory context

  memory                  Memory stats
  status                  System status
`);
}

const dispatch: Record<string, () => Promise<void> | void> = {
  analyze: cmdAnalyze,
  "write-docs": cmdWriteDocs,
  recall: cmdRecall,
  remember: cmdRemember,
  search: cmdSearch,
  run: cmdRun,
  ask: cmdAsk,
  memory: cmdMemory,
  status: cmdStatus,
  help: cmdHelp,
  "--help": cmdHelp,
  "-h": cmdHelp,
};

async function main() {
  if (!command || !(command in dispatch)) {
    cmdHelp();
    process.exit(command ? 1 : 0);
  }

  try {
    await dispatch[command]();
  } catch (e: any) {
    printError(e.message ?? String(e));
    process.exit(1);
  }
}

main();
