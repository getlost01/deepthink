import * as db from "../core/db";
import { hexToUUID } from "../core/db";
import { indexEntry, reindexWorkspace } from "../core/embedding-service";
import { deleteChunksForEntry } from "../core/vector-store";

export interface WorkspaceTool {
  name: string;
  description: string;
  inputSchema: Record<string, any>;
  execute: (params: Record<string, any>) => any;
  readonly?: boolean;
}

const STATUS_ENUM = ["Backlog", "To Do", "In Progress", "Done", "Cancelled"];
const PRIORITY_ENUM = ["None", "Low", "Medium", "High", "Urgent"];

export const WORKSPACE_TOOLS: WorkspaceTool[] = [
  // ── Tasks ──
  {
    name: "workspace_list_tasks",
    readonly: true,
    description: "List tasks with optional filters. Returns paginated results (default 50 per page).",
    inputSchema: {
      type: "object",
      properties: {
        status: { type: "string", enum: STATUS_ENUM, description: "Filter by status" },
        priority: { type: "string", enum: PRIORITY_ENUM, description: "Filter by priority" },
        project: { type: "string", description: "Filter by project name or ID" },
        limit: { type: "number", description: "Max results to return (default 50)" },
        offset: { type: "number", description: "Skip first N results for pagination (default 0)" },
      },
    },
    execute: (p) => {
      const all = db.listTasks({ status: p.status, priority: p.priority, project: p.project });
      const limit = typeof p.limit === "number" ? Math.min(p.limit, 200) : 50;
      const offset = typeof p.offset === "number" ? p.offset : 0;
      return {
        tasks: all.slice(offset, offset + limit),
        total: all.length,
        limit,
        offset,
        hasMore: offset + limit < all.length,
      };
    },
  },
  {
    name: "workspace_get_task",
    readonly: true,
    description: "Get a single task by ID (number) or name (fuzzy match).",
    inputSchema: {
      type: "object",
      properties: { ref: { type: "string", description: "Task ID or name" } },
      required: ["ref"],
    },
    execute: (p) => {
      const t = db.getTask(p.ref);
      if (!t) throw new Error(`task not found: ${p.ref}`);
      return t;
    },
  },
  {
    name: "workspace_create_task",
    description: "Create a new task.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Task title" },
        detail: { type: "string", description: "Task description/details" },
        status: { type: "string", enum: STATUS_ENUM, description: "Task status (default: To Do)" },
        priority: { type: "string", enum: PRIORITY_ENUM, description: "Priority level (default: None)" },
        storyPoints: { type: "number", description: "Story points estimate" },
        dueDate: { type: "string", description: "Due date in YYYY-MM-DD format" },
        project: { type: "string", description: "Project name or ID to assign to" },
      },
      required: ["title"],
    },
    execute: (p) => {
      const { pk, id } = db.createTask(p.title, {
        detail: p.detail,
        status: p.status,
        priority: p.priority,
        storyPoints: p.storyPoints,
        dueDate: p.dueDate,
        project: p.project,
      });
      indexEntry({
        id: `task:${hexToUUID(id)}`,
        type: "task",
        title: p.title,
        content: `${p.title}\n${p.detail ?? ""}`,
        tags: [],
        source: "task",
        importedAt: new Date(),
      });
      return { pk, title: p.title, status: p.status ?? "To Do" };
    },
  },
  {
    name: "workspace_update_task",
    description: "Update an existing task's fields. Only provided fields are changed.",
    inputSchema: {
      type: "object",
      properties: {
        ref: { type: "string", description: "Task ID or name" },
        title: { type: "string" },
        detail: { type: "string" },
        status: { type: "string", enum: STATUS_ENUM },
        priority: { type: "string", enum: PRIORITY_ENUM },
        storyPoints: { type: "number" },
        dueDate: { type: "string", description: "YYYY-MM-DD or 'none' to clear" },
        project: { type: "string", description: "Project name/ID or 'none' to unassign" },
      },
      required: ["ref"],
    },
    execute: (p) => {
      const t = db.getTask(p.ref);
      if (!t) throw new Error(`task not found: ${p.ref}`);
      if (t.isArchived) throw new Error(`task is archived and cannot be edited. Unarchive it first.`);
      const { ref, ...fields } = p;
      db.updateTask(t.pk, fields);
      const updated = db.getTask(t.pk.toString());
      if (updated)
        indexEntry({
          id: `task:${hexToUUID(t.id)}`,
          type: "task",
          title: updated.title,
          content: `${updated.title}\n${updated.detail}`,
          tags: [],
          source: "task",
          importedAt: updated.modifiedAt,
        });
      return { pk: t.pk, updated: Object.keys(fields) };
    },
  },
  {
    name: "workspace_delete_task",
    description: "Delete a task permanently.",
    inputSchema: {
      type: "object",
      properties: { ref: { type: "string", description: "Task ID or name" } },
      required: ["ref"],
    },
    execute: (p) => {
      const t = db.getTask(p.ref);
      if (!t) throw new Error(`task not found: ${p.ref}`);
      deleteChunksForEntry(`task:${hexToUUID(t.id)}`);
      db.deleteTask(t.pk);
      return { pk: t.pk, deleted: true };
    },
  },

  // ── Notes ──
  {
    name: "workspace_list_notes",
    readonly: true,
    description: "List notes with optional filters. Returns paginated results (default 50 per page).",
    inputSchema: {
      type: "object",
      properties: {
        project: { type: "string", description: "Filter by project name or ID" },
        pinned: { type: "boolean", description: "Filter pinned notes only" },
        limit: { type: "number", description: "Max results to return (default 50)" },
        offset: { type: "number", description: "Skip first N results for pagination (default 0)" },
      },
    },
    execute: (p) => {
      const all = db.listNotes({ project: p.project, pinned: p.pinned });
      const limit = typeof p.limit === "number" ? Math.min(p.limit, 200) : 50;
      const offset = typeof p.offset === "number" ? p.offset : 0;
      return {
        notes: all.slice(offset, offset + limit),
        total: all.length,
        limit,
        offset,
        hasMore: offset + limit < all.length,
      };
    },
  },
  {
    name: "workspace_get_note",
    readonly: true,
    description: "Get a single note by ID or name.",
    inputSchema: {
      type: "object",
      properties: { ref: { type: "string", description: "Note ID or title" } },
      required: ["ref"],
    },
    execute: (p) => {
      const n = db.getNote(p.ref);
      if (!n) throw new Error(`note not found: ${p.ref}`);
      return n;
    },
  },
  {
    name: "workspace_create_note",
    description: "Create a new note.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Note title" },
        content: { type: "string", description: "Note body content (markdown supported)" },
        pinned: { type: "boolean", description: "Pin this note" },
        project: { type: "string", description: "Project name or ID" },
      },
      required: ["title"],
    },
    execute: (p) => {
      const { pk, id } = db.createNote(p.title, {
        content: p.content,
        pinned: p.pinned,
        project: p.project,
      });
      indexEntry({
        id: `note:${hexToUUID(id)}`,
        type: "note",
        title: p.title,
        content: `${p.title}\n${p.content ?? ""}`,
        tags: [],
        source: "note",
        importedAt: new Date(),
      });
      return { pk, title: p.title };
    },
  },
  {
    name: "workspace_update_note",
    description: "Update an existing note's fields.",
    inputSchema: {
      type: "object",
      properties: {
        ref: { type: "string", description: "Note ID or title" },
        title: { type: "string" },
        content: { type: "string" },
        pinned: { type: "boolean" },
        project: { type: "string", description: "Project name/ID or 'none' to unassign" },
      },
      required: ["ref"],
    },
    execute: (p) => {
      const n = db.getNote(p.ref);
      if (!n) throw new Error(`note not found: ${p.ref}`);
      if (n.isArchived) throw new Error(`note is archived and cannot be edited. Unarchive it first.`);
      const { ref, ...fields } = p;
      db.updateNote(n.pk, fields);
      const updated = db.getNote(n.pk.toString());
      if (updated)
        indexEntry({
          id: `note:${hexToUUID(n.id)}`,
          type: "note",
          title: updated.title,
          content: `${updated.title}\n${updated.content}`,
          tags: [],
          source: "note",
          importedAt: updated.modifiedAt,
        });
      return { pk: n.pk, updated: Object.keys(fields) };
    },
  },
  {
    name: "workspace_delete_note",
    description: "Delete a note permanently.",
    inputSchema: {
      type: "object",
      properties: { ref: { type: "string", description: "Note ID or title" } },
      required: ["ref"],
    },
    execute: (p) => {
      const n = db.getNote(p.ref);
      if (!n) throw new Error(`note not found: ${p.ref}`);
      deleteChunksForEntry(`note:${hexToUUID(n.id)}`);
      db.deleteNote(n.pk);
      return { pk: n.pk, deleted: true };
    },
  },

  // ── Projects ──
  {
    name: "workspace_list_projects",
    readonly: true,
    description: "List all projects with task/note counts. Returns paginated results (default 50 per page).",
    inputSchema: {
      type: "object",
      properties: {
        limit: { type: "number", description: "Max results to return (default 50)" },
        offset: { type: "number", description: "Skip first N results for pagination (default 0)" },
      },
    },
    execute: (p) => {
      const all = db.listProjects();
      const limit = typeof p.limit === "number" ? Math.min(p.limit, 200) : 50;
      const offset = typeof p.offset === "number" ? p.offset : 0;
      return {
        projects: all.slice(offset, offset + limit),
        total: all.length,
        limit,
        offset,
        hasMore: offset + limit < all.length,
      };
    },
  },
  {
    name: "workspace_get_project",
    readonly: true,
    description: "Get a single project by ID or name.",
    inputSchema: {
      type: "object",
      properties: { ref: { type: "string", description: "Project ID or name" } },
      required: ["ref"],
    },
    execute: (p) => {
      const pr = db.getProject(p.ref);
      if (!pr) throw new Error(`project not found: ${p.ref}`);
      return pr;
    },
  },
  {
    name: "workspace_create_project",
    description: "Create a new project.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Project name" },
        summary: { type: "string", description: "Project description" },
        color: { type: "string", description: "Hex color (e.g. #007AFF)" },
      },
      required: ["name"],
    },
    execute: (p) => {
      const { pk, id } = db.createProject(p.name, { summary: p.summary, color: p.color });
      indexEntry({
        id: `project:${hexToUUID(id)}`,
        type: "project",
        title: p.name,
        content: `${p.name}\n${p.summary ?? ""}`,
        tags: [],
        source: "project",
        importedAt: new Date(),
      });
      return { pk, name: p.name };
    },
  },
  {
    name: "workspace_update_project",
    description: "Update an existing project's fields.",
    inputSchema: {
      type: "object",
      properties: {
        ref: { type: "string", description: "Project ID or name" },
        name: { type: "string" },
        summary: { type: "string" },
        color: { type: "string" },
        archived: { type: "boolean" },
      },
      required: ["ref"],
    },
    execute: (p) => {
      const pr = db.getProject(p.ref);
      if (!pr) throw new Error(`project not found: ${p.ref}`);
      if (pr.isArchived && !("archived" in p))
        throw new Error(
          `project is archived and cannot be edited. Unarchive it first or pass archived: false to unarchive.`
        );
      const { ref, ...fields } = p;
      db.updateProject(pr.pk, fields);
      const updated2 = db.getProject(pr.pk.toString());
      if (updated2)
        indexEntry({
          id: `project:${hexToUUID(pr.id)}`,
          type: "project",
          title: updated2.name,
          content: `${updated2.name}\n${updated2.summary ?? ""}`,
          tags: [],
          source: "project",
          importedAt: updated2.modifiedAt,
        });
      return { pk: pr.pk, updated: Object.keys(fields) };
    },
  },
  {
    name: "workspace_delete_project",
    description: "Delete a project. Tasks and notes in it become unassigned.",
    inputSchema: {
      type: "object",
      properties: { ref: { type: "string", description: "Project ID or name" } },
      required: ["ref"],
    },
    execute: (p) => {
      const pr = db.getProject(p.ref);
      if (!pr) throw new Error(`project not found: ${p.ref}`);
      deleteChunksForEntry(`project:${hexToUUID(pr.id)}`);
      db.deleteProject(pr.pk);
      return { pk: pr.pk, deleted: true };
    },
  },

  // ── Reminders ──
  {
    name: "workspace_list_reminders",
    readonly: true,
    description: "List all reminders. Optionally filter by completion status.",
    inputSchema: {
      type: "object",
      properties: {
        completed: { type: "boolean", description: "Filter by completion status" },
      },
    },
    execute: (p) => db.listReminders({ completed: p.completed }),
  },
  {
    name: "workspace_get_reminder",
    readonly: true,
    description: "Get a single reminder by ID (number) or title (fuzzy match).",
    inputSchema: {
      type: "object",
      properties: { ref: { type: "string", description: "Reminder ID or title" } },
      required: ["ref"],
    },
    execute: (p) => {
      const r = db.getReminder(p.ref);
      if (!r) throw new Error(`reminder not found: ${p.ref}`);
      return r;
    },
  },
  {
    name: "workspace_create_reminder",
    description: "Create a new reminder with an optional date/time to be reminded.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Reminder title" },
        notes: { type: "string", description: "Additional notes" },
        reminderDate: {
          type: "string",
          description: "When to remind, in ISO 8601 format (e.g. 2026-05-05T14:00:00). Optional.",
        },
      },
      required: ["title"],
    },
    execute: (p) => {
      const { pk, id } = db.createReminder(p.title, { notes: p.notes, reminderDate: p.reminderDate });
      indexEntry({
        id: `reminder:${hexToUUID(id)}`,
        type: "reminder",
        title: p.title,
        content: `${p.title}\n${p.notes ?? ""}`,
        tags: [],
        source: "reminder",
        importedAt: new Date(),
      });
      return { pk, title: p.title, reminderDate: p.reminderDate ?? null };
    },
  },
  {
    name: "workspace_update_reminder",
    description: "Update an existing reminder. Only provided fields are changed.",
    inputSchema: {
      type: "object",
      properties: {
        ref: { type: "string", description: "Reminder ID or title" },
        title: { type: "string" },
        notes: { type: "string" },
        completed: { type: "boolean" },
        reminderDate: { type: "string", description: "ISO 8601 date or 'none' to clear" },
      },
      required: ["ref"],
    },
    execute: (p) => {
      const r = db.getReminder(p.ref);
      if (!r) throw new Error(`reminder not found: ${p.ref}`);
      const { ref, ...fields } = p;
      if (fields.reminderDate === "none") fields.reminderDate = null;
      db.updateReminder(r.pk, fields);
      const updated = db.getReminder(r.pk.toString());
      if (updated)
        indexEntry({
          id: `reminder:${hexToUUID(r.id)}`,
          type: "reminder",
          title: updated.title,
          content: `${updated.title}\n${updated.notes ?? ""}`,
          tags: [],
          source: "reminder",
          importedAt: updated.modifiedAt,
        });
      return { pk: r.pk, updated: Object.keys(fields) };
    },
  },
  {
    name: "workspace_delete_reminder",
    description: "Delete a reminder permanently.",
    inputSchema: {
      type: "object",
      properties: { ref: { type: "string", description: "Reminder ID or title" } },
      required: ["ref"],
    },
    execute: (p) => {
      const r = db.getReminder(p.ref);
      if (!r) throw new Error(`reminder not found: ${p.ref}`);
      deleteChunksForEntry(`reminder:${hexToUUID(r.id)}`);
      db.deleteReminder(r.pk);
      return { pk: r.pk, deleted: true };
    },
  },

  // ── Deeplink ──
  {
    name: "workspace_resolve_deeplink",
    description:
      "Resolve any deepthink:// URL to its full content. Use this when you encounter a deepthink:// link in a note or task and want to read the referenced item. Supports task, note, project, and reminder URLs.",
    inputSchema: {
      type: "object",
      properties: {
        url: {
          type: "string",
          description: "A deepthink:// URL, e.g. deepthink://task/UUID-WITH-DASHES or deepthink://note/UUID",
        },
      },
      required: ["url"],
    },
    execute: (p) => {
      const url: string = p.url;
      const match = url.match(/^deepthink:\/\/([^/?]+)\/?([^?]*)?(\?.*)?$/);
      if (!match) throw new Error(`Invalid deepthink:// URL: ${url}`);

      const type = match[1];
      const rawUUID = match[2] ?? "";
      const queryString = match[3] ?? "";

      if (type === "knowledge") {
        const params = new URLSearchParams(queryString.replace(/^\?/, ""));
        const id = params.get("id") ?? rawUUID;
        return {
          type: "knowledge",
          entryId: id,
          note: "Use knowledge_search tool to find this entry's content",
        };
      }

      const normalizedUUID = rawUUID.replace(/-/g, "").toUpperCase();

      if (type === "task") {
        const found = db.listTasks({ excludeArchived: false }).find((t) => t.id === normalizedUUID);
        if (!found) throw new Error(`task not found for URL: ${url}`);
        if (found.isArchived) return { ...found, _warning: "This task is archived" };
        return found;
      }
      if (type === "note") {
        const found = db.listNotes({ excludeArchived: false }).find((n) => n.id === normalizedUUID);
        if (!found) throw new Error(`note not found for URL: ${url}`);
        if (found.isArchived) return { ...found, _warning: "This note is archived" };
        return found;
      }
      if (type === "project") {
        const found = db.listProjects().find((p) => p.id === normalizedUUID);
        if (!found) throw new Error(`project not found for URL: ${url}`);
        return found;
      }
      if (type === "reminder") {
        const found = db.listReminders({}).find((r) => r.id === normalizedUUID);
        if (!found) throw new Error(`reminder not found for URL: ${url}`);
        return found;
      }

      throw new Error(`Unsupported deepthink:// type "${type}" in URL: ${url}`);
    },
  },

  // ── Batch Deeplink ──
  {
    name: "workspace_resolve_deeplinks",
    description:
      "Resolve multiple deepthink:// URLs at once. Returns a map of URL → resolved item (or error message). More efficient than calling workspace_resolve_deeplink in a loop.",
    inputSchema: {
      type: "object",
      properties: {
        urls: {
          type: "array",
          items: { type: "string" },
          description: "Array of deepthink:// URLs to resolve",
        },
      },
      required: ["urls"],
    },
    execute: (p) => {
      const urls: string[] = p.urls;
      const results: Record<string, unknown> = {};
      for (const url of urls) {
        try {
          const match = url.match(/^deepthink:\/\/([^/?]+)\/?([^?]*)?(\?.*)?$/);
          if (!match) {
            results[url] = { error: `Invalid deepthink:// URL: ${url}` };
            continue;
          }

          const type = match[1];
          const rawUUID = match[2] ?? "";
          const queryString = match[3] ?? "";

          if (type === "knowledge") {
            const params = new URLSearchParams(queryString.replace(/^\?/, ""));
            const id = params.get("id") ?? rawUUID;
            results[url] = { type: "knowledge", entryId: id, note: "Use knowledge_search to find content" };
            continue;
          }

          const normalizedUUID = rawUUID.replace(/-/g, "").toUpperCase();

          if (type === "task") {
            const found = db.listTasks({ excludeArchived: false }).find((t) => t.id === normalizedUUID);
            results[url] = found
              ? found.isArchived
                ? { ...found, _warning: "This task is archived" }
                : found
              : { error: `task not found: ${url}` };
          } else if (type === "note") {
            const found = db.listNotes({ excludeArchived: false }).find((n) => n.id === normalizedUUID);
            results[url] = found
              ? found.isArchived
                ? { ...found, _warning: "This note is archived" }
                : found
              : { error: `note not found: ${url}` };
          } else if (type === "project") {
            const found = db.listProjects().find((p) => p.id === normalizedUUID);
            results[url] = found ?? { error: `project not found: ${url}` };
          } else if (type === "reminder") {
            const found = db.listReminders({}).find((r) => r.id === normalizedUUID);
            results[url] = found ?? { error: `reminder not found: ${url}` };
          } else {
            results[url] = { error: `Unsupported type "${type}"` };
          }
        } catch (e: any) {
          results[url] = { error: e.message };
        }
      }
      return results;
    },
  },

  // ── Summary ──
  {
    name: "workspace_summary",
    readonly: true,
    description: "Get a summary of the entire workspace: project, task, and note counts plus recent items.",
    inputSchema: { type: "object", properties: {} },
    execute: () => {
      const allProjects = db.listProjects();
      const activeTasks = db.listTasks({ excludeArchived: true });
      const activeNotes = db.listNotes({ excludeArchived: true });
      const reminders = db.listReminders();

      const activeProjects = allProjects.filter((p) => !p.isArchived);
      const tasksByStatus: Record<string, number> = {};
      for (const t of activeTasks) tasksByStatus[t.status] = (tasksByStatus[t.status] ?? 0) + 1;

      const activeReminders = reminders.filter((r) => !r.isCompleted);
      const overdueReminders = activeReminders.filter((r) => r.reminderDate && r.reminderDate < new Date());

      return {
        projects: {
          active: activeProjects.length,
          archived: allProjects.length - activeProjects.length,
          items: activeProjects
            .slice(0, 5)
            .map((p) => ({ pk: p.pk, name: p.name, tasks: p.taskCount, notes: p.noteCount })),
        },
        tasks: {
          active: activeTasks.length,
          byStatus: tasksByStatus,
          recent: activeTasks
            .slice(0, 5)
            .map((t) => ({ pk: t.pk, title: t.title, status: t.status, priority: t.priority })),
        },
        notes: {
          active: activeNotes.length,
          recent: activeNotes.slice(0, 5).map((n) => ({ pk: n.pk, title: n.title, project: n.projectName })),
        },
        reminders: {
          total: reminders.length,
          active: activeReminders.length,
          overdue: overdueReminders.length,
          recent: activeReminders.slice(0, 5).map((r) => ({ pk: r.pk, title: r.title, reminderDate: r.reminderDate })),
        },
      };
    },
  },
  // ── Reindex ──
  {
    name: "workspace_reindex",
    description:
      "Re-embed all workspace items (tasks, notes, reminders) that are missing embeddings or have stale content. " +
      "Run once after a fresh install or after upgrading from a version that lacked per-item embedding. " +
      "Safe to call multiple times — unchanged items are skipped. Returns the count of items actually indexed.",
    inputSchema: { type: "object", properties: {} },
    execute: (_p) => reindexWorkspace(),
  },
];

export const WORKSPACE_TOOL_MAP: Record<string, WorkspaceTool> = Object.fromEntries(
  WORKSPACE_TOOLS.map((t) => [t.name, t])
);

export const WORKSPACE_TOOL_NAMES = WORKSPACE_TOOLS.map((t) => t.name);
