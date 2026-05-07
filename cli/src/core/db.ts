import { Database } from "bun:sqlite";
import { join } from "path";
import { DEEPTHINK_ROOT } from "../config";

const STORE_PATH = join(DEEPTHINK_ROOT, "data", "deepthink.store");

// Core Data epoch: 2001-01-01T00:00:00Z
const CD_EPOCH = Date.UTC(2001, 0, 1) / 1000;

function toCD(date: Date): number {
  return date.getTime() / 1000 - CD_EPOCH;
}

function fromCD(ts: number): Date {
  return new Date((ts + CD_EPOCH) * 1000);
}

function formatDate(d: Date): string {
  return d.toISOString().replace("T", " ").slice(0, 19);
}

function uuidHex(): string {
  return crypto.randomUUID().replace(/-/g, "").toUpperCase();
}

function nextPK(db: Database, entity: string): { pk: number; ent: number } {
  let result: { pk: number; ent: number } | undefined;
  db.transaction(() => {
    const row = db.query("SELECT Z_ENT, Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME = ?").get(entity) as any;
    if (!row) throw new Error(`unknown entity: ${entity}`);
    const pk = row.Z_MAX + 1;
    db.query("UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_NAME = ?").run(pk, entity);
    result = { pk, ent: row.Z_ENT };
  })();
  return result!;
}

let _db: Database | null = null;
let _writeDb: Database | null = null;

function getDB(): Database {
  if (!_db) _db = new Database(STORE_PATH, { readonly: true });
  return _db;
}

function getWriteDB(): Database {
  if (!_writeDb) _writeDb = new Database(STORE_PATH);
  return _writeDb;
}

// ── Project ──

export interface ProjectRow {
  pk: number;
  id: string;
  name: string;
  summary: string;
  color: string;
  isArchived: boolean;
  createdAt: Date;
  modifiedAt: Date;
  taskCount: number;
  noteCount: number;
}

export function listProjects(): ProjectRow[] {
  const db = getDB();
  const rows = db.query(`
    SELECT p.Z_PK, hex(p.ZID) as id, p.ZNAME, p.ZSUMMARY, p.ZCOLOR, p.ZISARCHIVED,
           p.ZCREATEDAT, p.ZMODIFIEDAT,
           (SELECT COUNT(*) FROM ZTASKITEM WHERE ZPROJECT = p.Z_PK) as taskCount,
           (SELECT COUNT(*) FROM ZNOTE WHERE ZPROJECT = p.Z_PK) as noteCount
    FROM ZPROJECT p ORDER BY p.ZMODIFIEDAT DESC
  `).all() as any[];
  return rows.map(r => ({
    pk: r.Z_PK, id: r.id, name: r.ZNAME, summary: r.ZSUMMARY ?? "",
    color: r.ZCOLOR ?? "#007AFF", isArchived: !!r.ZISARCHIVED,
    createdAt: fromCD(r.ZCREATEDAT), modifiedAt: fromCD(r.ZMODIFIEDAT),
    taskCount: r.taskCount, noteCount: r.noteCount,
  }));
}

export function getProject(nameOrPk: string): ProjectRow | null {
  const projects = listProjects();
  const byPk = projects.find(p => p.pk.toString() === nameOrPk);
  if (byPk) return byPk;
  const lower = nameOrPk.toLowerCase();
  return projects.find(p => p.name.toLowerCase() === lower) ??
         projects.find(p => p.name.toLowerCase().includes(lower)) ?? null;
}

export function createProject(name: string, opts: { summary?: string; color?: string } = {}): number {
  const db = getWriteDB();
  const { pk, ent } = nextPK(db, "Project");
  const now = toCD(new Date());
  db.query(`
    INSERT INTO ZPROJECT (Z_PK, Z_ENT, Z_OPT, ZISARCHIVED, ZCREATEDAT, ZMODIFIEDAT, ZNAME, ZSUMMARY, ZCOLOR, ZID)
    VALUES (?, ?, 1, 0, ?, ?, ?, ?, ?, x'${uuidHex()}')
  `).run(pk, ent, now, now, name, opts.summary ?? "", opts.color ?? "#007AFF");
  return pk;
}

export function updateProject(pk: number, fields: Record<string, any>): void {
  const db = getWriteDB();
  const sets: string[] = [];
  const vals: any[] = [];

  if (fields.name !== undefined) { sets.push("ZNAME = ?"); vals.push(fields.name); }
  if (fields.summary !== undefined) { sets.push("ZSUMMARY = ?"); vals.push(fields.summary); }
  if (fields.color !== undefined) { sets.push("ZCOLOR = ?"); vals.push(fields.color); }
  if (fields.archived !== undefined) { sets.push("ZISARCHIVED = ?"); vals.push(fields.archived ? 1 : 0); }

  if (sets.length === 0) { return; }

  sets.push("ZMODIFIEDAT = ?");
  vals.push(toCD(new Date()));
  vals.push(pk);

  db.query(`UPDATE ZPROJECT SET ${sets.join(", ")} WHERE Z_PK = ?`).run(...vals);
}

export function deleteProject(pk: number): void {
  const db = getWriteDB();
  db.query("UPDATE ZTASKITEM SET ZPROJECT = NULL WHERE ZPROJECT = ?").run(pk);
  db.query("UPDATE ZNOTE SET ZPROJECT = NULL WHERE ZPROJECT = ?").run(pk);
  db.query("DELETE FROM ZPROJECT WHERE Z_PK = ?").run(pk);
}

// ── Task ──

export interface TaskRow {
  pk: number;
  id: string;
  title: string;
  detail: string;
  status: string;
  priority: string;
  storyPoints: number | null;
  dueDate: Date | null;
  projectPk: number | null;
  projectName: string | null;
  isArchived: boolean;
  createdAt: Date;
  modifiedAt: Date;
}

export function listTasks(opts: { status?: string; priority?: string; project?: string; excludeArchived?: boolean } = {}): TaskRow[] {
  const db = getDB();
  let where = opts.excludeArchived ? "(t.ZISARCHIVED = 0 OR t.ZISARCHIVED IS NULL)" : "1=1";
  const params: any[] = [];

  if (opts.status) { where += " AND t.ZSTATUSRAW = ?"; params.push(opts.status); }
  if (opts.priority) { where += " AND t.ZPRIORITYRAW = ?"; params.push(opts.priority); }
  if (opts.project) {
    const proj = getProject(opts.project);
    if (proj) { where += " AND t.ZPROJECT = ?"; params.push(proj.pk); }
  }

  const rows = db.query(`
    SELECT t.Z_PK, hex(t.ZID) as id, t.ZTITLE, t.ZDETAIL, t.ZSTATUSRAW, t.ZPRIORITYRAW,
           t.ZSTORYPOINTS, t.ZDUEDATE, t.ZPROJECT, t.ZISARCHIVED, t.ZCREATEDAT, t.ZMODIFIEDAT,
           p.ZNAME as projectName
    FROM ZTASKITEM t LEFT JOIN ZPROJECT p ON t.ZPROJECT = p.Z_PK
    WHERE ${where}
    ORDER BY t.ZMODIFIEDAT DESC
  `).all(...params) as any[];
  return rows.map(r => ({
    pk: r.Z_PK, id: r.id, title: r.ZTITLE, detail: r.ZDETAIL ?? "",
    status: r.ZSTATUSRAW, priority: r.ZPRIORITYRAW,
    storyPoints: r.ZSTORYPOINTS, dueDate: r.ZDUEDATE ? fromCD(r.ZDUEDATE) : null,
    projectPk: r.ZPROJECT, projectName: r.projectName ?? null,
    isArchived: !!r.ZISARCHIVED,
    createdAt: fromCD(r.ZCREATEDAT), modifiedAt: fromCD(r.ZMODIFIEDAT),
  }));
}

export function getTask(pkStr: string): TaskRow | null {
  const tasks = listTasks();
  const byPk = tasks.find(t => t.pk.toString() === pkStr);
  if (byPk) return byPk;
  const lower = pkStr.toLowerCase();
  return tasks.find(t => t.title.toLowerCase() === lower) ??
         tasks.find(t => t.title.toLowerCase().includes(lower)) ?? null;
}

export function createTask(title: string, opts: {
  detail?: string; status?: string; priority?: string;
  storyPoints?: number; dueDate?: string; project?: string;
} = {}): number {
  const db = getWriteDB();
  const { pk, ent } = nextPK(db, "TaskItem");
  const now = toCD(new Date());

  let projectPk: number | null = null;
  if (opts.project) {
    const proj = getProject(opts.project);
    if (proj) projectPk = proj.pk;
  }

  let dueDateCD: number | null = null;
  if (opts.dueDate) {
    dueDateCD = toCD(new Date(opts.dueDate));
  }

  db.query(`
    INSERT INTO ZTASKITEM (Z_PK, Z_ENT, Z_OPT, ZSTORYPOINTS, ZPROJECT, ZCOMPLETEDAT, ZCREATEDAT, ZDUEDATE, ZMODIFIEDAT, ZDETAIL, ZPRIORITYRAW, ZSTATUSRAW, ZTITLE, ZID)
    VALUES (?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, x'${uuidHex()}')
  `).run(pk, ent, opts.storyPoints ?? null, projectPk, now, dueDateCD, now, opts.detail ?? "", opts.priority ?? "None", opts.status ?? "To Do", title);
  return pk;
}

export function updateTask(pk: number, fields: Record<string, any>): void {
  const db = getWriteDB();
  const sets: string[] = [];
  const vals: any[] = [];

  if (fields.title !== undefined) { sets.push("ZTITLE = ?"); vals.push(fields.title); }
  if (fields.detail !== undefined) { sets.push("ZDETAIL = ?"); vals.push(fields.detail); }
  if (fields.status !== undefined) {
    sets.push("ZSTATUSRAW = ?"); vals.push(fields.status);
    if (fields.status === "Done") { sets.push("ZCOMPLETEDAT = ?"); vals.push(toCD(new Date())); }
    else { sets.push("ZCOMPLETEDAT = ?"); vals.push(null); }
  }
  if (fields.priority !== undefined) { sets.push("ZPRIORITYRAW = ?"); vals.push(fields.priority); }
  if (fields.storyPoints !== undefined) { sets.push("ZSTORYPOINTS = ?"); vals.push(fields.storyPoints); }
  if (fields.dueDate !== undefined) {
    sets.push("ZDUEDATE = ?");
    vals.push(fields.dueDate ? toCD(new Date(fields.dueDate)) : null);
  }
  if (fields.project !== undefined) {
    if (fields.project === null || fields.project === "none") {
      sets.push("ZPROJECT = ?"); vals.push(null);
    } else {
      const proj = getProject(fields.project);
      if (proj) { sets.push("ZPROJECT = ?"); vals.push(proj.pk); }
    }
  }

  if (sets.length === 0) { return; }

  sets.push("ZMODIFIEDAT = ?");
  vals.push(toCD(new Date()));
  vals.push(pk);

  db.query(`UPDATE ZTASKITEM SET ${sets.join(", ")} WHERE Z_PK = ?`).run(...vals);
}

export function deleteTask(pk: number): void {
  const db = getWriteDB();
  db.query("DELETE FROM Z_6TASKS WHERE Z_7TASKS = ?").run(pk);
  db.query("DELETE FROM ZTASKITEM WHERE Z_PK = ?").run(pk);
}

// ── Note ──

export interface NoteRow {
  pk: number;
  id: string;
  title: string;
  content: string;
  isPinned: boolean;
  isArchived: boolean;
  projectPk: number | null;
  projectName: string | null;
  createdAt: Date;
  modifiedAt: Date;
}

export function listNotes(opts: { project?: string; pinned?: boolean; excludeArchived?: boolean } = {}): NoteRow[] {
  const db = getDB();
  let where = opts.excludeArchived ? "(n.ZISARCHIVED = 0 OR n.ZISARCHIVED IS NULL)" : "1=1";
  const params: any[] = [];

  if (opts.pinned !== undefined) { where += " AND n.ZISPINNED = ?"; params.push(opts.pinned ? 1 : 0); }
  if (opts.project) {
    const proj = getProject(opts.project);
    if (proj) { where += " AND n.ZPROJECT = ?"; params.push(proj.pk); }
  }

  const rows = db.query(`
    SELECT n.Z_PK, hex(n.ZID) as id, n.ZTITLE, n.ZCONTENT, n.ZISPINNED, n.ZISARCHIVED, n.ZPROJECT,
           n.ZCREATEDAT, n.ZMODIFIEDAT, p.ZNAME as projectName
    FROM ZNOTE n LEFT JOIN ZPROJECT p ON n.ZPROJECT = p.Z_PK
    WHERE ${where}
    ORDER BY n.ZMODIFIEDAT DESC
  `).all(...params) as any[];
  return rows.map(r => ({
    pk: r.Z_PK, id: r.id, title: r.ZTITLE, content: r.ZCONTENT ?? "",
    isPinned: !!r.ZISPINNED, isArchived: !!r.ZISARCHIVED,
    projectPk: r.ZPROJECT, projectName: r.projectName ?? null,
    createdAt: fromCD(r.ZCREATEDAT), modifiedAt: fromCD(r.ZMODIFIEDAT),
  }));
}

export function getNote(pkStr: string): NoteRow | null {
  const notes = listNotes();
  const byPk = notes.find(n => n.pk.toString() === pkStr);
  if (byPk) return byPk;
  const lower = pkStr.toLowerCase();
  return notes.find(n => n.title.toLowerCase() === lower) ??
         notes.find(n => n.title.toLowerCase().includes(lower)) ?? null;
}

export function createNote(title: string, opts: {
  content?: string; pinned?: boolean; project?: string;
} = {}): number {
  const db = getWriteDB();
  const { pk, ent } = nextPK(db, "Note");
  const now = toCD(new Date());

  let projectPk: number | null = null;
  if (opts.project) {
    const proj = getProject(opts.project);
    if (proj) projectPk = proj.pk;
  }

  db.query(`
    INSERT INTO ZNOTE (Z_PK, Z_ENT, Z_OPT, ZISPINNED, ZPROJECT, ZCREATEDAT, ZMODIFIEDAT, ZCONTENT, ZTITLE, ZID)
    VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, x'${uuidHex()}')
  `).run(pk, ent, opts.pinned ? 1 : 0, projectPk, now, now, opts.content ?? "", title);
  return pk;
}

export function updateNote(pk: number, fields: Record<string, any>): void {
  const db = getWriteDB();
  const sets: string[] = [];
  const vals: any[] = [];

  if (fields.title !== undefined) { sets.push("ZTITLE = ?"); vals.push(fields.title); }
  if (fields.content !== undefined) { sets.push("ZCONTENT = ?"); vals.push(fields.content); }
  if (fields.pinned !== undefined) { sets.push("ZISPINNED = ?"); vals.push(fields.pinned ? 1 : 0); }
  if (fields.project !== undefined) {
    if (fields.project === null || fields.project === "none") {
      sets.push("ZPROJECT = ?"); vals.push(null);
    } else {
      const proj = getProject(fields.project);
      if (proj) { sets.push("ZPROJECT = ?"); vals.push(proj.pk); }
    }
  }

  if (sets.length === 0) { return; }

  sets.push("ZMODIFIEDAT = ?");
  vals.push(toCD(new Date()));
  vals.push(pk);

  db.query(`UPDATE ZNOTE SET ${sets.join(", ")} WHERE Z_PK = ?`).run(...vals);
}

export function deleteNote(pk: number): void {
  const db = getWriteDB();
  db.query("DELETE FROM Z_2TAGS WHERE Z_2NOTES = ?").run(pk);
  db.query("DELETE FROM ZNOTE WHERE Z_PK = ?").run(pk);
}

// ── Reminder ──

export interface ReminderRow {
  pk: number;
  id: string;
  title: string;
  notes: string;
  reminderDate: Date | null;
  isCompleted: boolean;
  completedAt: Date | null;
  createdAt: Date;
  modifiedAt: Date;
}

export function listReminders(opts: { completed?: boolean } = {}): ReminderRow[] {
  const db = getDB();
  let where = "1=1";
  const params: any[] = [];

  if (opts.completed !== undefined) {
    where += " AND r.ZISCOMPLETED = ?";
    params.push(opts.completed ? 1 : 0);
  }

  const rows = db.query(`
    SELECT r.Z_PK, hex(r.ZID) as id, r.ZTITLE, r.ZNOTES, r.ZREMINDERDATE,
           r.ZISCOMPLETED, r.ZCOMPLETEDAT, r.ZCREATEDAT, r.ZMODIFIEDAT
    FROM ZREMINDER r
    WHERE ${where}
    ORDER BY r.ZMODIFIEDAT DESC
  `).all(...params) as any[];
  return rows.map(r => ({
    pk: r.Z_PK, id: r.id, title: r.ZTITLE, notes: r.ZNOTES ?? "",
    reminderDate: r.ZREMINDERDATE ? fromCD(r.ZREMINDERDATE) : null,
    isCompleted: !!r.ZISCOMPLETED,
    completedAt: r.ZCOMPLETEDAT ? fromCD(r.ZCOMPLETEDAT) : null,
    createdAt: fromCD(r.ZCREATEDAT), modifiedAt: fromCD(r.ZMODIFIEDAT),
  }));
}

export function getReminder(pkStr: string): ReminderRow | null {
  const reminders = listReminders();
  const byPk = reminders.find(r => r.pk.toString() === pkStr);
  if (byPk) return byPk;
  const lower = pkStr.toLowerCase();
  return reminders.find(r => r.title.toLowerCase() === lower) ??
         reminders.find(r => r.title.toLowerCase().includes(lower)) ?? null;
}

export function createReminder(title: string, opts: {
  notes?: string; reminderDate?: string;
} = {}): number {
  const db = getWriteDB();
  const { pk, ent } = nextPK(db, "Reminder");
  const now = toCD(new Date());

  let reminderDateCD: number | null = null;
  if (opts.reminderDate) {
    reminderDateCD = toCD(new Date(opts.reminderDate));
  }

  db.query(`
    INSERT INTO ZREMINDER (Z_PK, Z_ENT, Z_OPT, ZISCOMPLETED, ZNOTIFICATIONSCHEDULED, ZCOMPLETEDAT, ZCREATEDAT, ZMODIFIEDAT, ZREMINDERDATE, ZNOTES, ZTITLE, ZID)
    VALUES (?, ?, 1, 0, 0, NULL, ?, ?, ?, ?, ?, x'${uuidHex()}')
  `).run(pk, ent, now, now, reminderDateCD, opts.notes ?? "", title);
  return pk;
}

export function updateReminder(pk: number, fields: Record<string, any>): void {
  const db = getWriteDB();
  const sets: string[] = [];
  const vals: any[] = [];

  if (fields.title !== undefined) { sets.push("ZTITLE = ?"); vals.push(fields.title); }
  if (fields.notes !== undefined) { sets.push("ZNOTES = ?"); vals.push(fields.notes); }
  if (fields.completed !== undefined) {
    sets.push("ZISCOMPLETED = ?"); vals.push(fields.completed ? 1 : 0);
    if (fields.completed) { sets.push("ZCOMPLETEDAT = ?"); vals.push(toCD(new Date())); }
    else { sets.push("ZCOMPLETEDAT = ?"); vals.push(null); }
  }
  if (fields.reminderDate !== undefined) {
    sets.push("ZREMINDERDATE = ?");
    vals.push(fields.reminderDate ? toCD(new Date(fields.reminderDate)) : null);
  }

  if (sets.length === 0) { return; }

  sets.push("ZMODIFIEDAT = ?");
  vals.push(toCD(new Date()));
  vals.push(pk);

  db.query(`UPDATE ZREMINDER SET ${sets.join(", ")} WHERE Z_PK = ?`).run(...vals);
}

export function deleteReminder(pk: number): void {
  const db = getWriteDB();
  db.query("DELETE FROM ZREMINDER WHERE Z_PK = ?").run(pk);
}

// ── Helpers ──

export { formatDate };
