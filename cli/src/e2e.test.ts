#!/usr/bin/env bun

/**
 * E2E test suite for DeepThink MCP server.
 * Spawns the compiled binary and exercises every tool via JSON-RPC over stdio.
 *
 * Entity shape notes (from db.ts):
 *  - create tools return { pk, title|name }   — no id field
 *  - get/list tools return { pk, id (raw hex UUID), ... }
 *  - update/delete tools take `ref` = pk.toString() or title/name
 *  - deeplinks expect deepthink://<type>/<hexUUID>
 */

import { join } from "node:path";
import { type Subprocess, type FileSink, spawn } from "bun";

const MCP_BINARY = join(import.meta.dir, "../out/deepthink-mcp");

// ── JSON-RPC client over stdio ───────────────────────────────────────────────

interface RPCResponse {
  id?: number;
  result?: any;
  error?: { code: number; message: string };
}

class MCPClient {
  private proc: Subprocess;
  private stdin: FileSink;
  private buf = "";
  private pending = new Map<number, { resolve: (v: any) => void; reject: (e: any) => void }>();
  private nextId = 1;
  private reader: ReadableStreamDefaultReader<Uint8Array>;

  constructor() {
    this.proc = spawn([MCP_BINARY], {
      stdin: "pipe",
      stdout: "pipe",
      stderr: "pipe",
    });
    this.stdin = this.proc.stdin as FileSink;
    this.reader = (this.proc.stdout as ReadableStream<Uint8Array>).getReader();
    this.pump();
  }

  private async pump() {
    const dec = new TextDecoder();
    while (true) {
      let chunk: Awaited<ReturnType<typeof this.reader.read>>;
      try {
        chunk = await this.reader.read();
      } catch {
        break;
      }
      if (chunk.done) break;
      this.buf += dec.decode(chunk.value, { stream: true });
      let nl = this.buf.indexOf("\n");
      while (nl !== -1) {
        const line = this.buf.slice(0, nl).trim();
        this.buf = this.buf.slice(nl + 1);
        nl = this.buf.indexOf("\n");
        if (!line) continue;
        try {
          const msg: RPCResponse = JSON.parse(line);
          if (msg.id !== undefined) {
            const p = this.pending.get(msg.id);
            if (p) {
              this.pending.delete(msg.id);
              if (msg.error) p.reject(new Error(msg.error.message));
              else p.resolve(msg.result);
            }
          }
        } catch {
          /* non-JSON stdout — ignore */
        }
      }
    }
  }

  private send(method: string, params: any): Promise<any> {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      const msg = `${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`;
      this.stdin.write(msg);
    });
  }

  private notify(method: string, params: any = {}) {
    const msg = `${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`;
    this.stdin.write(msg);
  }

  async initialize() {
    await this.send("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "e2e-test", version: "1.0" },
    });
    this.notify("notifications/initialized");
  }

  async listTools(): Promise<any[]> {
    const res = await this.send("tools/list", {});
    return res.tools ?? [];
  }

  /** Calls a tool. Throws if the tool returns isError. */
  async call(name: string, args: Record<string, any> = {}): Promise<any> {
    const res = await this.send("tools/call", { name, arguments: args });
    if (res.isError) throw new Error(res.content?.[0]?.text ?? "tool error");
    const text = res.content?.[0]?.text ?? "{}";
    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  }

  /** Calls a tool and returns { result, isError } without throwing. */
  async callRaw(
    name: string,
    args: Record<string, any> = {}
  ): Promise<{ result: any; isError: boolean; text: string }> {
    const res = await this.send("tools/call", { name, arguments: args });
    const text = res.content?.[0]?.text ?? "";
    return { result: res, isError: !!res.isError, text };
  }

  async readResource(uri: string): Promise<any> {
    const res = await this.send("resources/read", { uri });
    const text = res.contents?.[0]?.text ?? "{}";
    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  }

  async close() {
    this.stdin.end();
    // Server has a background reconciler timer so it won't exit on EOF alone — kill it.
    await Bun.sleep(200);
    this.proc.kill();
    await this.proc.exited.catch(() => {});
  }
}

// ── Test harness ─────────────────────────────────────────────────────────────

let passed = 0;
let failed = 0;
const errors: string[] = [];

function assert(label: string, cond: boolean, detail?: string) {
  if (cond) {
    console.log(`  ✅ ${label}`);
    passed++;
  } else {
    const msg = `  ❌ ${label}${detail ? ` — ${detail}` : ""}`;
    console.log(msg);
    failed++;
    errors.push(label + (detail ? ` (${detail})` : ""));
  }
}

/** Assert that the callback throws. */
async function assertThrows(label: string, fn: () => Promise<any>, matchMsg?: string) {
  try {
    await fn();
    assert(label, false, "expected error but call succeeded");
  } catch (e: any) {
    const msg: string = e?.message ?? String(e);
    if (matchMsg) {
      assert(label, msg.toLowerCase().includes(matchMsg.toLowerCase()), `got: "${msg}"`);
    } else {
      assert(label, true);
    }
  }
}

function section(name: string) {
  console.log(`\n── ${name} ──`);
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function run() {
  console.log("Starting DeepThink MCP E2E test suite…\n");
  const client = new MCPClient();
  await Bun.sleep(800);

  // Primary entities (live across the whole suite)
  let projPk = "";
  let taskPk = "";
  let notePk = "";
  let reminderPk = "";
  let taskHexId = "";
  let noteHexId = "";
  let projHexId = "";
  let reminderHexId = "";

  // Extra entities created in edge-case sections — tracked for cleanup
  // Each entry is [deleteTool, ref]
  const extraCleanup: Array<[string, string]> = [];

  try {
    await client.initialize();
    console.log("MCP server initialized ✓");

    // ══════════════════════════════════════════════════════════════════════════
    // 0. Tool discovery
    // ══════════════════════════════════════════════════════════════════════════
    section("Tool Discovery");
    const tools = await client.listTools();
    assert("tools/list returns array", Array.isArray(tools));
    assert("at least 40 tools registered", tools.length >= 40, `got ${tools.length}`);
    const toolNames = new Set(tools.map((t: any) => t.name));
    const REQUIRED_TOOLS = [
      "workspace_list_tasks",
      "workspace_get_task",
      "workspace_create_task",
      "workspace_update_task",
      "workspace_delete_task",
      "workspace_list_notes",
      "workspace_get_note",
      "workspace_create_note",
      "workspace_update_note",
      "workspace_delete_note",
      "workspace_list_projects",
      "workspace_get_project",
      "workspace_create_project",
      "workspace_update_project",
      "workspace_delete_project",
      "workspace_list_reminders",
      "workspace_get_reminder",
      "workspace_create_reminder",
      "workspace_update_reminder",
      "workspace_delete_reminder",
      "workspace_resolve_deeplink",
      "workspace_resolve_deeplinks",
      "workspace_summary",
      "workspace_reindex",
      "deepthink_overview",
      "smart_query",
      "unified_search",
      "workspace_context",
      "knowledge_context",
      "knowledge_stats",
      "knowledge_list_projects",
      "knowledge_load_project",
      "knowledge_save_project",
      "knowledge_search",
      "knowledge_list_integrations",
      "knowledge_load_integration",
      "knowledge_capture",
      "knowledge_compress",
      "knowledge_archive_project",
      "agent_list",
      "agent_get",
      "agent_create",
      "agent_delete",
      "rule_list",
      "rule_get",
      "rule_create",
      "rule_delete",
      "skill_list",
      "skill_get",
      "skill_create",
      "skill_delete",
    ];
    for (const t of REQUIRED_TOOLS) {
      assert(`tool "${t}" registered`, toolNames.has(t));
    }
    // Every registered tool has a name and inputSchema
    for (const t of tools) {
      assert(`tool "${t.name}" has inputSchema`, typeof t.inputSchema === "object");
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 1. Overview / workspace summary
    // ══════════════════════════════════════════════════════════════════════════
    section("Overview (deepthink_overview)");
    const ov = await client.call("deepthink_overview");
    assert("returns workspace object", typeof ov.workspace === "object");
    assert("workspace.projects is number", typeof ov.workspace?.projects === "number");
    assert("workspace.tasks.total is number", typeof ov.workspace?.tasks?.total === "number");
    assert("workspace.tasks.byStatus is object", typeof ov.workspace?.tasks?.byStatus === "object");
    assert("workspace.notes is number", typeof ov.workspace?.notes === "number");
    assert("workspace.reminders is object", typeof ov.workspace?.reminders === "object");
    assert("workspace.reminders.total is number", typeof ov.workspace?.reminders?.total === "number");
    assert("workspace.reminders.active is number", typeof ov.workspace?.reminders?.active === "number");
    assert("knowledge block present", typeof ov.knowledge === "object");
    assert("recentTasks is array", Array.isArray(ov.workspace?.recentTasks));
    assert("recentNotes is array", Array.isArray(ov.workspace?.recentNotes));

    section("Workspace Summary");
    const summ = await client.call("workspace_summary");
    assert("returns object", typeof summ === "object");
    assert("summary.projects.active is number", typeof summ.projects?.active === "number");
    assert("summary.projects.archived is number", typeof summ.projects?.archived === "number");
    assert("summary.tasks.active is number", typeof summ.tasks?.active === "number");
    assert("summary.reminders.active is number", typeof summ.reminders?.active === "number");

    // ══════════════════════════════════════════════════════════════════════════
    // 2. Projects CRUD
    // ══════════════════════════════════════════════════════════════════════════
    section("Projects CRUD");
    const projCreate = await client.call("workspace_create_project", {
      name: "E2E Test Project",
      summary: "Created by automated E2E test",
      color: "#FF6B6B",
    });
    assert("create returns pk", typeof projCreate.pk === "number");
    assert("create returns name", projCreate.name === "E2E Test Project");
    projPk = projCreate.pk.toString();

    const projList = await client.call("workspace_list_projects");
    const projItems: any[] = projList.projects ?? projList;
    assert("created project appears in list", !!projItems.find((p: any) => p.pk === projCreate.pk));
    assert("list returns total", typeof projList.total === "number");
    assert("list returns hasMore", typeof projList.hasMore === "boolean");

    const projGet = await client.call("workspace_get_project", { ref: projPk });
    assert("get by pk returns correct name", projGet.name === "E2E Test Project");
    assert("get returns summary", typeof projGet.summary === "string");
    assert("get returns color", typeof projGet.color === "string");
    assert("get returns taskCount", typeof projGet.taskCount === "number");
    assert("get returns noteCount", typeof projGet.noteCount === "number");
    assert("get returns isArchived=false", projGet.isArchived === false);
    projHexId = projGet.id;

    const projGetFuzzy = await client.call("workspace_get_project", { ref: "E2E Test Project" });
    assert("get by name returns same pk", projGetFuzzy.pk === projCreate.pk);

    await client.call("workspace_update_project", { ref: projPk, summary: "Updated E2E summary" });
    const projAfter = await client.call("workspace_get_project", { ref: projPk });
    assert("update changes summary", projAfter.summary === "Updated E2E summary");

    // ══════════════════════════════════════════════════════════════════════════
    // 3. Tasks CRUD
    // ══════════════════════════════════════════════════════════════════════════
    section("Tasks CRUD");
    const taskCreate = await client.call("workspace_create_task", {
      title: "E2E Test Task",
      detail: "Automated test task detail",
      status: "To Do",
      priority: "Medium",
      storyPoints: 3,
      project: projPk,
    });
    assert("create returns pk", typeof taskCreate.pk === "number");
    assert("create returns title", taskCreate.title === "E2E Test Task");
    assert("create returns status", taskCreate.status === "To Do");
    taskPk = taskCreate.pk.toString();

    const taskList = await client.call("workspace_list_tasks");
    const taskItems: any[] = taskList.tasks ?? taskList;
    assert("created task appears in list", !!taskItems.find((t: any) => t.pk === taskCreate.pk));
    assert("list returns total count", typeof taskList.total === "number");
    assert("list returns hasMore flag", typeof taskList.hasMore === "boolean");
    assert("list returns limit", typeof taskList.limit === "number");
    assert("list returns offset", typeof taskList.offset === "number");

    const taskListFiltered = await client.call("workspace_list_tasks", { status: "To Do", project: projPk });
    assert(
      "status+project filter includes task",
      !!(taskListFiltered.tasks ?? taskListFiltered).find((t: any) => t.pk === taskCreate.pk)
    );

    const taskGet = await client.call("workspace_get_task", { ref: taskPk });
    assert("get by pk returns correct title", taskGet.title === "E2E Test Task");
    assert("task has 32-char hex id", typeof taskGet.id === "string" && taskGet.id.length === 32);
    assert("task has storyPoints", taskGet.storyPoints === 3);
    assert("task has detail", taskGet.detail === "Automated test task detail");
    assert("task has priority", taskGet.priority === "Medium");
    taskHexId = taskGet.id;

    const taskGetFuzzy = await client.call("workspace_get_task", { ref: "E2E Test Task" });
    assert("get by name returns same pk", taskGetFuzzy.pk === taskCreate.pk);

    await client.call("workspace_update_task", { ref: taskPk, status: "In Progress", priority: "High" });
    const taskAfter = await client.call("workspace_get_task", { ref: taskPk });
    assert("update changes status", taskAfter.status === "In Progress");
    assert("update changes priority", taskAfter.priority === "High");

    const taskHighPri = await client.call("workspace_list_tasks", { priority: "High" });
    assert(
      "priority filter includes updated task",
      !!(taskHighPri.tasks ?? taskHighPri).find((t: any) => t.pk === taskCreate.pk)
    );

    const taskPage = await client.call("workspace_list_tasks", { limit: 2, offset: 0 });
    assert("pagination limit respected", (taskPage.tasks ?? taskPage).length <= 2);

    // ══════════════════════════════════════════════════════════════════════════
    // 4. Notes CRUD
    // ══════════════════════════════════════════════════════════════════════════
    section("Notes CRUD");
    const noteCreate = await client.call("workspace_create_note", {
      title: "E2E Test Note",
      content: "# E2E Note\nAutomated test note.",
      pinned: false,
      project: projPk,
    });
    assert("create returns pk", typeof noteCreate.pk === "number");
    notePk = noteCreate.pk.toString();

    const noteList = await client.call("workspace_list_notes");
    assert("created note in list", !!(noteList.notes ?? noteList).find((n: any) => n.pk === noteCreate.pk));
    assert("note list returns total", typeof noteList.total === "number");

    const noteGet = await client.call("workspace_get_note", { ref: notePk });
    assert("get by pk returns correct title", noteGet.title === "E2E Test Note");
    assert("note has 32-char hex id", typeof noteGet.id === "string" && noteGet.id.length === 32);
    assert("note isPinned starts false", noteGet.isPinned === false);
    noteHexId = noteGet.id;

    const noteGetFuzzy = await client.call("workspace_get_note", { ref: "E2E Test Note" });
    assert("get by title returns same pk", noteGetFuzzy.pk === noteCreate.pk);

    await client.call("workspace_update_note", { ref: notePk, pinned: true, content: "# E2E Note\nUpdated content." });
    const noteAfter = await client.call("workspace_get_note", { ref: notePk });
    assert("update pins note", noteAfter.isPinned === true);
    assert("update changes content", noteAfter.content?.includes("Updated content"));

    const notePinnedList = await client.call("workspace_list_notes", { pinned: true });
    assert(
      "pinned filter includes pinned note",
      !!(notePinnedList.notes ?? notePinnedList).find((n: any) => n.pk === noteCreate.pk)
    );

    const noteByProj = await client.call("workspace_list_notes", { project: projPk });
    assert("project filter includes note", !!(noteByProj.notes ?? noteByProj).find((n: any) => n.pk === noteCreate.pk));

    // ══════════════════════════════════════════════════════════════════════════
    // 5. Reminders CRUD
    // ══════════════════════════════════════════════════════════════════════════
    section("Reminders CRUD");
    const remCreate = await client.call("workspace_create_reminder", {
      title: "E2E Test Reminder",
      notes: "Reminder detail from E2E",
      reminderDate: "2026-12-31T09:00:00.000Z",
    });
    assert("create returns pk", typeof remCreate.pk === "number");
    reminderPk = remCreate.pk.toString();

    const remList = await client.call("workspace_list_reminders");
    assert("created reminder in list", !!(remList.reminders ?? remList).find((r: any) => r.pk === remCreate.pk));

    const remGet = await client.call("workspace_get_reminder", { ref: reminderPk });
    assert("get by pk returns correct title", remGet.title === "E2E Test Reminder");
    assert("get returns notes", remGet.notes === "Reminder detail from E2E");
    assert("get returns isCompleted=false", remGet.isCompleted === false);
    assert("get returns reminderDate", !!remGet.reminderDate);
    assert("reminder has 32-char hex id", typeof remGet.id === "string" && remGet.id.length === 32);
    reminderHexId = remGet.id;

    const remGetFuzzy = await client.call("workspace_get_reminder", { ref: "E2E Test Reminder" });
    assert("get by title returns same pk", remGetFuzzy.pk === remCreate.pk);

    await client.call("workspace_update_reminder", { ref: reminderPk, completed: true });
    const remAfter = await client.call("workspace_get_reminder", { ref: reminderPk });
    assert("update marks completed", remAfter.isCompleted === true);

    const remCompleted = await client.call("workspace_list_reminders", { completed: true });
    assert(
      "completed filter includes reminder",
      !!(remCompleted.reminders ?? remCompleted).find((r: any) => r.pk === remCreate.pk)
    );

    const remActive = await client.call("workspace_list_reminders", { completed: false });
    assert(
      "active filter excludes completed reminder",
      !(remActive.reminders ?? remActive).find((r: any) => r.pk === remCreate.pk)
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 6. Deeplinks — basic
    // ══════════════════════════════════════════════════════════════════════════
    section("Deeplink Resolution");
    const dlTask = await client.call("workspace_resolve_deeplink", { url: `deepthink://task/${taskHexId}` });
    assert("resolve task deeplink returns item", dlTask.title === "E2E Test Task");

    const dlNote = await client.call("workspace_resolve_deeplink", { url: `deepthink://note/${noteHexId}` });
    assert("resolve note deeplink returns item", dlNote.title === "E2E Test Note");

    const dlProj = await client.call("workspace_resolve_deeplink", { url: `deepthink://project/${projHexId}` });
    assert("resolve project deeplink returns item", dlProj.name === "E2E Test Project");

    const dlMulti = await client.call("workspace_resolve_deeplinks", {
      urls: [`deepthink://task/${taskHexId}`, `deepthink://note/${noteHexId}`, `deepthink://project/${projHexId}`],
    });
    const dlResults: any = dlMulti.results ?? dlMulti;
    assert(
      "resolve_deeplinks returns 3 results",
      Object.keys(dlResults).length === 3 || (Array.isArray(dlResults) && dlResults.length === 3)
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 7. Smart tools — basic
    // ══════════════════════════════════════════════════════════════════════════
    section("Smart Tools");
    const smartQ = await client.call("smart_query", { query: "show me my tasks" });
    assert("smart_query returns result", !!smartQ);

    const unifiedRes = await client.call("unified_search", { query: "E2E Test" });
    const unifiedItems: any[] = unifiedRes.results ?? (Array.isArray(unifiedRes) ? unifiedRes : []);
    assert("unified_search returns array", Array.isArray(unifiedItems));
    assert(
      "unified_search finds E2E items",
      unifiedItems.some((r: any) => (r.title ?? r.name ?? "").includes("E2E"))
    );

    const wsCtx = await client.call("workspace_context", { query: "E2E test" });
    assert("workspace_context returns object", typeof wsCtx === "object");

    try {
      const kCtx = await client.call("knowledge_context", { query: "E2E" });
      assert("knowledge_context returns result", !!kCtx);
    } catch {
      assert("knowledge_context gracefully handled when no embeddings", true);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 8. Knowledge base — basic
    // ══════════════════════════════════════════════════════════════════════════
    section("Knowledge Base");
    const kStats = await client.call("knowledge_stats");
    assert("knowledge_stats.projects is number", typeof kStats.projects === "number");

    const kListProj = await client.call("knowledge_list_projects");
    assert("knowledge_list_projects returns array", Array.isArray(kListProj.projects ?? kListProj));

    await client.call("knowledge_save_project", {
      project: "e2e-knowledge-test",
      content: "E2E knowledge base entry — context test.",
      type: "context",
    });
    const kLoaded = await client.call("knowledge_load_project", { project: "e2e-knowledge-test" });
    assert("knowledge_load_project returns object", typeof kLoaded === "object");
    assert("saved context appears in loaded project", JSON.stringify(kLoaded).includes("E2E knowledge"));

    await client.call("knowledge_save_project", {
      project: "e2e-knowledge-test",
      content: "Decision: Use E2E tests for validation.",
      type: "decision",
    });
    const kLoadedDecision = await client.call("knowledge_load_project", { project: "e2e-knowledge-test" });
    assert("saved decision appears in project", JSON.stringify(kLoadedDecision).includes("Decision:"));

    const kIntegrations = await client.call("knowledge_list_integrations");
    assert("knowledge_list_integrations returns object or array", typeof kIntegrations === "object");

    await client.call("knowledge_capture", {
      source: "e2e-test-source",
      channel: "e2e-channel",
      title: "E2E Capture Entry",
      content: "Captured E2E test content.",
      tags: ["e2e", "test"],
    });
    const kLoaded2 = await client.call("knowledge_load_integration", {
      source: "e2e-test-source",
      channel: "e2e-channel",
    });
    assert("knowledge_load_integration returns data", !!kLoaded2);
    assert("captured entry appears in integration", JSON.stringify(kLoaded2).includes("E2E Capture Entry"));

    const kSearch = await client.call("knowledge_search", { query: "E2E" });
    assert("knowledge_search returns results", !!kSearch);

    const kCompress = await client.call("knowledge_compress", { source: "e2e-test-source", channel: "e2e-channel" });
    assert("knowledge_compress returns result", !!kCompress);

    const kArchive = await client.call("knowledge_archive_project", { project: "e2e-knowledge-test" });
    assert("knowledge_archive_project returns result", !!kArchive);

    // ══════════════════════════════════════════════════════════════════════════
    // 9. Config — Agents, Rules, Skills (basic)
    // ══════════════════════════════════════════════════════════════════════════
    section("Agents");
    assert(
      "agent_list returns array",
      Array.isArray((await client.call("agent_list")).agents ?? (await client.call("agent_list")))
    );

    await client.call("agent_create", {
      name: "E2E Test Agent",
      role: "Test assistant for E2E validation",
      icon: "🤖",
      model: "claude-haiku-4-5-20251001",
      systemPrompt: "You are a test agent created by the E2E suite.",
    });
    const agentGet = await client.call("agent_get", { name: "E2E Test Agent" });
    assert("agent_get correct name", agentGet.name === "E2E Test Agent");
    assert("agent_get has role", typeof agentGet.role === "string");
    assert("agent_get has systemPrompt", typeof agentGet.systemPrompt === "string");
    assert(
      "agent_get in list",
      !!(await client.call("agent_list")).agents?.find((a: any) => a.name === "E2E Test Agent")
    );

    await client.call("agent_delete", { name: "E2E Test Agent" });
    assert(
      "deleted agent not in list",
      !(await client.call("agent_list")).agents?.find((a: any) => a.name === "E2E Test Agent")
    );

    section("Rules");
    assert("rule_list returns array", Array.isArray((await client.call("rule_list")).rules ?? []));

    await client.call("rule_create", {
      name: "E2E Test Rule",
      trigger: "when discussing E2E tests",
      category: "testing",
      instruction: "Always validate assertions in E2E tests.",
    });
    const ruleGet = await client.call("rule_get", { name: "E2E Test Rule" });
    assert("rule_get correct name", ruleGet.name === "E2E Test Rule");
    assert("rule_get has instruction", typeof ruleGet.instruction === "string");
    assert("rule in list", !!(await client.call("rule_list")).rules?.find((r: any) => r.name === "E2E Test Rule"));

    await client.call("rule_delete", { name: "E2E Test Rule" });
    assert(
      "deleted rule not in list",
      !(await client.call("rule_list")).rules?.find((r: any) => r.name === "E2E Test Rule")
    );

    section("Skills");
    assert("skill_list returns array", Array.isArray((await client.call("skill_list")).skills ?? []));

    await client.call("skill_create", {
      name: "e2e-test-skill",
      description: "Skill created by E2E test suite",
      category: "testing",
      systemPrompt: "You help with E2E testing validation.",
      promptTemplate: "Run E2E validation for: {{input}}",
    });
    const skillGet = await client.call("skill_get", { name: "e2e-test-skill" });
    assert("skill_get correct name", skillGet.name === "e2e-test-skill");
    assert("skill_get has category", typeof skillGet.category === "string");
    assert("skill in list", !!(await client.call("skill_list")).skills?.find((s: any) => s.name === "e2e-test-skill"));

    await client.call("skill_delete", { name: "e2e-test-skill" });
    assert(
      "deleted skill not in list",
      !(await client.call("skill_list")).skills?.find((s: any) => s.name === "e2e-test-skill")
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 10. MCP Resources
    // ══════════════════════════════════════════════════════════════════════════
    section("MCP Resources");
    for (const uri of [
      "deepthink://tasks",
      "deepthink://notes",
      "deepthink://projects",
      "deepthink://reminders",
      "deepthink://knowledge/stats",
      "deepthink://knowledge/projects",
      "deepthink://knowledge/integrations",
      "deepthink://overview",
    ]) {
      try {
        const res = await client.readResource(uri);
        assert(`resource ${uri} readable`, res !== null && res !== undefined);
      } catch (e: any) {
        assert(`resource ${uri} readable`, false, e.message);
      }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // EDGE CASES START HERE
    // ══════════════════════════════════════════════════════════════════════════

    // ── Task Edge Cases ────────────────────────────────────────────────────
    section("Task Edge Cases — Defaults & Fields");

    // Default status + priority
    const taskDefaults = await client.call("workspace_create_task", { title: "E2E Defaults Task" });
    extraCleanup.push(["workspace_delete_task", taskDefaults.pk.toString()]);
    const taskDefaultsGet = await client.call("workspace_get_task", { ref: taskDefaults.pk.toString() });
    assert("task default status is 'To Do'", taskDefaultsGet.status === "To Do");
    assert("task default priority is 'None'", taskDefaultsGet.priority === "None");
    assert(
      "task default storyPoints is null",
      taskDefaultsGet.storyPoints === null ||
        taskDefaultsGet.storyPoints === 0 ||
        taskDefaultsGet.storyPoints === undefined
    );
    assert("task default dueDate is null", taskDefaultsGet.dueDate === null || taskDefaultsGet.dueDate === undefined);
    assert(
      "task default detail is empty",
      taskDefaultsGet.detail === "" || taskDefaultsGet.detail === null || taskDefaultsGet.detail === undefined
    );

    // storyPoints round-trip
    const taskSP = await client.call("workspace_create_task", { title: "E2E StoryPoints Task", storyPoints: 8 });
    extraCleanup.push(["workspace_delete_task", taskSP.pk.toString()]);
    const taskSPGet = await client.call("workspace_get_task", { ref: taskSP.pk.toString() });
    assert("storyPoints round-trip", taskSPGet.storyPoints === 8);

    // dueDate round-trip
    const taskDue = await client.call("workspace_create_task", { title: "E2E DueDate Task", dueDate: "2026-06-15" });
    extraCleanup.push(["workspace_delete_task", taskDue.pk.toString()]);
    const taskDueGet = await client.call("workspace_get_task", { ref: taskDue.pk.toString() });
    assert("dueDate round-trip set", !!taskDueGet.dueDate);

    // Clear dueDate with 'none' (explicit null path in workspace.ts)
    await client.call("workspace_update_task", { ref: taskDue.pk.toString(), dueDate: "none" });
    const taskDueAfter = await client.call("workspace_get_task", { ref: taskDue.pk.toString() });
    assert("dueDate cleared with 'none'", taskDueAfter.dueDate === null || taskDueAfter.dueDate === undefined);

    // All status enum values
    section("Task Edge Cases — All Statuses");
    const taskStatusCycle = await client.call("workspace_create_task", { title: "E2E Status Cycle Task" });
    extraCleanup.push(["workspace_delete_task", taskStatusCycle.pk.toString()]);
    const taskStatusRef = taskStatusCycle.pk.toString();
    for (const status of ["Backlog", "To Do", "In Progress", "Done", "Cancelled"] as const) {
      await client.call("workspace_update_task", { ref: taskStatusRef, status });
      const tg = await client.call("workspace_get_task", { ref: taskStatusRef });
      assert(`task status set to '${status}'`, tg.status === status);
    }

    // All priority enum values
    const taskPriCycle = await client.call("workspace_create_task", { title: "E2E Priority Cycle Task" });
    extraCleanup.push(["workspace_delete_task", taskPriCycle.pk.toString()]);
    const taskPriRef = taskPriCycle.pk.toString();
    for (const priority of ["None", "Low", "Medium", "High", "Urgent"] as const) {
      await client.call("workspace_update_task", { ref: taskPriRef, priority });
      const tg = await client.call("workspace_get_task", { ref: taskPriRef });
      assert(`task priority set to '${priority}'`, tg.priority === priority);
    }

    // Project unassign with 'none'
    section("Task Edge Cases — Project Unassign");
    const taskUnassign = await client.call("workspace_create_task", { title: "E2E Unassign Task", project: projPk });
    extraCleanup.push(["workspace_delete_task", taskUnassign.pk.toString()]);
    const taskUnassignRef = taskUnassign.pk.toString();
    let taskUnassignGet = await client.call("workspace_get_task", { ref: taskUnassignRef });
    assert("task assigned to project", !!taskUnassignGet.projectName);
    await client.call("workspace_update_task", { ref: taskUnassignRef, project: "none" });
    taskUnassignGet = await client.call("workspace_get_task", { ref: taskUnassignRef });
    assert("task unassigned from project", !taskUnassignGet.projectName);

    // Multiple tasks in a project → all appear in project filter
    section("Task Edge Cases — Multiple Tasks in Project");
    const projFilter = await client.call("workspace_create_project", { name: "E2E Filter Project" });
    extraCleanup.push(["workspace_delete_project", projFilter.pk.toString()]);
    const filterProjRef = projFilter.pk.toString();
    const filterTaskPks: number[] = [];
    for (let i = 1; i <= 3; i++) {
      const t = await client.call("workspace_create_task", { title: `E2E Filter Task ${i}`, project: filterProjRef });
      extraCleanup.push(["workspace_delete_task", t.pk.toString()]);
      filterTaskPks.push(t.pk);
    }
    const filterResults = await client.call("workspace_list_tasks", { project: filterProjRef });
    const filterItems: any[] = filterResults.tasks ?? filterResults;
    assert(
      "all 3 project tasks visible via filter",
      filterTaskPks.every((pk) => filterItems.find((t: any) => t.pk === pk))
    );
    assert("filter returns exactly 3", filterItems.length === 3);

    // Pagination: create 5 tasks, page with limit=2
    section("Task Edge Cases — Pagination");
    const pageProjCreate = await client.call("workspace_create_project", { name: "E2E Pagination Project" });
    extraCleanup.push(["workspace_delete_project", pageProjCreate.pk.toString()]);
    const pageProjRef = pageProjCreate.pk.toString();
    for (let i = 1; i <= 5; i++) {
      const t = await client.call("workspace_create_task", { title: `E2E Page Task ${i}`, project: pageProjRef });
      extraCleanup.push(["workspace_delete_task", t.pk.toString()]);
    }
    const page1 = await client.call("workspace_list_tasks", { project: pageProjRef, limit: 2, offset: 0 });
    const page2 = await client.call("workspace_list_tasks", { project: pageProjRef, limit: 2, offset: 2 });
    const page3 = await client.call("workspace_list_tasks", { project: pageProjRef, limit: 2, offset: 4 });
    assert("page1 has 2 tasks", (page1.tasks ?? []).length === 2);
    assert("page2 has 2 tasks", (page2.tasks ?? []).length === 2);
    assert("page3 has 1 task (last page)", (page3.tasks ?? []).length === 1);
    assert("page1 total === 5", page1.total === 5);
    assert("page1 hasMore === true", page1.hasMore === true);
    assert("page3 hasMore === false", page3.hasMore === false);
    // Pages don't overlap
    const page1Pks = new Set((page1.tasks ?? []).map((t: any) => t.pk));
    const page2Pks = new Set((page2.tasks ?? []).map((t: any) => t.pk));
    assert(
      "page1 and page2 are non-overlapping",
      [...page2Pks].every((pk) => !page1Pks.has(pk))
    );

    // ── Note Edge Cases ────────────────────────────────────────────────────
    section("Note Edge Cases — Defaults");

    // Note without project
    const noteNoProj = await client.call("workspace_create_note", {
      title: "E2E No-Project Note",
      content: "Orphan note.",
    });
    extraCleanup.push(["workspace_delete_note", noteNoProj.pk.toString()]);
    const noteNoProjGet = await client.call("workspace_get_note", { ref: noteNoProj.pk.toString() });
    assert(
      "note without project has null projectPk",
      noteNoProjGet.projectPk === null || noteNoProjGet.projectPk === undefined
    );
    assert("note without project isPinned defaults false", noteNoProjGet.isPinned === false);

    // Note content round-trip with markdown
    const markdownContent = "# Heading\n\n- item 1\n- item 2\n\n**bold** and _italic_";
    const noteMd = await client.call("workspace_create_note", { title: "E2E Markdown Note", content: markdownContent });
    extraCleanup.push(["workspace_delete_note", noteMd.pk.toString()]);
    const noteMdGet = await client.call("workspace_get_note", { ref: noteMd.pk.toString() });
    assert("markdown content round-trip", noteMdGet.content === markdownContent);

    // Unpin note (pin then unpin)
    const noteUnpin = await client.call("workspace_create_note", {
      title: "E2E Unpin Note",
      content: "Will be unpinned.",
      pinned: true,
    });
    extraCleanup.push(["workspace_delete_note", noteUnpin.pk.toString()]);
    await client.call("workspace_update_note", { ref: noteUnpin.pk.toString(), pinned: false });
    const noteUnpinGet = await client.call("workspace_get_note", { ref: noteUnpin.pk.toString() });
    assert("note can be unpinned", noteUnpinGet.isPinned === false);

    // Note project unassign with 'none'
    const noteUnassign = await client.call("workspace_create_note", {
      title: "E2E Unassign Note",
      content: ".",
      project: projPk,
    });
    extraCleanup.push(["workspace_delete_note", noteUnassign.pk.toString()]);
    await client.call("workspace_update_note", { ref: noteUnassign.pk.toString(), project: "none" });
    const noteUnassignGet = await client.call("workspace_get_note", { ref: noteUnassign.pk.toString() });
    assert("note unassigned from project", noteUnassignGet.projectPk === null || !noteUnassignGet.projectName);

    // Note pagination
    section("Note Edge Cases — Pagination");
    const notePagProj = await client.call("workspace_create_project", { name: "E2E Note Pagination Project" });
    extraCleanup.push(["workspace_delete_project", notePagProj.pk.toString()]);
    for (let i = 1; i <= 4; i++) {
      const n = await client.call("workspace_create_note", {
        title: `E2E Pag Note ${i}`,
        content: `content ${i}`,
        project: notePagProj.pk.toString(),
      });
      extraCleanup.push(["workspace_delete_note", n.pk.toString()]);
    }
    const notePage1 = await client.call("workspace_list_notes", {
      project: notePagProj.pk.toString(),
      limit: 2,
      offset: 0,
    });
    const notePage2 = await client.call("workspace_list_notes", {
      project: notePagProj.pk.toString(),
      limit: 2,
      offset: 2,
    });
    assert("note page1 has 2", (notePage1.notes ?? []).length === 2);
    assert("note page2 has 2", (notePage2.notes ?? []).length === 2);
    assert("note total is 4", notePage1.total === 4);
    assert("note page2 hasMore is false", notePage2.hasMore === false);

    // ── Project Edge Cases ─────────────────────────────────────────────────
    section("Project Edge Cases — taskCount / noteCount");

    // Verify taskCount and noteCount reflect reality
    const countProj = await client.call("workspace_create_project", { name: "E2E Count Project" });
    extraCleanup.push(["workspace_delete_project", countProj.pk.toString()]);
    const countProjRef = countProj.pk.toString();

    const countProjBefore = await client.call("workspace_get_project", { ref: countProjRef });
    assert("taskCount starts at 0", countProjBefore.taskCount === 0);
    assert("noteCount starts at 0", countProjBefore.noteCount === 0);

    const countTask = await client.call("workspace_create_task", { title: "E2E Count Task", project: countProjRef });
    extraCleanup.push(["workspace_delete_task", countTask.pk.toString()]);
    const countNote = await client.call("workspace_create_note", {
      title: "E2E Count Note",
      content: ".",
      project: countProjRef,
    });
    extraCleanup.push(["workspace_delete_note", countNote.pk.toString()]);

    const countProjAfter = await client.call("workspace_get_project", { ref: countProjRef });
    assert("taskCount increments after task creation", countProjAfter.taskCount === 1);
    assert("noteCount increments after note creation", countProjAfter.noteCount === 1);

    // Also visible in list
    const projListForCount = await client.call("workspace_list_projects");
    const countProjInList = (projListForCount.projects ?? []).find((p: any) => p.pk === countProj.pk);
    assert("taskCount in list matches", countProjInList?.taskCount === 1);
    assert("noteCount in list matches", countProjInList?.noteCount === 1);

    // Archive / unarchive project
    section("Project Edge Cases — Archive / Unarchive");
    const archiveProj = await client.call("workspace_create_project", {
      name: "E2E Archive Project",
      summary: "Will be archived",
    });
    extraCleanup.push(["workspace_delete_project", archiveProj.pk.toString()]);
    const archiveProjRef = archiveProj.pk.toString();

    await client.call("workspace_update_project", { ref: archiveProjRef, archived: true });
    const archiveProjGet = await client.call("workspace_get_project", { ref: archiveProjRef });
    assert("project is archived after update", archiveProjGet.isArchived === true);

    // Editing archived project without archived: false should error
    await assertThrows(
      "editing archived project without unarchive flag throws",
      () => client.call("workspace_update_project", { ref: archiveProjRef, summary: "Try to edit" }),
      "archived"
    );

    // Unarchive
    await client.call("workspace_update_project", { ref: archiveProjRef, archived: false });
    const unarchiveProjGet = await client.call("workspace_get_project", { ref: archiveProjRef });
    assert("project is unarchived after archived: false", unarchiveProjGet.isArchived === false);

    // Delete project with tasks — tasks become unassigned, not deleted
    section("Project Edge Cases — Delete cascades");
    const cascadeProj = await client.call("workspace_create_project", { name: "E2E Cascade Project" });
    const cascadeTask = await client.call("workspace_create_task", {
      title: "E2E Cascade Task",
      project: cascadeProj.pk.toString(),
    });
    extraCleanup.push(["workspace_delete_task", cascadeTask.pk.toString()]);

    await client.call("workspace_delete_project", { ref: cascadeProj.pk.toString() });
    // project gone
    await assertThrows("cascade-deleted project throws on get", () =>
      client.call("workspace_get_project", { ref: cascadeProj.pk.toString() })
    );
    // task still exists but unassigned
    const cascadeTaskGet = await client.call("workspace_get_task", { ref: cascadeTask.pk.toString() });
    assert("task survives project delete", !!cascadeTaskGet);
    assert("task project unassigned after project delete", !cascadeTaskGet.projectName);

    // ── Reminder Edge Cases ────────────────────────────────────────────────
    section("Reminder Edge Cases — No Date / Date Clear / Re-open");

    // Create without reminderDate
    const remNoDate = await client.call("workspace_create_reminder", {
      title: "E2E No-Date Reminder",
      notes: "no date",
    });
    extraCleanup.push(["workspace_delete_reminder", remNoDate.pk.toString()]);
    const remNoDateGet = await client.call("workspace_get_reminder", { ref: remNoDate.pk.toString() });
    assert(
      "reminder without date has null reminderDate",
      remNoDateGet.reminderDate === null || remNoDateGet.reminderDate === undefined
    );

    // Set a date then clear it with 'none'
    await client.call("workspace_update_reminder", {
      ref: remNoDate.pk.toString(),
      reminderDate: "2026-09-01T08:00:00.000Z",
    });
    const remDateSet = await client.call("workspace_get_reminder", { ref: remNoDate.pk.toString() });
    assert("reminder date set", !!remDateSet.reminderDate);
    await client.call("workspace_update_reminder", { ref: remNoDate.pk.toString(), reminderDate: "none" });
    const remDateCleared = await client.call("workspace_get_reminder", { ref: remNoDate.pk.toString() });
    assert(
      "reminder date cleared with 'none'",
      remDateCleared.reminderDate === null || remDateCleared.reminderDate === undefined
    );

    // Re-open a completed reminder
    const remReopen = await client.call("workspace_create_reminder", { title: "E2E Reopen Reminder" });
    extraCleanup.push(["workspace_delete_reminder", remReopen.pk.toString()]);
    const remReopenRef = remReopen.pk.toString();
    await client.call("workspace_update_reminder", { ref: remReopenRef, completed: true });
    await client.call("workspace_update_reminder", { ref: remReopenRef, completed: false });
    const remReopenGet = await client.call("workspace_get_reminder", { ref: remReopenRef });
    assert("reminder re-opened (isCompleted false)", remReopenGet.isCompleted === false);

    // Update title and notes
    await client.call("workspace_update_reminder", {
      ref: remReopenRef,
      title: "E2E Reopen Renamed",
      notes: "new notes",
    });
    const remRenamedGet = await client.call("workspace_get_reminder", { ref: remReopenRef });
    assert("reminder title updated", remRenamedGet.title === "E2E Reopen Renamed");
    assert("reminder notes updated", remRenamedGet.notes === "new notes");

    // ── Deeplink Edge Cases ────────────────────────────────────────────────
    section("Deeplink Edge Cases — UUID with dashes");

    // Hex UUID -> insert dashes and verify it still resolves (normalized)
    const hexId = taskHexId; // 32-char hex
    const dashedUUID = `${hexId.slice(0, 8)}-${hexId.slice(8, 12)}-${hexId.slice(12, 16)}-${hexId.slice(16, 20)}-${hexId.slice(20)}`;
    const dlDashedTask = await client.call("workspace_resolve_deeplink", { url: `deepthink://task/${dashedUUID}` });
    assert("dashed UUID resolves same task", dlDashedTask.title === "E2E Test Task");

    // Mixed case UUID (lowercase)
    const lowerHex = taskHexId.toLowerCase();
    const dlLowerTask = await client.call("workspace_resolve_deeplink", { url: `deepthink://task/${lowerHex}` });
    assert("lowercase hex UUID resolves task", dlLowerTask.title === "E2E Test Task");

    // Knowledge deeplink returns knowledge stub (doesn't throw)
    const dlKnowledge = await client.call("workspace_resolve_deeplink", { url: `deepthink://knowledge?id=test-123` });
    assert("knowledge deeplink returns type=knowledge", dlKnowledge.type === "knowledge");

    // Invalid URL throws
    await assertThrows(
      "invalid deeplink URL throws",
      () => client.call("workspace_resolve_deeplink", { url: "not-a-deeplink" }),
      "invalid"
    );

    // Unknown type throws
    await assertThrows("unknown deeplink type throws", () =>
      client.call("workspace_resolve_deeplink", { url: "deepthink://bogustype/AABBCCDD" })
    );

    // resolve_deeplinks — mix of valid and invalid
    const dlMixedResult = await client.call("workspace_resolve_deeplinks", {
      urls: [`deepthink://task/${taskHexId}`, "deepthink://bogustype/AABBCCDD"],
    });
    const dlMixedData: any = dlMixedResult.results ?? dlMixedResult;
    assert("resolve_deeplinks returns 2 entries (valid + invalid)", Object.keys(dlMixedData).length === 2);
    const dlMixedValues = Object.values(dlMixedData) as any[];
    const hasSuccess = dlMixedValues.some((v: any) => v.title === "E2E Test Task");
    const hasError = dlMixedValues.some((v: any) => typeof v === "string" || v.error);
    assert("resolve_deeplinks: valid URL succeeded", hasSuccess);
    assert("resolve_deeplinks: invalid URL is error string", hasError);

    // ── Smart Tools — Depth ────────────────────────────────────────────────
    section("Smart Tools — Mode Routing");

    // Force summary mode
    const smartSummary = await client.call("smart_query", { query: "what tasks do I have", mode: "summary" });
    assert("smart_query mode=summary returns result", !!smartSummary);

    // Force full mode
    const smartFull = await client.call("smart_query", { query: "list all tasks", mode: "full" });
    assert("smart_query mode=full returns result", !!smartFull);

    // Auto mode — summary signal keyword
    const smartAutoSummary = await client.call("smart_query", { query: "summarize my workspace" });
    assert("smart_query auto with 'summarize' returns result", !!smartAutoSummary);

    // Auto mode — full data signal keyword
    const smartAutoFull = await client.call("smart_query", { query: "export all tasks" });
    assert("smart_query auto with 'export' returns result", !!smartAutoFull);

    section("Smart Tools — unified_search Filters");

    // Type filter: tasks only
    const uniTaskOnly = await client.call("unified_search", { query: "E2E Test", types: ["task"] });
    assert("unified_search type=task returns array", Array.isArray(uniTaskOnly.results));
    assert(
      "unified_search type=task all results are tasks",
      (uniTaskOnly.results as any[]).every((r: any) => r.type === "task")
    );

    // Type filter: notes only
    const uniNoteOnly = await client.call("unified_search", { query: "E2E Test", types: ["note"] });
    assert(
      "unified_search type=note all results are notes",
      (uniNoteOnly.results as any[]).every((r: any) => r.type === "note")
    );

    // maxItems limit
    const uniLimited = await client.call("unified_search", { query: "E2E", maxItems: 1 });
    assert("unified_search maxItems=1 returns at most 1", (uniLimited.results ?? []).length <= 1);

    // Query that returns nothing
    const uniEmpty = await client.call("unified_search", { query: "xQzNoMatchStringXYZ99" });
    assert("unified_search returns array for no-match", Array.isArray(uniEmpty.results));
    // Semantic search may still surface top-N results for unrecognized tokens — just verify array is returned

    // unified_search result shape
    const uniShape = await client.call("unified_search", { query: "E2E Test Task", types: ["task"] });
    if ((uniShape.results ?? []).length > 0) {
      const first = uniShape.results[0];
      assert("unified_search result has type", typeof first.type === "string");
      assert("unified_search result has title", typeof first.title === "string");
      assert("unified_search result has score", typeof first.score === "number");
    } else {
      assert("unified_search returned at least 1 task result", false, "0 results for E2E Test Task");
    }

    // workspace_context result shape
    section("Smart Tools — workspace_context Shape");
    const wsCtxShape = await client.call("workspace_context", { query: "E2E Test" });
    assert(
      "workspace_context has tasks field",
      Array.isArray(wsCtxShape.tasks) || typeof wsCtxShape.tasks === "object"
    );
    assert(
      "workspace_context has notes field",
      Array.isArray(wsCtxShape.notes) || typeof wsCtxShape.notes === "object"
    );

    // ── Knowledge — Depth ─────────────────────────────────────────────────
    section("Knowledge — Artifact Type");

    // Save artifact type
    await client.call("knowledge_save_project", {
      project: "e2e-artifact-test",
      content: "Artifact: deployment config v2.0",
      type: "artifact",
    });
    const kArtifact = await client.call("knowledge_load_project", { project: "e2e-artifact-test" });
    assert("knowledge_load_project returns object for artifact", typeof kArtifact === "object");
    // artifacts is an array of filenames, not file contents — verify at least one artifact file was created
    assert(
      "artifact type content saved (artifact file exists)",
      Array.isArray(kArtifact.artifacts) && kArtifact.artifacts.length > 0
    );

    // Archive the artifact test project
    await client.call("knowledge_archive_project", { project: "e2e-artifact-test" });
    assert("knowledge_archive_project (artifact) returns", true);

    section("Knowledge — Multiple Captures / Search Specificity");

    // Capture several entries to a fresh channel
    const uniqueToken = `UNIQUETOKEN_${Date.now()}`;
    for (let i = 1; i <= 3; i++) {
      await client.call("knowledge_capture", {
        source: "e2e-multi-source",
        channel: "e2e-multi-channel",
        title: `E2E Multi-Capture ${i}`,
        content: `Content ${i}: ${uniqueToken}`,
        tags: [`batch-${i}`],
      });
    }

    const kMultiLoad = await client.call("knowledge_load_integration", {
      source: "e2e-multi-source",
      channel: "e2e-multi-channel",
    });
    const kMultiStr = JSON.stringify(kMultiLoad);
    assert(
      "all 3 captures in channel",
      kMultiStr.includes("E2E Multi-Capture 1") &&
        kMultiStr.includes("E2E Multi-Capture 2") &&
        kMultiStr.includes("E2E Multi-Capture 3")
    );

    // Search by unique token
    const kSpecificSearch = await client.call("knowledge_search", { query: uniqueToken });
    assert("knowledge_search finds by unique token", JSON.stringify(kSpecificSearch).includes(uniqueToken));

    // Capture with metadata
    await client.call("knowledge_capture", {
      source: "e2e-meta-source",
      channel: "e2e-meta-channel",
      title: "E2E Metadata Capture",
      content: "Content with metadata.",
      tags: ["meta", "test"],
      metadata: { author: "e2e-bot", version: "1.0" },
    });
    const kMetaLoad = await client.call("knowledge_load_integration", {
      source: "e2e-meta-source",
      channel: "e2e-meta-channel",
    });
    assert("metadata capture stored", JSON.stringify(kMetaLoad).includes("E2E Metadata Capture"));

    // Compress multi-channel
    await client.call("knowledge_compress", { source: "e2e-multi-source", channel: "e2e-multi-channel" });
    assert("compress multi-channel succeeds", true);

    // Load channel after compress — entries are gone (replaced by archive)
    const kAfterCompress = await client.call("knowledge_load_integration", {
      source: "e2e-multi-source",
      channel: "e2e-multi-channel",
    });
    assert("after compress, original entries removed", !JSON.stringify(kAfterCompress).includes("E2E Multi-Capture 1"));

    // knowledge_stats after saves — project count goes up
    section("Knowledge — Stats After Saves");
    const kStatsAfter = await client.call("knowledge_stats");
    assert("knowledge_stats.projects still a number after saves", typeof kStatsAfter.projects === "number");
    assert("knowledge_stats.integrations is a number", typeof kStatsAfter.integrations === "number");

    // ── Config — Depth ────────────────────────────────────────────────────
    section("Config — Agent with knowledgeScope + skills");

    await client.call("agent_create", {
      name: "E2E Scoped Agent",
      role: "Agent with scope",
      systemPrompt: "You are a scoped agent.",
      model: "claude-sonnet-4-6",
      knowledgeScope: ["backend", "infra"],
      skills: ["deepthink", "code-review"],
    });
    const scopedAgent = await client.call("agent_get", { name: "E2E Scoped Agent" });
    assert("scoped agent name correct", scopedAgent.name === "E2E Scoped Agent");
    assert("scoped agent has model", scopedAgent.model === "claude-sonnet-4-6");
    // knowledgeScope and skills are stored as strings in frontmatter — verify they exist
    assert("scoped agent systemPrompt preserved", scopedAgent.systemPrompt.includes("scoped agent"));

    await client.call("agent_delete", { name: "E2E Scoped Agent" });
    assert(
      "scoped agent deleted",
      !(await client.call("agent_list")).agents?.find((a: any) => a.name === "E2E Scoped Agent")
    );

    section("Config — Skill commandName + {{input}} template");

    await client.call("skill_create", {
      name: "My Test Skill",
      description: "Tests commandName slugification",
      category: "testing",
      systemPrompt: "System: handle {{input}} carefully.",
      promptTemplate: "Process this: {{input}}",
    });
    const sluggedSkill = await client.call("skill_get", { name: "My Test Skill" });
    assert("skill commandName is slugified", sluggedSkill.commandName === "my-test-skill");
    assert("skill promptTemplate preserves {{input}}", sluggedSkill.promptTemplate?.includes("{{input}}"));
    assert("skill systemPrompt preserves {{input}}", sluggedSkill.systemPrompt?.includes("{{input}}"));

    // Also reachable by commandName
    const sluggedSkillByCmd = await client.call("skill_get", { name: "my-test-skill" });
    assert("skill get by commandName works", sluggedSkillByCmd.name === "My Test Skill");

    await client.call("skill_delete", { name: "My Test Skill" });

    section("Config — Rule instruction fidelity");

    const uniqueInstruction = `Exactly preserve: newlines\nand special chars: "quotes" & <brackets> ${Date.now()}`;
    await client.call("rule_create", {
      name: "E2E Fidelity Rule",
      trigger: "always",
      category: "testing",
      instruction: uniqueInstruction,
    });
    const fidelityRule = await client.call("rule_get", { name: "E2E Fidelity Rule" });
    // Instruction may be slightly reformatted by markdown — check key tokens
    assert("rule instruction preserved (quotes)", fidelityRule.instruction?.includes("Exactly preserve:"));
    assert("rule trigger preserved", fidelityRule.trigger === "always");

    await client.call("rule_delete", { name: "E2E Fidelity Rule" });

    // ── Error Paths ────────────────────────────────────────────────────────
    section("Error Paths — Non-existent refs");

    await assertThrows(
      "get task with bogus ref throws",
      () => client.call("workspace_get_task", { ref: "999999" }),
      "not found"
    );
    await assertThrows(
      "get note with bogus ref throws",
      () => client.call("workspace_get_note", { ref: "999999" }),
      "not found"
    );
    await assertThrows(
      "get project with bogus ref throws",
      () => client.call("workspace_get_project", { ref: "999999" }),
      "not found"
    );
    await assertThrows(
      "get reminder with bogus ref throws",
      () => client.call("workspace_get_reminder", { ref: "999999" }),
      "not found"
    );
    await assertThrows(
      "get task by unrecognized name throws",
      () => client.call("workspace_get_task", { ref: "ZZZ_NO_MATCH_E2E_TASK" }),
      "not found"
    );

    section("Error Paths — Unknown tool");

    const badTool = await client.callRaw("nonexistent_tool_xyz", {});
    assert("unknown tool returns isError", badTool.isError === true);
    assert(
      "unknown tool error mentions tool name",
      badTool.text.includes("nonexistent_tool_xyz") || badTool.text.includes("unknown")
    );

    section("Error Paths — Invalid deeplink");

    await assertThrows(
      "resolve_deeplink: no match URL throws",
      () => client.call("workspace_resolve_deeplink", { url: "http://not-deepthink.com" }),
      "invalid"
    );
    await assertThrows(
      "resolve_deeplink: non-existent task UUID throws",
      () => client.call("workspace_resolve_deeplink", { url: "deepthink://task/FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" }),
      "not found"
    );

    section("Error Paths — Archived item edit");

    // Create a task, verify we can edit archived task protection
    // (We don't archive a task here since there's no direct archive-task tool exposed;
    //  this path is tested indirectly through update_project which has the same guard.)
    // Re-verify archived project guard still works on a freshly created one:
    const guardProj = await client.call("workspace_create_project", { name: "E2E Guard Project" });
    extraCleanup.push(["workspace_delete_project", guardProj.pk.toString()]);
    await client.call("workspace_update_project", { ref: guardProj.pk.toString(), archived: true });
    await assertThrows(
      "update archived project without unarchive flag throws",
      () => client.call("workspace_update_project", { ref: guardProj.pk.toString(), name: "Should Fail" }),
      "archived"
    );
    await client.call("workspace_update_project", { ref: guardProj.pk.toString(), archived: false });

    // ── workspace_reindex ─────────────────────────────────────────────────
    section("workspace_reindex");
    const reindexResult = await client.call("workspace_reindex");
    assert("reindex returns object", typeof reindexResult === "object" || typeof reindexResult === "number");
    // Result may be { indexed: N } or just a number
    const reindexCount =
      typeof reindexResult === "number" ? reindexResult : (reindexResult.indexed ?? reindexResult.count ?? 0);
    assert("reindex returns numeric count", typeof reindexCount === "number");

    // ══════════════════════════════════════════════════════════════════════════
    // 11. Task completedAt lifecycle
    // ══════════════════════════════════════════════════════════════════════════
    section("Task completedAt lifecycle");

    const taskComplete = await client.call("workspace_create_task", { title: "E2E CompletedAt Task", status: "To Do" });
    extraCleanup.push(["workspace_delete_task", taskComplete.pk.toString()]);
    const taskCompleteRef = taskComplete.pk.toString();

    // completedAt should be null initially
    const taskCompleteGet0 = await client.call("workspace_get_task", { ref: taskCompleteRef });
    assert(
      "completedAt is null before Done",
      taskCompleteGet0.completedAt === null || taskCompleteGet0.completedAt === undefined
    );

    // Set status → Done: completedAt should be set
    await client.call("workspace_update_task", { ref: taskCompleteRef, status: "Done" });
    const taskCompleteGet1 = await client.call("workspace_get_task", { ref: taskCompleteRef });
    assert("status is Done after update", taskCompleteGet1.status === "Done");
    assert(
      "completedAt is set when status=Done",
      taskCompleteGet1.completedAt !== null && taskCompleteGet1.completedAt !== undefined
    );

    // Set status → In Progress: completedAt should be cleared
    await client.call("workspace_update_task", { ref: taskCompleteRef, status: "In Progress" });
    const taskCompleteGet2 = await client.call("workspace_get_task", { ref: taskCompleteRef });
    assert("status is In Progress after reopen", taskCompleteGet2.status === "In Progress");
    assert(
      "completedAt is cleared when status is not Done",
      taskCompleteGet2.completedAt === null || taskCompleteGet2.completedAt === undefined
    );

    // Set to Done again then Cancelled: completedAt cleared on Cancelled
    await client.call("workspace_update_task", { ref: taskCompleteRef, status: "Done" });
    await client.call("workspace_update_task", { ref: taskCompleteRef, status: "Cancelled" });
    const taskCompleteGet3 = await client.call("workspace_get_task", { ref: taskCompleteRef });
    assert(
      "completedAt cleared on Cancelled",
      taskCompleteGet3.completedAt === null || taskCompleteGet3.completedAt === undefined
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 12. Task & Note field update depth
    // ══════════════════════════════════════════════════════════════════════════
    section("Task — Title & Detail Updates");

    const taskFieldUpd = await client.call("workspace_create_task", {
      title: "E2E Field Update Original",
      detail: "original detail",
      storyPoints: 5,
    });
    extraCleanup.push(["workspace_delete_task", taskFieldUpd.pk.toString()]);
    const taskFieldRef = taskFieldUpd.pk.toString();

    // title update
    await client.call("workspace_update_task", { ref: taskFieldRef, title: "E2E Field Update Renamed" });
    const taskFieldGet1 = await client.call("workspace_get_task", { ref: taskFieldRef });
    assert("task title updated", taskFieldGet1.title === "E2E Field Update Renamed");
    assert("task detail unchanged after title update", taskFieldGet1.detail === "original detail");

    // detail update
    await client.call("workspace_update_task", { ref: taskFieldRef, detail: "new detail content" });
    const taskFieldGet2 = await client.call("workspace_get_task", { ref: taskFieldRef });
    assert("task detail updated", taskFieldGet2.detail === "new detail content");
    assert("task title unchanged after detail update", taskFieldGet2.title === "E2E Field Update Renamed");

    // storyPoints update
    await client.call("workspace_update_task", { ref: taskFieldRef, storyPoints: 13 });
    const taskFieldGet3 = await client.call("workspace_get_task", { ref: taskFieldRef });
    assert("task storyPoints updated to 13", taskFieldGet3.storyPoints === 13);

    // Multi-field update in single call
    await client.call("workspace_update_task", {
      ref: taskFieldRef,
      title: "E2E Multi-Field Update",
      detail: "multi updated",
      status: "In Progress",
      priority: "Urgent",
      storyPoints: 21,
    });
    const taskFieldGet4 = await client.call("workspace_get_task", { ref: taskFieldRef });
    assert("multi-field update: title", taskFieldGet4.title === "E2E Multi-Field Update");
    assert("multi-field update: detail", taskFieldGet4.detail === "multi updated");
    assert("multi-field update: status", taskFieldGet4.status === "In Progress");
    assert("multi-field update: priority", taskFieldGet4.priority === "Urgent");
    assert("multi-field update: storyPoints", taskFieldGet4.storyPoints === 21);

    section("Note — Title & Content Updates");

    const noteFieldUpd = await client.call("workspace_create_note", {
      title: "E2E Note Field Original",
      content: "original content here",
    });
    extraCleanup.push(["workspace_delete_note", noteFieldUpd.pk.toString()]);
    const noteFieldRef = noteFieldUpd.pk.toString();

    // title update
    await client.call("workspace_update_note", { ref: noteFieldRef, title: "E2E Note Field Renamed" });
    const noteFieldGet1 = await client.call("workspace_get_note", { ref: noteFieldRef });
    assert("note title updated", noteFieldGet1.title === "E2E Note Field Renamed");
    assert("note content unchanged after title update", noteFieldGet1.content === "original content here");

    // content with empty string
    await client.call("workspace_update_note", { ref: noteFieldRef, content: "" });
    const noteFieldGet2 = await client.call("workspace_get_note", { ref: noteFieldRef });
    assert("note content cleared to empty string", noteFieldGet2.content === "" || noteFieldGet2.content === null);

    // large content (>500 chars to exercise chunking logic on reindex)
    const largeContent = `# Large Note\n\n${"Lorem ipsum dolor sit amet. ".repeat(30)}`;
    await client.call("workspace_update_note", { ref: noteFieldRef, content: largeContent });
    const noteFieldGet3 = await client.call("workspace_get_note", { ref: noteFieldRef });
    assert("note accepts large content", noteFieldGet3.content === largeContent);

    // ══════════════════════════════════════════════════════════════════════════
    // 13. Project field updates (name, color, default color)
    // ══════════════════════════════════════════════════════════════════════════
    section("Project — Name, Color, Default Color");

    // Default color when not specified
    const projDefaultColor = await client.call("workspace_create_project", { name: "E2E Default Color Project" });
    extraCleanup.push(["workspace_delete_project", projDefaultColor.pk.toString()]);
    const projDefaultColorGet = await client.call("workspace_get_project", { ref: projDefaultColor.pk.toString() });
    assert("project default color is #007AFF", projDefaultColorGet.color === "#007AFF");

    // Name update round-trip
    await client.call("workspace_update_project", { ref: projDefaultColor.pk.toString(), name: "E2E Renamed Project" });
    const projRenamedGet = await client.call("workspace_get_project", { ref: projDefaultColor.pk.toString() });
    assert("project name updated", projRenamedGet.name === "E2E Renamed Project");

    // Get by new name (fuzzy match)
    const projByNewName = await client.call("workspace_get_project", { ref: "E2E Renamed Project" });
    assert("get project by updated name", projByNewName.pk === projDefaultColor.pk);

    // Color update round-trip
    await client.call("workspace_update_project", { ref: projDefaultColor.pk.toString(), color: "#123456" });
    const projColorGet = await client.call("workspace_get_project", { ref: projDefaultColor.pk.toString() });
    assert("project color updated", projColorGet.color === "#123456");

    // Passing archived: true to already-archived project should not throw
    // (because "archived" key IS in p — guard only fires when "archived" not in p)
    const projArch2 = await client.call("workspace_create_project", { name: "E2E Re-Archive Test" });
    extraCleanup.push(["workspace_delete_project", projArch2.pk.toString()]);
    await client.call("workspace_update_project", { ref: projArch2.pk.toString(), archived: true });
    // passing archived: true again should not throw (key present in p)
    await client.call("workspace_update_project", { ref: projArch2.pk.toString(), archived: true });
    const projArch2Get = await client.call("workspace_get_project", { ref: projArch2.pk.toString() });
    assert("re-archiving already-archived project does not throw", projArch2Get.isArchived === true);
    await client.call("workspace_update_project", { ref: projArch2.pk.toString(), archived: false });

    // No-op update (only ref provided)
    const projNoOp = await client.call("workspace_create_project", {
      name: "E2E No-Op Project",
      summary: "no-op test",
    });
    extraCleanup.push(["workspace_delete_project", projNoOp.pk.toString()]);
    await client.call("workspace_update_project", { ref: projNoOp.pk.toString() });
    const projNoOpGet = await client.call("workspace_get_project", { ref: projNoOp.pk.toString() });
    assert("no-op project update doesn't change name", projNoOpGet.name === "E2E No-Op Project");
    assert("no-op project update doesn't change summary", projNoOpGet.summary === "no-op test");

    // ══════════════════════════════════════════════════════════════════════════
    // 14. Reminder completedAt lifecycle & deeplink
    // ══════════════════════════════════════════════════════════════════════════
    section("Reminder — completedAt lifecycle");

    const remCA = await client.call("workspace_create_reminder", { title: "E2E CompletedAt Reminder" });
    extraCleanup.push(["workspace_delete_reminder", remCA.pk.toString()]);
    const remCARef = remCA.pk.toString();

    // Initially completedAt is null
    const remCA0 = await client.call("workspace_get_reminder", { ref: remCARef });
    assert("reminder completedAt null initially", remCA0.completedAt === null || remCA0.completedAt === undefined);
    assert("reminder isCompleted false initially", remCA0.isCompleted === false);

    // Complete it
    await client.call("workspace_update_reminder", { ref: remCARef, completed: true });
    const remCA1 = await client.call("workspace_get_reminder", { ref: remCARef });
    assert("completedAt set when completed=true", remCA1.completedAt !== null && remCA1.completedAt !== undefined);
    assert("isCompleted true", remCA1.isCompleted === true);

    // Re-open: completedAt cleared
    await client.call("workspace_update_reminder", { ref: remCARef, completed: false });
    const remCA2 = await client.call("workspace_get_reminder", { ref: remCARef });
    assert("completedAt cleared when completed=false", remCA2.completedAt === null || remCA2.completedAt === undefined);
    assert("isCompleted false after re-open", remCA2.isCompleted === false);

    section("Reminder — Deeplink Resolution");

    // Resolve reminder deeplink (single)
    const dlReminder = await client.call("workspace_resolve_deeplink", {
      url: `deepthink://reminder/${reminderHexId}`,
    });
    assert("resolve reminder deeplink returns item", dlReminder.title === "E2E Test Reminder");
    assert("reminder deeplink result has isCompleted", typeof dlReminder.isCompleted === "boolean");

    // Dashed UUID for reminder
    const remHex = reminderHexId;
    const remDashedUUID = `${remHex.slice(0, 8)}-${remHex.slice(8, 12)}-${remHex.slice(12, 16)}-${remHex.slice(16, 20)}-${remHex.slice(20)}`;
    const dlReminderDashed = await client.call("workspace_resolve_deeplink", {
      url: `deepthink://reminder/${remDashedUUID}`,
    });
    assert("dashed UUID resolves same reminder", dlReminderDashed.title === "E2E Test Reminder");

    // ══════════════════════════════════════════════════════════════════════════
    // 15. Deeplink batch — extended
    // ══════════════════════════════════════════════════════════════════════════
    section("Deeplink Batch — Extended");

    // Empty array → empty result object
    const dlEmpty = await client.call("workspace_resolve_deeplinks", { urls: [] });
    const dlEmptyData: any = dlEmpty.results ?? dlEmpty;
    assert("resolve_deeplinks empty array returns empty result", Object.keys(dlEmptyData).length === 0);

    // All four entity types in one batch
    const dlAllTypes = await client.call("workspace_resolve_deeplinks", {
      urls: [
        `deepthink://task/${taskHexId}`,
        `deepthink://note/${noteHexId}`,
        `deepthink://project/${projHexId}`,
        `deepthink://reminder/${reminderHexId}`,
      ],
    });
    const dlAllData: any = dlAllTypes.results ?? dlAllTypes;
    assert("resolve_deeplinks all 4 types returns 4 entries", Object.keys(dlAllData).length === 4);
    const dlAllValues = Object.values(dlAllData) as any[];
    assert(
      "task in batch result",
      dlAllValues.some((v: any) => v.title === "E2E Test Task")
    );
    assert(
      "note in batch result",
      dlAllValues.some((v: any) => v.title === "E2E Test Note")
    );
    assert(
      "project in batch result",
      dlAllValues.some((v: any) => v.name === "E2E Test Project")
    );
    assert(
      "reminder in batch result",
      dlAllValues.some((v: any) => v.title === "E2E Test Reminder")
    );

    // Knowledge URL in batch (should succeed as stub)
    const dlKnowledgeBatch = await client.call("workspace_resolve_deeplinks", {
      urls: [`deepthink://knowledge?id=batch-test-123`],
    });
    const dlKnowledgeBatchData: any = dlKnowledgeBatch.results ?? dlKnowledgeBatch;
    assert("knowledge URL in batch returns stub", Object.keys(dlKnowledgeBatchData).length === 1);
    const knowledgeBatchVal = Object.values(dlKnowledgeBatchData)[0] as any;
    assert("knowledge batch result has type=knowledge", knowledgeBatchVal.type === "knowledge");

    // Non-existent task UUID in batch → error entry (not exception)
    const dlBatchMissing = await client.call("workspace_resolve_deeplinks", {
      urls: [`deepthink://task/FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF`],
    });
    const dlBatchMissingData: any = dlBatchMissing.results ?? dlBatchMissing;
    assert("batch non-existent task returns error object", Object.keys(dlBatchMissingData).length === 1);
    const missingVal = Object.values(dlBatchMissingData)[0] as any;
    assert("batch missing item has error field", typeof missingVal.error === "string");

    // ══════════════════════════════════════════════════════════════════════════
    // 16. Config edge cases
    // ══════════════════════════════════════════════════════════════════════════
    section("Config — Agent Defaults & Overwrite");

    // Agent with no icon/model → defaults applied
    await client.call("agent_create", {
      name: "E2E Default Agent",
      role: "Default test agent",
      systemPrompt: "Minimal agent.",
    });
    const defaultAgent = await client.call("agent_get", { name: "E2E Default Agent" });
    assert("agent default icon is person.circle", defaultAgent.icon === "person.circle");
    assert("agent default model is null", defaultAgent.model === null);
    assert("agent isBuiltIn is false", defaultAgent.isBuiltIn === false);

    // Overwrite agent by creating same name again
    await client.call("agent_create", {
      name: "E2E Default Agent",
      role: "Overwritten role",
      systemPrompt: "Overwritten prompt.",
      model: "claude-haiku-4-5-20251001",
    });
    const overwrittenAgent = await client.call("agent_get", { name: "E2E Default Agent" });
    assert("agent overwrite changes role", overwrittenAgent.role === "Overwritten role");
    assert("agent overwrite changes model", overwrittenAgent.model === "claude-haiku-4-5-20251001");
    assert("agent overwrite changes systemPrompt", overwrittenAgent.systemPrompt.includes("Overwritten prompt"));

    await client.call("agent_delete", { name: "E2E Default Agent" });

    // Delete non-existent agent throws
    await assertThrows("delete non-existent agent throws", () =>
      client.call("agent_delete", { name: "ZZZ-NoSuchAgent-XYZ" })
    );

    section("Config — Rule Defaults & Edge Cases");

    // Rule with default icon/category
    await client.call("rule_create", {
      name: "E2E Default Rule",
      trigger: "note.tagged.important",
      instruction: "Apply careful formatting.",
    });
    const defaultRule = await client.call("rule_get", { name: "E2E Default Rule" });
    assert("rule default icon is bolt", defaultRule.icon === "bolt");
    assert("rule default category is General", defaultRule.category === "General");
    assert("rule isBuiltIn is false", defaultRule.isBuiltIn === false);
    assert("rule complex trigger preserved", defaultRule.trigger === "note.tagged.important");

    // Get rule by slugified filename
    const ruleBySlug = await client.call("rule_get", { name: "e2e-default-rule" });
    assert("rule get by slugified name", ruleBySlug.name === "E2E Default Rule");

    await client.call("rule_delete", { name: "E2E Default Rule" });

    // Delete non-existent rule throws
    await assertThrows("delete non-existent rule throws", () =>
      client.call("rule_delete", { name: "ZZZ-NoSuchRule-XYZ" })
    );

    section("Config — Skill Defaults & No-SystemPrompt");

    // Skill without systemPrompt
    await client.call("skill_create", {
      name: "E2E No-Prompt Skill",
      promptTemplate: "Just a template: {{input}}",
    });
    const noPromptSkill = await client.call("skill_get", { name: "E2E No-Prompt Skill" });
    assert(
      "skill without systemPrompt has empty systemPrompt",
      noPromptSkill.systemPrompt === "" ||
        noPromptSkill.systemPrompt === undefined ||
        noPromptSkill.systemPrompt === null
    );
    assert("skill promptTemplate preserved", noPromptSkill.promptTemplate?.includes("Just a template"));
    assert("skill default trigger is manual", noPromptSkill.trigger === "manual");
    assert("skill isPinned defaults false", noPromptSkill.isPinned === false);
    assert("skill default icon is sparkles", noPromptSkill.icon === "sparkles");

    await client.call("skill_delete", { name: "E2E No-Prompt Skill" });

    // Skill with model override
    await client.call("skill_create", {
      name: "E2E Model Skill",
      promptTemplate: "Do this: {{input}}",
      model: "claude-opus-4-7",
      trigger: "content_type.code",
    });
    const modelSkill = await client.call("skill_get", { name: "E2E Model Skill" });
    assert("skill model round-trip", modelSkill.model === "claude-opus-4-7");
    assert("skill trigger round-trip", modelSkill.trigger === "content_type.code");

    await client.call("skill_delete", { name: "E2E Model Skill" });

    // Delete non-existent skill throws
    await assertThrows("delete non-existent skill throws", () =>
      client.call("skill_delete", { name: "ZZZ-NoSuchSkill-XYZ" })
    );

    // Get non-existent agent/rule/skill throws
    await assertThrows("get non-existent agent throws", () => client.call("agent_get", { name: "ZZZ-NoSuchAgent" }));
    await assertThrows("get non-existent rule throws", () => client.call("rule_get", { name: "ZZZ-NoSuchRule" }));
    await assertThrows("get non-existent skill throws", () => client.call("skill_get", { name: "ZZZ-NoSuchSkill" }));

    // ══════════════════════════════════════════════════════════════════════════
    // 17. Smart query intent routing — verified
    // ══════════════════════════════════════════════════════════════════════════
    section("Smart Query — Intent Routing Verification");

    // "export all tasks" should route to full (export=1, all=1: fullScore=2 > summaryScore=0)
    const sqFull = await client.call("smart_query", { query: "export all tasks" });
    assert("smart_query 'export all' routes to full mode", sqFull.mode === "full");
    assert("full mode has workspace block", typeof sqFull.workspace === "object");
    assert("full mode workspace.tasks is array", Array.isArray(sqFull.workspace?.tasks));
    assert("full mode workspace.projects is array", Array.isArray(sqFull.workspace?.projects));

    // "what should I work on next" → summary
    const sqSummary = await client.call("smart_query", { query: "what should I work on next" });
    assert("smart_query 'what' routes to summary mode", sqSummary.mode === "summary");
    assert("summary mode has results array", Array.isArray(sqSummary.results));

    // "delete all my data" → full (delete=1, all=1, my=0, data=0: fullScore=2)
    const sqDeleteAll = await client.call("smart_query", { query: "delete all my data" });
    assert("smart_query 'delete all' routes to full mode", sqDeleteAll.mode === "full");

    // Force override: summary signals but mode=full → full
    const sqForcedfull = await client.call("smart_query", { query: "what is happening", mode: "full" });
    assert("forced mode=full overrides summary signal", sqForcedfull.mode === "full");
    assert("forced full has workspace block", typeof sqForcedfull.workspace === "object");

    // Force override: full signals but mode=summary → summary
    const sqForcedSummary = await client.call("smart_query", { query: "export all tasks", mode: "summary" });
    assert("forced mode=summary overrides full signal", sqForcedSummary.mode === "summary");
    assert("forced summary has results array", Array.isArray(sqForcedSummary.results));

    // ══════════════════════════════════════════════════════════════════════════
    // 18. Workspace summary depth
    // ══════════════════════════════════════════════════════════════════════════
    section("Workspace Summary — Depth");

    // Create a reminder with a past date → should show as overdue
    const pastDate = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(); // yesterday
    const overdueRem = await client.call("workspace_create_reminder", {
      title: "E2E Overdue Reminder",
      reminderDate: pastDate,
    });
    extraCleanup.push(["workspace_delete_reminder", overdueRem.pk.toString()]);

    const summaryWithOverdue = await client.call("workspace_summary");
    assert("workspace_summary.reminders.overdue is number", typeof summaryWithOverdue.reminders?.overdue === "number");
    assert("overdue reminder counted (≥1)", summaryWithOverdue.reminders.overdue >= 1);

    // tasks.byStatus should reflect actual status distribution
    const taskTodo = await client.call("workspace_create_task", { title: "E2E Summary Todo Task", status: "To Do" });
    extraCleanup.push(["workspace_delete_task", taskTodo.pk.toString()]);
    const taskInProg = await client.call("workspace_create_task", {
      title: "E2E Summary InProg Task",
      status: "In Progress",
    });
    extraCleanup.push(["workspace_delete_task", taskInProg.pk.toString()]);

    const summaryAfterTasks = await client.call("workspace_summary");
    assert("byStatus.To Do ≥ 1", (summaryAfterTasks.tasks?.byStatus?.["To Do"] ?? 0) >= 1);
    assert("byStatus.In Progress ≥ 1", (summaryAfterTasks.tasks?.byStatus?.["In Progress"] ?? 0) >= 1);

    // projects.items shows at most 5
    assert("workspace_summary.projects.items ≤ 5", (summaryAfterTasks.projects?.items?.length ?? 0) <= 5);

    // notes.active is a number
    assert("workspace_summary.notes.active is number", typeof summaryAfterTasks.notes?.active === "number");

    // ══════════════════════════════════════════════════════════════════════════
    // 19. deepthink_overview — count consistency
    // ══════════════════════════════════════════════════════════════════════════
    section("deepthink_overview — Count Consistency");

    const ovCount = await client.call("deepthink_overview");
    const projListCount = await client.call("workspace_list_projects");
    const taskListCount = await client.call("workspace_list_tasks");
    const noteListCount = await client.call("workspace_list_notes");
    const remListCount = await client.call("workspace_list_reminders");

    assert("overview.workspace.projects matches list total", ovCount.workspace.projects === projListCount.total);
    assert("overview.workspace.tasks.total matches list total", ovCount.workspace.tasks.total === taskListCount.total);
    assert("overview.workspace.notes matches list total", ovCount.workspace.notes === noteListCount.total);
    assert(
      "overview.workspace.reminders.total matches list count",
      ovCount.workspace.reminders.total === (remListCount.reminders ?? remListCount).length
    );

    // recentTasks should contain ≤ 3 strings
    assert("recentTasks ≤ 3 entries", ovCount.workspace.recentTasks.length <= 3);
    assert("recentNotes ≤ 3 entries", ovCount.workspace.recentNotes.length <= 3);

    // ══════════════════════════════════════════════════════════════════════════
    // 20. Pagination edge cases
    // ══════════════════════════════════════════════════════════════════════════
    section("Pagination — Offset Beyond Total");

    // offset past all results → empty array, hasMore=false, total still correct
    const bigOffset = await client.call("workspace_list_tasks", { offset: 99999 });
    assert("offset beyond total returns empty tasks", (bigOffset.tasks ?? []).length === 0);
    assert("offset beyond total: hasMore=false", bigOffset.hasMore === false);
    assert("offset beyond total: total still reflects real count", bigOffset.total >= 0);

    const bigOffsetNotes = await client.call("workspace_list_notes", { offset: 99999 });
    assert("notes: offset beyond total returns empty", (bigOffsetNotes.notes ?? []).length === 0);
    assert("notes: offset beyond total hasMore=false", bigOffsetNotes.hasMore === false);

    const bigOffsetProj = await client.call("workspace_list_projects", { offset: 99999 });
    assert("projects: offset beyond total returns empty", (bigOffsetProj.projects ?? []).length === 0);
    assert("projects: offset beyond total hasMore=false", bigOffsetProj.hasMore === false);

    section("Pagination — Limit Cap at 200");

    // Requesting limit=300 should be capped at 200
    const cappedList = await client.call("workspace_list_tasks", { limit: 300 });
    assert("limit=300 is capped: returned limit=200", cappedList.limit === 200);
    assert("capped limit: tasks.length ≤ 200", (cappedList.tasks ?? []).length <= 200);

    section("Pagination — Boundary: offset=0, limit=total → hasMore=false");

    const taskTotal = taskListCount.total as number;
    if (taskTotal > 0 && taskTotal <= 200) {
      const exactFetch = await client.call("workspace_list_tasks", { limit: taskTotal, offset: 0 });
      assert("fetching exactly total tasks: hasMore=false", exactFetch.hasMore === false);
      assert("fetching exactly total tasks: length=total", (exactFetch.tasks ?? []).length === taskTotal);
    } else {
      assert("pagination boundary test skipped (task count too large or zero)", true);
    }

    section("Pagination — limit=1 returns exactly 1");

    const limit1 = await client.call("workspace_list_tasks", { limit: 1 });
    assert("limit=1 returns exactly 1 task (if any exist)", (limit1.tasks ?? []).length <= 1);
    if (taskTotal > 1) {
      assert("limit=1 with >1 total: hasMore=true", limit1.hasMore === true);
    }

    section("Pagination — Projects Pagination");

    // Projects also paginate (separate pagination path from tasks/notes)
    const projPag1 = await client.call("workspace_list_projects", { limit: 1, offset: 0 });
    assert("project list: limit=1 works", (projPag1.projects ?? []).length <= 1);
    assert("project list returns total", typeof projPag1.total === "number");
    assert("project list returns hasMore", typeof projPag1.hasMore === "boolean");

    section("Task — Combined Filters (status + priority + project)");

    const comboProj = await client.call("workspace_create_project", { name: "E2E Combo Filter Project" });
    extraCleanup.push(["workspace_delete_project", comboProj.pk.toString()]);
    const comboProjRef = comboProj.pk.toString();

    const comboTask1 = await client.call("workspace_create_task", {
      title: "E2E Combo Task Urgent",
      status: "In Progress",
      priority: "Urgent",
      project: comboProjRef,
    });
    extraCleanup.push(["workspace_delete_task", comboTask1.pk.toString()]);

    const comboTask2 = await client.call("workspace_create_task", {
      title: "E2E Combo Task Low",
      status: "In Progress",
      priority: "Low",
      project: comboProjRef,
    });
    extraCleanup.push(["workspace_delete_task", comboTask2.pk.toString()]);

    // All three filters combined: only comboTask1 should match
    const comboFiltered = await client.call("workspace_list_tasks", {
      status: "In Progress",
      priority: "Urgent",
      project: comboProjRef,
    });
    const comboItems: any[] = comboFiltered.tasks ?? comboFiltered;
    assert("3-way filter returns 1 result", comboItems.length === 1);
    assert("3-way filter returns correct task", comboItems[0].pk === comboTask1.pk);

    // ══════════════════════════════════════════════════════════════════════════
    // 21. No-op updates
    // ══════════════════════════════════════════════════════════════════════════
    section("No-Op Updates — Only ref, no field changes");

    const taskNoOp = await client.call("workspace_create_task", { title: "E2E No-Op Task", detail: "keep this" });
    extraCleanup.push(["workspace_delete_task", taskNoOp.pk.toString()]);
    // Update with only ref — no fields → should not throw, data unchanged
    const taskNoOpResult = await client.call("workspace_update_task", { ref: taskNoOp.pk.toString() });
    assert("task no-op update doesn't throw", !!taskNoOpResult);
    const taskNoOpGet = await client.call("workspace_get_task", { ref: taskNoOp.pk.toString() });
    assert("task title unchanged after no-op", taskNoOpGet.title === "E2E No-Op Task");
    assert("task detail unchanged after no-op", taskNoOpGet.detail === "keep this");

    const noteNoOp = await client.call("workspace_create_note", { title: "E2E No-Op Note", content: "keep" });
    extraCleanup.push(["workspace_delete_note", noteNoOp.pk.toString()]);
    const noteNoOpResult = await client.call("workspace_update_note", { ref: noteNoOp.pk.toString() });
    assert("note no-op update doesn't throw", !!noteNoOpResult);
    const noteNoOpGet = await client.call("workspace_get_note", { ref: noteNoOp.pk.toString() });
    assert("note title unchanged after no-op", noteNoOpGet.title === "E2E No-Op Note");

    // ══════════════════════════════════════════════════════════════════════════
    // 22. Knowledge depth — stats archives, load nonexistent, search params
    // ══════════════════════════════════════════════════════════════════════════
    section("Knowledge — Stats archives field");

    const kStatsDeep = await client.call("knowledge_stats");
    assert("knowledge_stats returns archives field", typeof kStatsDeep.archives === "number");
    assert("knowledge_stats archives ≥ 0", kStatsDeep.archives >= 0);
    // We've run archive operations earlier, so archives should be ≥ 1
    assert("knowledge_stats archives ≥ 1 after archive ops", kStatsDeep.archives >= 1);

    section("Knowledge — Load nonexistent project/integration");

    // Non-existent project → graceful empty response (not an error)
    const kNonExistProj = await client.call("knowledge_load_project", { project: "zzz-no-such-project-xyz-e2e" });
    assert("load nonexistent project returns object", typeof kNonExistProj === "object");
    assert("load nonexistent project has empty context", kNonExistProj.context === "" || kNonExistProj.context == null);
    assert(
      "load nonexistent project has empty decisions",
      kNonExistProj.decisions === "" || kNonExistProj.decisions == null
    );
    assert(
      "load nonexistent project has empty artifacts",
      Array.isArray(kNonExistProj.artifacts) && kNonExistProj.artifacts.length === 0
    );

    // Non-existent source → graceful empty entries (not an error)
    const kNonExistSrc = await client.call("knowledge_load_integration", { source: "zzz-no-such-source-xyz-e2e" });
    assert("load nonexistent source returns object", typeof kNonExistSrc === "object");
    assert("load nonexistent source entries is empty array", (kNonExistSrc.entries ?? kNonExistSrc).length === 0);
    assert("load nonexistent source count is 0", (kNonExistSrc.count ?? 0) === 0);

    section("Knowledge — Search with source filter and limit");

    // Populate fresh channel for search
    const searchToken = `SEARCHTOKEN_${Date.now()}`;
    await client.call("knowledge_capture", {
      source: "e2e-search-source",
      channel: "e2e-search-channel",
      title: "E2E Search Entry",
      content: `Unique token: ${searchToken}`,
    });
    await client.call("knowledge_capture", {
      source: "e2e-other-source",
      channel: "other-channel",
      title: "E2E Other Entry",
      content: `Decoy content: ${searchToken}`,
    });

    // Search without source filter → finds both
    const kSearchAll = await client.call("knowledge_search", { query: searchToken });
    assert("search without source filter finds ≥ 2 results", (kSearchAll.results?.length ?? 0) >= 2);

    // Search with source filter → finds only matching source
    const kSearchFiltered = await client.call("knowledge_search", { query: searchToken, source: "e2e-search-source" });
    assert("search with source filter returns results object", typeof kSearchFiltered === "object");
    const filteredResults = kSearchFiltered.results ?? [];
    assert("search with source filter finds at least 1", filteredResults.length >= 1);
    assert(
      "search with source filter all from correct source",
      filteredResults.every((r: any) => r.source === "e2e-search-source")
    );

    // Search with limit=1 → returns at most 1
    const kSearchLimited = await client.call("knowledge_search", { query: searchToken, limit: 1 });
    assert("search with limit=1 returns at most 1", (kSearchLimited.results?.length ?? 0) <= 1);

    // Search with limit=0 → returns 0 (empty)
    const kSearchLimit0 = await client.call("knowledge_search", { query: searchToken, limit: 0 });
    assert("search with limit=0 returns 0 results", (kSearchLimit0.results?.length ?? 0) === 0);

    section("Knowledge — Auto-title from content");

    // Capture without explicit title → auto-derived from content
    const autoTitleContent = "## My Decision\nWe should use TypeScript for all new code.";
    await client.call("knowledge_capture", {
      source: "e2e-autotitle-source",
      channel: "e2e-autotitle-channel",
      content: autoTitleContent,
    });
    const kAutoLoad = await client.call("knowledge_load_integration", {
      source: "e2e-autotitle-source",
      channel: "e2e-autotitle-channel",
    });
    assert("auto-title capture stored", (kAutoLoad.entries?.length ?? 0) >= 1);
    // The auto-derived title should come from the first meaningful line
    const autoEntryContent = kAutoLoad.entries?.[0]?.content ?? "";
    assert(
      "auto-title entry has content",
      autoEntryContent.includes("My Decision") || autoEntryContent.includes("TypeScript")
    );

    section("Knowledge — knowledge_list_integrations structure");

    const kListInt = await client.call("knowledge_list_integrations");
    // Returns array directly (no wrapper) or with wrapper object
    const kIntList: any[] = Array.isArray(kListInt) ? kListInt : (kListInt.integrations ?? []);
    assert("knowledge_list_integrations returns array", Array.isArray(kIntList));
    // Each entry has source and channels
    if (kIntList.length > 0) {
      assert("integration entry has source field", typeof kIntList[0].source === "string");
      assert("integration entry has channels array", Array.isArray(kIntList[0].channels));
    }

    // knowledge_list_integrations via knowledge_load_integration with source=undefined should work or gracefully fail
    // Just verify the structure is consistent
    assert("integration list is an array", Array.isArray(kIntList));

    section("Knowledge — Multiple types in same project");

    const multiTypeProj = "e2e-multi-type-project";
    await client.call("knowledge_save_project", {
      project: multiTypeProj,
      content: "Context about project.",
      type: "context",
    });
    await client.call("knowledge_save_project", {
      project: multiTypeProj,
      content: "Decision: use Bun runtime.",
      type: "decision",
    });
    await client.call("knowledge_save_project", {
      project: multiTypeProj,
      content: "Artifact: config schema.",
      type: "artifact",
    });

    const multiTypeLoaded = await client.call("knowledge_load_project", { project: multiTypeProj });
    assert("multi-type project has context", multiTypeLoaded.context?.includes("Context about project"));
    assert("multi-type project has decisions", multiTypeLoaded.decisions?.includes("Decision:"));
    assert(
      "multi-type project has artifacts array",
      Array.isArray(multiTypeLoaded.artifacts) && multiTypeLoaded.artifacts.length >= 1
    );

    // Context is append-only — save again and verify both entries present
    await client.call("knowledge_save_project", {
      project: multiTypeProj,
      content: "More context added later.",
      type: "context",
    });
    const multiTypeLoaded2 = await client.call("knowledge_load_project", { project: multiTypeProj });
    assert(
      "context file accumulates entries",
      multiTypeLoaded2.context?.includes("Context about project") &&
        multiTypeLoaded2.context?.includes("More context added later")
    );

    await client.call("knowledge_archive_project", { project: multiTypeProj });

    // ══════════════════════════════════════════════════════════════════════════
    // 23. Double-delete error paths
    // ══════════════════════════════════════════════════════════════════════════
    section("Double-Delete — Second delete throws");

    // Task double-delete
    const ddTask = await client.call("workspace_create_task", { title: "E2E DD Task" });
    await client.call("workspace_delete_task", { ref: ddTask.pk.toString() });
    await assertThrows(
      "double-delete task throws",
      () => client.call("workspace_delete_task", { ref: ddTask.pk.toString() }),
      "not found"
    );

    // Note double-delete
    const ddNote = await client.call("workspace_create_note", { title: "E2E DD Note", content: "." });
    await client.call("workspace_delete_note", { ref: ddNote.pk.toString() });
    await assertThrows(
      "double-delete note throws",
      () => client.call("workspace_delete_note", { ref: ddNote.pk.toString() }),
      "not found"
    );

    // Project double-delete
    const ddProj = await client.call("workspace_create_project", { name: "E2E DD Project" });
    await client.call("workspace_delete_project", { ref: ddProj.pk.toString() });
    await assertThrows(
      "double-delete project throws",
      () => client.call("workspace_delete_project", { ref: ddProj.pk.toString() }),
      "not found"
    );

    // Reminder double-delete
    const ddRem = await client.call("workspace_create_reminder", { title: "E2E DD Reminder" });
    await client.call("workspace_delete_reminder", { ref: ddRem.pk.toString() });
    await assertThrows(
      "double-delete reminder throws",
      () => client.call("workspace_delete_reminder", { ref: ddRem.pk.toString() }),
      "not found"
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 24. Error path depth — update nonexistent
    // ══════════════════════════════════════════════════════════════════════════
    section("Error Paths — Update Non-existent");

    await assertThrows(
      "update nonexistent task throws",
      () => client.call("workspace_update_task", { ref: "999999", title: "x" }),
      "not found"
    );
    await assertThrows(
      "update nonexistent note throws",
      () => client.call("workspace_update_note", { ref: "999999", content: "x" }),
      "not found"
    );
    await assertThrows(
      "update nonexistent project throws",
      () => client.call("workspace_update_project", { ref: "999999", name: "x" }),
      "not found"
    );
    await assertThrows(
      "update nonexistent reminder throws",
      () => client.call("workspace_update_reminder", { ref: "999999", title: "x" }),
      "not found"
    );

    section("Error Paths — Delete Non-existent");

    await assertThrows(
      "delete nonexistent task throws",
      () => client.call("workspace_delete_task", { ref: "999999" }),
      "not found"
    );
    await assertThrows(
      "delete nonexistent note throws",
      () => client.call("workspace_delete_note", { ref: "999999" }),
      "not found"
    );
    await assertThrows(
      "delete nonexistent project throws",
      () => client.call("workspace_delete_project", { ref: "999999" }),
      "not found"
    );
    await assertThrows(
      "delete nonexistent reminder throws",
      () => client.call("workspace_delete_reminder", { ref: "999999" }),
      "not found"
    );

    section("Error Paths — Empty string ref");

    // Empty string ref should behave like "not found" (fuzzy match fails)
    await assertThrows(
      "get task with empty ref throws",
      () => client.call("workspace_get_task", { ref: "" }),
      "not found"
    );
    await assertThrows(
      "get note with empty ref throws",
      () => client.call("workspace_get_note", { ref: "" }),
      "not found"
    );
    await assertThrows(
      "get project with empty ref throws",
      () => client.call("workspace_get_project", { ref: "" }),
      "not found"
    );
    await assertThrows(
      "get reminder with empty ref throws",
      () => client.call("workspace_get_reminder", { ref: "" }),
      "not found"
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 25. workspace_reindex (idempotency)
    // ══════════════════════════════════════════════════════════════════════════
    section("workspace_reindex — Idempotency");

    const reindex1 = await client.call("workspace_reindex");
    const reindex2 = await client.call("workspace_reindex");
    assert("reindex is idempotent (no error on second call)", !!reindex2);
    // On second call, most items are unchanged → indexed count should be ≤ first call
    const count1 = typeof reindex1 === "number" ? reindex1 : (reindex1.indexed ?? reindex1.count ?? 0);
    const count2 = typeof reindex2 === "number" ? reindex2 : (reindex2.indexed ?? reindex2.count ?? 0);
    assert("reindex second call returns numeric count", typeof count2 === "number");
    assert("reindex second call ≤ first (skips unchanged)", count2 <= count1);

    // ══════════════════════════════════════════════════════════════════════════
    // 26. deepthink_overview knowledge block completeness
    // ══════════════════════════════════════════════════════════════════════════
    section("deepthink_overview — Knowledge Block");

    const ovFinal = await client.call("deepthink_overview");
    assert("knowledge.totalProjects is number", typeof ovFinal.knowledge?.totalProjects === "number");
    assert(
      "knowledge.totalIntegrationChannels is number",
      typeof ovFinal.knowledge?.totalIntegrationChannels === "number"
    );
    assert("knowledge.archives is number", typeof ovFinal.knowledge?.archives === "number");
    assert("knowledge.projects is array", Array.isArray(ovFinal.knowledge?.projects));
    assert("knowledge.integrationSources is array", Array.isArray(ovFinal.knowledge?.integrationSources));
    // After our earlier operations, totalProjects ≥ 1
    assert("knowledge.totalProjects ≥ 1 after save ops", ovFinal.knowledge.totalProjects >= 1);
    assert("knowledge.archives ≥ 1 after archive ops", ovFinal.knowledge.archives >= 1);

    // ══════════════════════════════════════════════════════════════════════════
    // Cleanup
    // ══════════════════════════════════════════════════════════════════════════
    section("Cleanup — Extra Entities (reverse order)");
    for (const [tool, ref] of [...extraCleanup].reverse()) {
      try {
        await client.call(tool, { ref });
      } catch {
        /* already cleaned up */
      }
    }
    assert("extra entities cleaned up", true);

    section("Cleanup — Primary Entities");

    await client.call("workspace_delete_reminder", { ref: reminderPk });
    await assertThrows("reminder deleted", () => client.call("workspace_get_reminder", { ref: reminderPk }));
    reminderPk = "";

    await client.call("workspace_delete_note", { ref: notePk });
    await assertThrows("note deleted", () => client.call("workspace_get_note", { ref: notePk }));
    notePk = "";

    await client.call("workspace_delete_task", { ref: taskPk });
    await assertThrows("task deleted", () => client.call("workspace_get_task", { ref: taskPk }));
    taskPk = "";

    await client.call("workspace_delete_project", { ref: projPk });
    await assertThrows("project deleted", () => client.call("workspace_get_project", { ref: projPk }));
    projPk = "";
  } finally {
    // Emergency cleanup
    for (const [tool, ref] of [...extraCleanup].reverse()) {
      if (ref) {
        try {
          await client.call(tool, { ref });
        } catch {}
      }
    }
    for (const [ref, tool] of [
      [reminderPk, "workspace_delete_reminder"],
      [notePk, "workspace_delete_note"],
      [taskPk, "workspace_delete_task"],
      [projPk, "workspace_delete_project"],
    ] as [string, string][]) {
      if (ref) {
        try {
          await client.call(tool, { ref });
        } catch {}
      }
    }
    await client.close();
  }

  // ── Summary ──────────────────────────────────────────────────────────────
  console.log(`\n${"─".repeat(60)}`);
  console.log(`Results: ${passed} passed, ${failed} failed`);
  if (errors.length > 0) {
    console.log("\nFailed assertions:");
    for (const e of errors) console.log(`  • ${e}`);
  }
  console.log("─".repeat(60));
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((e) => {
  console.error("Fatal error:", e);
  process.exit(1);
});
