import * as db from "../core/db";
import { hexToUUID, listSubtaskIds } from "../core/db";
import {
  indexEntry,
  noteContent,
  projectContent,
  reindexWorkspace,
  reminderContent,
  taskContent,
} from "../core/embedding-service";
import { deleteChunksForEntry } from "../core/vector-store";

export interface WorkspaceTool {
  name: string;
  description: string;
  inputSchema: Record<string, any>;
  execute: (params: Record<string, any>) => any;
}

const STATUS_ENUM = ["Backlog", "To Do", "In Progress", "Done", "Cancelled"];
const PRIORITY_ENUM = ["None", "Low", "Medium", "High", "Urgent"];
const CRUD_ACTIONS = ["list", "get", "create", "update", "delete"];

function paginate<T>(all: T[], key: string, p: Record<string, any>) {
  const limit = typeof p.limit === "number" ? Math.min(p.limit, 200) : 50;
  const offset = typeof p.offset === "number" ? p.offset : 0;
  return {
    [key]: all.slice(offset, offset + limit),
    total: all.length,
    limit,
    offset,
    hasMore: offset + limit < all.length,
  };
}

// ── Deeplink resolution (shared by single + batch) ──

function resolveDeeplink(url: string): unknown {
  const match = url.match(/^deepthink:\/\/([^/?]+)\/?([^?]*)?(\?.*)?$/);
  if (!match) throw new Error(`Invalid deepthink:// URL: ${url}`);

  const type = match[1];
  const rawUUID = match[2] ?? "";
  const queryString = match[3] ?? "";

  if (type === "knowledge") {
    const params = new URLSearchParams(queryString.replace(/^\?/, ""));
    const id = params.get("id") ?? rawUUID;
    return { type: "knowledge", entryId: id, note: "Use knowledge_search tool to find this entry's content" };
  }

  const normalizedUUID = rawUUID.replace(/-/g, "").toUpperCase();

  if (type === "task") {
    const found = db.listTasks({ excludeArchived: false }).find((t) => t.id === normalizedUUID);
    if (!found) throw new Error(`task not found for URL: ${url}`);
    return found.isArchived ? { ...found, _warning: "This task is archived" } : found;
  }
  if (type === "note") {
    const found = db.listNotes({ excludeArchived: false }).find((n) => n.id === normalizedUUID);
    if (!found) throw new Error(`note not found for URL: ${url}`);
    return found.isArchived ? { ...found, _warning: "This note is archived" } : found;
  }
  if (type === "project") {
    const found = db.listProjects().find((pr) => pr.id === normalizedUUID);
    if (!found) throw new Error(`project not found for URL: ${url}`);
    return found;
  }
  if (type === "reminder") {
    const found = db.listReminders({}).find((r) => r.id === normalizedUUID);
    if (!found) throw new Error(`reminder not found for URL: ${url}`);
    return found;
  }

  throw new Error(`Unsupported deepthink:// type "${type}" in URL: ${url}`);
}

export const WORKSPACE_TOOLS: WorkspaceTool[] = [
  // ── Tasks ──
  {
    name: "workspace_task",
    description:
      "Create, read, update, delete, or list tasks. Set `action`:\n" +
      "- list: optional status, priority, project, limit, offset → paginated list\n" +
      "- get: requires ref (ID or name)\n" +
      "- create: requires title; optional detail, status, priority, storyPoints, dueDate, project\n" +
      "- update: requires ref; any of title, detail, status, priority, storyPoints, dueDate ('none' to clear), project ('none' to unassign)\n" +
      "- delete: requires ref",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: CRUD_ACTIONS, description: "Operation to perform" },
        ref: { type: "string", description: "Task ID or name (get/update/delete)" },
        title: { type: "string", description: "Task title" },
        detail: { type: "string", description: "Task description/details" },
        status: { type: "string", enum: STATUS_ENUM, description: "Task status (default: To Do on create)" },
        priority: { type: "string", enum: PRIORITY_ENUM, description: "Priority level (default: None on create)" },
        storyPoints: { type: "number", description: "Story points estimate" },
        dueDate: { type: "string", description: "Due date YYYY-MM-DD (or 'none' to clear on update)" },
        project: { type: "string", description: "Project name or ID (or 'none' to unassign on update)" },
        limit: { type: "number", description: "list: max results (default 50)" },
        offset: { type: "number", description: "list: skip first N (default 0)" },
      },
      required: ["action"],
    },
    execute: (p) => {
      switch (p.action) {
        case "list": {
          const all = db.listTasks({ status: p.status, priority: p.priority, project: p.project });
          return paginate(all, "tasks", p);
        }
        case "get": {
          const t = db.getTask(p.ref);
          if (!t) throw new Error(`task not found: ${p.ref}`);
          return t;
        }
        case "create": {
          if (!p.title) throw new Error(`'title' is required for action 'create'`);
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
            content: taskContent(p.title, p.detail ?? "", p.status ?? "To Do", false),
            tags: [],
            source: "task",
            importedAt: new Date(),
          });
          return { pk, title: p.title, status: p.status ?? "To Do" };
        }
        case "update": {
          const t = db.getTask(p.ref);
          if (!t) throw new Error(`task not found: ${p.ref}`);
          if (t.isArchived) throw new Error(`task is archived and cannot be edited. Unarchive it first.`);
          const { action, ref, limit, offset, ...fields } = p;
          if (fields.dueDate === "none") fields.dueDate = null;
          db.updateTask(t.pk, fields);
          const updated = db.getTask(t.pk.toString());
          if (updated)
            indexEntry({
              id: `task:${hexToUUID(t.id)}`,
              type: "task",
              title: updated.title,
              content: taskContent(updated.title, updated.detail, updated.status, updated.isArchived),
              tags: [],
              source: updated.isArchived ? "archive" : "task",
              importedAt: updated.modifiedAt,
            });
          return { pk: t.pk, updated: Object.keys(fields) };
        }
        case "delete": {
          const t = db.getTask(p.ref);
          if (!t) throw new Error(`task not found: ${p.ref}`);
          for (const subId of listSubtaskIds(t.pk)) deleteChunksForEntry(`task:${hexToUUID(subId)}`);
          deleteChunksForEntry(`task:${hexToUUID(t.id)}`);
          db.deleteTask(t.pk);
          return { pk: t.pk, deleted: true };
        }
        default:
          throw new Error(`unknown action: ${p.action}. Use one of: ${CRUD_ACTIONS.join(", ")}`);
      }
    },
  },

  // ── Notes ──
  {
    name: "workspace_note",
    description:
      "Create, read, update, delete, or list notes. Set `action`:\n" +
      "- list: optional project, pinned, limit, offset → paginated list\n" +
      "- get: requires ref (ID or title)\n" +
      "- create: requires title; optional content (markdown), pinned, project\n" +
      "- update: requires ref; any of title, content, pinned, project ('none' to unassign)\n" +
      "- delete: requires ref",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: CRUD_ACTIONS, description: "Operation to perform" },
        ref: { type: "string", description: "Note ID or title (get/update/delete)" },
        title: { type: "string", description: "Note title" },
        content: { type: "string", description: "Note body content (markdown supported)" },
        pinned: { type: "boolean", description: "Pin this note" },
        project: { type: "string", description: "Project name or ID (or 'none' to unassign on update)" },
        limit: { type: "number", description: "list: max results (default 50)" },
        offset: { type: "number", description: "list: skip first N (default 0)" },
      },
      required: ["action"],
    },
    execute: (p) => {
      switch (p.action) {
        case "list": {
          const all = db.listNotes({ project: p.project, pinned: p.pinned });
          return paginate(all, "notes", p);
        }
        case "get": {
          const n = db.getNote(p.ref);
          if (!n) throw new Error(`note not found: ${p.ref}`);
          return n;
        }
        case "create": {
          if (!p.title) throw new Error(`'title' is required for action 'create'`);
          const { pk, id } = db.createNote(p.title, { content: p.content, pinned: p.pinned, project: p.project });
          indexEntry({
            id: `note:${hexToUUID(id)}`,
            type: "note",
            title: p.title,
            content: noteContent(p.title, p.content ?? "", false),
            tags: [],
            source: "note",
            importedAt: new Date(),
          });
          return { pk, title: p.title };
        }
        case "update": {
          const n = db.getNote(p.ref);
          if (!n) throw new Error(`note not found: ${p.ref}`);
          if (n.isArchived) throw new Error(`note is archived and cannot be edited. Unarchive it first.`);
          const { action, ref, limit, offset, ...fields } = p;
          db.updateNote(n.pk, fields);
          const updated = db.getNote(n.pk.toString());
          if (updated)
            indexEntry({
              id: `note:${hexToUUID(n.id)}`,
              type: "note",
              title: updated.title,
              content: noteContent(updated.title, updated.content, updated.isArchived),
              tags: [],
              source: updated.isArchived ? "archive" : "note",
              importedAt: updated.modifiedAt,
            });
          return { pk: n.pk, updated: Object.keys(fields) };
        }
        case "delete": {
          const n = db.getNote(p.ref);
          if (!n) throw new Error(`note not found: ${p.ref}`);
          deleteChunksForEntry(`note:${hexToUUID(n.id)}`);
          db.deleteNote(n.pk);
          return { pk: n.pk, deleted: true };
        }
        default:
          throw new Error(`unknown action: ${p.action}. Use one of: ${CRUD_ACTIONS.join(", ")}`);
      }
    },
  },

  // ── Projects ──
  {
    name: "workspace_project",
    description:
      "Create, read, update, delete, or list projects. Set `action`:\n" +
      "- list: optional limit, offset → paginated list with task/note counts\n" +
      "- get: requires ref (ID or name)\n" +
      "- create: requires name; optional summary, color (hex like #007AFF)\n" +
      "- update: requires ref; any of name, summary, color, archived (boolean; pass archived:false to unarchive)\n" +
      "- delete: requires ref (tasks and notes in it become unassigned)",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: CRUD_ACTIONS, description: "Operation to perform" },
        ref: { type: "string", description: "Project ID or name (get/update/delete)" },
        name: { type: "string", description: "Project name" },
        summary: { type: "string", description: "Project description" },
        color: { type: "string", description: "Hex color (e.g. #007AFF)" },
        archived: { type: "boolean", description: "Archive/unarchive (update only)" },
        limit: { type: "number", description: "list: max results (default 50)" },
        offset: { type: "number", description: "list: skip first N (default 0)" },
      },
      required: ["action"],
    },
    execute: (p) => {
      switch (p.action) {
        case "list":
          return paginate(db.listProjects(), "projects", p);
        case "get": {
          const pr = db.getProject(p.ref);
          if (!pr) throw new Error(`project not found: ${p.ref}`);
          return pr;
        }
        case "create": {
          if (!p.name) throw new Error(`'name' is required for action 'create'`);
          const { pk, id } = db.createProject(p.name, { summary: p.summary, color: p.color });
          indexEntry({
            id: `project:${hexToUUID(id)}`,
            type: "project",
            title: p.name,
            content: projectContent(p.name, p.summary, false),
            tags: [],
            source: "project",
            importedAt: new Date(),
          });
          return { pk, name: p.name };
        }
        case "update": {
          const pr = db.getProject(p.ref);
          if (!pr) throw new Error(`project not found: ${p.ref}`);
          if (pr.isArchived && !("archived" in p))
            throw new Error(
              `project is archived and cannot be edited. Unarchive it first or pass archived: false to unarchive.`
            );
          const { action, ref, limit, offset, ...fields } = p;
          db.updateProject(pr.pk, fields);
          const updated = db.getProject(pr.pk.toString());
          if (updated)
            indexEntry({
              id: `project:${hexToUUID(pr.id)}`,
              type: "project",
              title: updated.name,
              content: projectContent(updated.name, updated.summary, updated.isArchived),
              tags: [],
              source: updated.isArchived ? "archive" : "project",
              importedAt: updated.modifiedAt,
            });
          return { pk: pr.pk, updated: Object.keys(fields) };
        }
        case "delete": {
          const pr = db.getProject(p.ref);
          if (!pr) throw new Error(`project not found: ${p.ref}`);
          deleteChunksForEntry(`project:${hexToUUID(pr.id)}`);
          db.deleteProject(pr.pk);
          return { pk: pr.pk, deleted: true };
        }
        default:
          throw new Error(`unknown action: ${p.action}. Use one of: ${CRUD_ACTIONS.join(", ")}`);
      }
    },
  },

  // ── Reminders ──
  {
    name: "workspace_reminder",
    description:
      "Create, read, update, delete, or list reminders. Set `action`:\n" +
      "- list: optional completed (boolean) → all reminders\n" +
      "- get: requires ref (ID or title)\n" +
      "- create: requires title; optional notes, reminderDate (ISO 8601 e.g. 2026-05-05T14:00:00)\n" +
      "- update: requires ref; any of title, notes, completed, reminderDate ('none' to clear)\n" +
      "- delete: requires ref",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: CRUD_ACTIONS, description: "Operation to perform" },
        ref: { type: "string", description: "Reminder ID or title (get/update/delete)" },
        title: { type: "string", description: "Reminder title" },
        notes: { type: "string", description: "Additional notes" },
        completed: { type: "boolean", description: "list: filter by completion status; update: set completion status" },
        reminderDate: { type: "string", description: "ISO 8601 date/time (or 'none' to clear on update)" },
      },
      required: ["action"],
    },
    execute: (p) => {
      switch (p.action) {
        case "list":
          return db.listReminders({ completed: p.completed });
        case "get": {
          const r = db.getReminder(p.ref);
          if (!r) throw new Error(`reminder not found: ${p.ref}`);
          return r;
        }
        case "create": {
          if (!p.title) throw new Error(`'title' is required for action 'create'`);
          const { pk, id } = db.createReminder(p.title, { notes: p.notes, reminderDate: p.reminderDate });
          indexEntry({
            id: `reminder:${hexToUUID(id)}`,
            type: "reminder",
            title: p.title,
            content: reminderContent(p.title, p.notes, false),
            tags: [],
            source: "reminder",
            importedAt: new Date(),
          });
          return { pk, title: p.title, reminderDate: p.reminderDate ?? null };
        }
        case "update": {
          const r = db.getReminder(p.ref);
          if (!r) throw new Error(`reminder not found: ${p.ref}`);
          const { action, ref, ...fields } = p;
          if (fields.reminderDate === "none") fields.reminderDate = null;
          db.updateReminder(r.pk, fields);
          const updated = db.getReminder(r.pk.toString());
          if (updated)
            indexEntry({
              id: `reminder:${hexToUUID(r.id)}`,
              type: "reminder",
              title: updated.title,
              content: reminderContent(updated.title, updated.notes, updated.isCompleted),
              tags: [],
              source: "reminder",
              importedAt: updated.modifiedAt,
            });
          return { pk: r.pk, updated: Object.keys(fields) };
        }
        case "delete": {
          const r = db.getReminder(p.ref);
          if (!r) throw new Error(`reminder not found: ${p.ref}`);
          deleteChunksForEntry(`reminder:${hexToUUID(r.id)}`);
          db.deleteReminder(r.pk);
          return { pk: r.pk, deleted: true };
        }
        default:
          throw new Error(`unknown action: ${p.action}. Use one of: ${CRUD_ACTIONS.join(", ")}`);
      }
    },
  },

  // ── Deeplink (single or batch) ──
  {
    name: "workspace_resolve_deeplink",
    description:
      "Resolve deepthink:// URLs to their full content. Pass `url` for one, or `urls` for many (returns a map of URL → item or error). Supports task, note, project, reminder, and knowledge URLs.",
    inputSchema: {
      type: "object",
      properties: {
        url: { type: "string", description: "A single deepthink:// URL, e.g. deepthink://task/UUID-WITH-DASHES" },
        urls: {
          type: "array",
          items: { type: "string" },
          description: "Multiple deepthink:// URLs to resolve at once",
        },
      },
    },
    execute: (p) => {
      if (Array.isArray(p.urls)) {
        const results: Record<string, unknown> = {};
        for (const url of p.urls) {
          try {
            results[url] = resolveDeeplink(url);
          } catch (e: any) {
            results[url] = { error: e.message };
          }
        }
        return results;
      }
      if (!p.url) throw new Error(`provide 'url' (string) or 'urls' (array)`);
      return resolveDeeplink(p.url);
    },
  },

  // ── Summary ──
  {
    name: "workspace_summary",
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
