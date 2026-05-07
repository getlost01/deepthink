import { retrieveContextHybrid, unifiedSearch, workspaceContext } from "../core/context-engine";
import * as db from "../core/db";
import * as knowledge from "./knowledge";

export interface MCPTool {
  name: string;
  description: string;
  inputSchema: Record<string, any>;
  execute: (params: Record<string, any>) => any;
}

// ── Intent Classification ──

const FULL_DATA_SIGNALS = [
  "edit",
  "update",
  "modify",
  "change",
  "delete",
  "remove",
  "create",
  "add",
  "new",
  "set",
  "assign",
  "move",
  "export",
  "dump",
  "backup",
  "migrate",
  "full",
  "all",
  "complete",
  "entire",
  "detail",
  "details",
  "specific",
  "exact",
];

const SUMMARY_SIGNALS = [
  "what",
  "how",
  "why",
  "when",
  "where",
  "who",
  "summary",
  "summarize",
  "overview",
  "brief",
  "context",
  "status",
  "progress",
  "recent",
  "latest",
  "help",
  "explain",
  "understand",
  "describe",
  "find",
  "search",
  "look",
  "check",
  "plan",
  "suggest",
  "recommend",
  "advise",
];

function classifyIntent(query: string): "summary" | "full" | "auto" {
  const q = query.toLowerCase();
  const fullScore = FULL_DATA_SIGNALS.reduce((s, w) => s + (q.includes(w) ? 1 : 0), 0);
  const summaryScore = SUMMARY_SIGNALS.reduce((s, w) => s + (q.includes(w) ? 1 : 0), 0);

  if (fullScore >= 2 && fullScore > summaryScore) return "full";
  if (summaryScore >= 1) return "summary";
  return "auto";
}

// ── Smart Tools ──

export const SMART_TOOLS: MCPTool[] = [
  // ── Smart Query (auto-routes) ──
  {
    name: "smart_query",
    description:
      "Intelligent auto-routing query. Analyzes intent and returns either compact summary context (for understanding/planning) or full data (for mutations/exports). Use this as your DEFAULT tool — it picks the right depth automatically. Saves ~80-90% tokens vs raw data retrieval for context-only queries.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Natural language query describing what you need" },
        mode: {
          type: "string",
          enum: ["auto", "summary", "full"],
          description:
            "Override auto-detection: 'summary' for context/understanding, 'full' for mutations/exports. Default: 'auto' (recommended)",
        },
        maxTokens: { type: "number", description: "Token budget for summary mode (default: 4000)" },
      },
      required: ["query"],
    },
    execute: (p) => {
      const mode = p.mode ?? classifyIntent(p.query);
      const resolvedMode = mode === "auto" ? classifyIntent(p.query) : mode;
      const actualMode = resolvedMode === "auto" ? "summary" : resolvedMode;

      if (actualMode === "full") {
        return {
          mode: "full",
          intent: "full_data",
          hint: "Use workspace_list_tasks, workspace_list_notes, knowledge_load_project, etc. for full data access.",
          workspace: {
            projects: db.listProjects(),
            tasks: db.listTasks(),
            notes: db.listNotes(),
            reminders: db.listReminders(),
          },
          knowledge: {
            stats: knowledge.knowledgeStats(),
            projects: knowledge.listProjects(),
            integrations: knowledge.listIntegrations(),
          },
        };
      }

      // Summary mode — unified search (BM25 + semantic, all types, RRF-fused)
      const unified = unifiedSearch(p.query, { maxItems: p.maxTokens ? Math.ceil(p.maxTokens / 400) : 10 });

      return {
        mode: "summary",
        intent: classifyIntent(p.query),
        results: unified,
        totalResults: unified.length,
        tip: "Need full data? Call again with mode='full' or use specific workspace_list_* / knowledge_load_* tools.",
      };
    },
  },

  // ── Knowledge Summary ──
  {
    name: "knowledge_context",
    description:
      "Hybrid knowledge retrieval (BM25 + semantic search with RRF fusion). Returns only the most relevant chunks instead of dumping all data. Use for context/understanding queries. ~90% fewer tokens than knowledge_search.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "What you're looking for" },
        maxTokens: {
          type: "number",
          description: "Token budget (default: 4000). Controls how much context is returned.",
        },
        projectScope: { type: "string", description: "Boost results from this project" },
        agentScope: {
          type: "array",
          items: { type: "string" },
          description: "Filter to these knowledge scope tags",
        },
        topK: { type: "number", description: "Max entries to return (default: 10)" },
      },
      required: ["query"],
    },
    execute: (p) => {
      return retrieveContextHybrid(p.query, {
        maxTokens: p.maxTokens ?? 4000,
        projectScope: p.projectScope,
        agentScope: p.agentScope,
        topK: p.topK ?? 10,
      });
    },
  },

  // ── Workspace Summary ──
  {
    name: "workspace_context",
    description:
      "Query-relevant workspace snapshot. Scores tasks, notes, and reminders by relevance to your query and returns top matches only. Use instead of workspace_list_tasks + workspace_list_notes when you need context, not full data.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "What you're working on or looking for" },
        maxItems: { type: "number", description: "Max items per category (default: 5)" },
      },
      required: ["query"],
    },
    execute: (p) => {
      return workspaceContext(p.query, p.maxItems ?? 5);
    },
  },

  // ── Unified Search ──
  {
    name: "unified_search",
    description:
      "Single ranked list across ALL data types: tasks, notes, reminders, and knowledge — BM25 + semantic vector search, RRF-fused. Use when you need the most relevant items regardless of type. Each result includes type, pk (for workspace items), title, content, and score.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "What you're looking for" },
        maxItems: { type: "number", description: "Max results (default: 10)" },
        types: {
          type: "array",
          items: { type: "string", enum: ["task", "note", "reminder", "knowledge"] },
          description: "Filter to specific types (default: all types)",
        },
      },
      required: ["query"],
    },
    execute: (p) => {
      const results = unifiedSearch(p.query, { maxItems: p.maxItems ?? 10, types: p.types });
      return { results, count: results.length };
    },
  },

  // ── Combined Overview ──
  {
    name: "deepthink_overview",
    description:
      "Compact overview of entire DeepThink state. Returns counts and top items only — no full content. Use as a starting point to understand what data exists before making specific queries. ~200 tokens vs ~60K+ for raw dump.",
    inputSchema: { type: "object", properties: {} },
    execute: () => {
      const projects = db.listProjects();
      const tasks = db.listTasks();
      const notes = db.listNotes();
      const reminders = db.listReminders();
      const kStats = knowledge.knowledgeStats();
      const kProjects = knowledge.listProjects();
      const kIntegrations = knowledge.listIntegrations();

      const tasksByStatus: Record<string, number> = {};
      for (const t of tasks) tasksByStatus[t.status] = (tasksByStatus[t.status] ?? 0) + 1;

      const activeReminders = reminders.filter((r) => !r.isCompleted);

      return {
        workspace: {
          projects: projects.length,
          tasks: { total: tasks.length, byStatus: tasksByStatus },
          notes: notes.length,
          reminders: { total: reminders.length, active: activeReminders.length },
          recentTasks: tasks.slice(0, 3).map((t) => `[${t.status}] ${t.title}`),
          recentNotes: notes.slice(0, 3).map((n) => n.title),
        },
        knowledge: {
          totalProjects: kStats.projects,
          totalIntegrationChannels: kStats.integrations,
          archives: kStats.archives,
          projects: kProjects,
          integrationSources: kIntegrations.map((i) => `${i.source} (${i.channels.length} channels)`),
        },
        hint: "Use smart_query for relevant context, or workspace_list_*/knowledge_load_* for full data.",
      };
    },
  },
];

export const SMART_TOOL_MAP: Record<string, MCPTool> = Object.fromEntries(SMART_TOOLS.map((t) => [t.name, t]));
