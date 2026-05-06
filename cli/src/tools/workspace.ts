import * as db from "../core/db";
import { indexEntry, removeEntry } from "../core/embedding-service";
import { deleteChunksForEntry } from "../core/vector-store";

export interface WorkspaceTool {
  name: string;
  description: string;
  inputSchema: Record<string, any>;
  execute: (params: Record<string, any>) => any;
}

const STATUS_ENUM = ["Backlog", "To Do", "In Progress", "Done", "Cancelled"];
const PRIORITY_ENUM = ["None", "Low", "Medium", "High", "Urgent"];

export const WORKSPACE_TOOLS: WorkspaceTool[] = [
  // ── Tasks ──
  {
    name: "workspace_list_tasks",
    description: "List all tasks. Optionally filter by status, priority, or project.",
    inputSchema: {
      type: "object",
      properties: {
        status: { type: "string", enum: STATUS_ENUM, description: "Filter by status" },
        priority: { type: "string", enum: PRIORITY_ENUM, description: "Filter by priority" },
        project: { type: "string", description: "Filter by project name or ID" },
      },
    },
    execute: (p) => db.listTasks({ status: p.status, priority: p.priority, project: p.project }),
  },
  {
    name: "workspace_get_task",
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
      const pk = db.createTask(p.title, {
        detail: p.detail, status: p.status, priority: p.priority,
        storyPoints: p.storyPoints, dueDate: p.dueDate, project: p.project,
      });
      indexEntry({ id: `task:${pk}`, type: "task", title: p.title, content: p.detail ?? "", tags: [], source: "task", importedAt: new Date() });
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
      const { ref, ...fields } = p;
      db.updateTask(t.pk, fields);
      const updated = db.getTask(t.pk.toString());
      if (updated) indexEntry({ id: `task:${t.pk}`, type: "task", title: updated.title, content: updated.detail, tags: [], source: "task", importedAt: updated.modifiedAt });
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
      db.deleteTask(t.pk);
      deleteChunksForEntry(`task:${t.pk}`);
      return { pk: t.pk, deleted: true };
    },
  },

  // ── Notes ──
  {
    name: "workspace_list_notes",
    description: "List all notes. Optionally filter by project or pinned status.",
    inputSchema: {
      type: "object",
      properties: {
        project: { type: "string", description: "Filter by project name or ID" },
        pinned: { type: "boolean", description: "Filter pinned notes only" },
      },
    },
    execute: (p) => db.listNotes({ project: p.project, pinned: p.pinned }),
  },
  {
    name: "workspace_get_note",
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
      const pk = db.createNote(p.title, {
        content: p.content, pinned: p.pinned, project: p.project,
      });
      indexEntry({ id: `note:${pk}`, type: "note", title: p.title, content: p.content ?? "", tags: [], source: "note", importedAt: new Date() });
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
      const { ref, ...fields } = p;
      db.updateNote(n.pk, fields);
      const updated = db.getNote(n.pk.toString());
      if (updated) indexEntry({ id: `note:${n.pk}`, type: "note", title: updated.title, content: updated.content, tags: [], source: "note", importedAt: updated.modifiedAt });
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
      db.deleteNote(n.pk);
      deleteChunksForEntry(`note:${n.pk}`);
      return { pk: n.pk, deleted: true };
    },
  },

  // ── Projects ──
  {
    name: "workspace_list_projects",
    description: "List all projects with task/note counts.",
    inputSchema: { type: "object", properties: {} },
    execute: () => db.listProjects(),
  },
  {
    name: "workspace_get_project",
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
      const pk = db.createProject(p.name, { summary: p.summary, color: p.color });
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
      const { ref, ...fields } = p;
      db.updateProject(pr.pk, fields);
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
      db.deleteProject(pr.pk);
      return { pk: pr.pk, deleted: true };
    },
  },

  // ── Reminders ──
  {
    name: "workspace_list_reminders",
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
        reminderDate: { type: "string", description: "When to remind, in ISO 8601 format (e.g. 2026-05-05T14:00:00). Optional." },
      },
      required: ["title"],
    },
    execute: (p) => {
      const pk = db.createReminder(p.title, { notes: p.notes, reminderDate: p.reminderDate });
      indexEntry({ id: `reminder:${pk}`, type: "reminder", title: p.title, content: p.notes ?? "", tags: [], source: "reminder", importedAt: new Date() });
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
      if (updated) indexEntry({ id: `reminder:${r.pk}`, type: "reminder", title: updated.title, content: updated.notes, tags: [], source: "reminder", importedAt: updated.modifiedAt });
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
      db.deleteReminder(r.pk);
      deleteChunksForEntry(`reminder:${r.pk}`);
      return { pk: r.pk, deleted: true };
    },
  },

  // ── Summary ──
  {
    name: "workspace_summary",
    description: "Get a summary of the entire workspace: project, task, and note counts plus recent items.",
    inputSchema: { type: "object", properties: {} },
    execute: () => {
      const projects = db.listProjects();
      const tasks = db.listTasks();
      const notes = db.listNotes();
      const reminders = db.listReminders();

      const tasksByStatus: Record<string, number> = {};
      for (const t of tasks) tasksByStatus[t.status] = (tasksByStatus[t.status] ?? 0) + 1;

      const activeReminders = reminders.filter(r => !r.isCompleted);
      const overdueReminders = activeReminders.filter(r => r.reminderDate && r.reminderDate < new Date());

      return {
        projects: { total: projects.length, items: projects.slice(0, 5).map(p => ({ pk: p.pk, name: p.name, tasks: p.taskCount, notes: p.noteCount })) },
        tasks: { total: tasks.length, byStatus: tasksByStatus, recent: tasks.slice(0, 5).map(t => ({ pk: t.pk, title: t.title, status: t.status, priority: t.priority })) },
        notes: { total: notes.length, recent: notes.slice(0, 5).map(n => ({ pk: n.pk, title: n.title, project: n.projectName })) },
        reminders: { total: reminders.length, active: activeReminders.length, overdue: overdueReminders.length, recent: activeReminders.slice(0, 5).map(r => ({ pk: r.pk, title: r.title, reminderDate: r.reminderDate })) },
      };
    },
  },
];

export const WORKSPACE_TOOL_MAP: Record<string, WorkspaceTool> = Object.fromEntries(
  WORKSPACE_TOOLS.map((t) => [t.name, t])
);

export const WORKSPACE_TOOL_NAMES = WORKSPACE_TOOLS.map((t) => t.name);
