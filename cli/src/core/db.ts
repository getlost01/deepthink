import { Database } from "bun:sqlite";
import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { DEEPTHINK_ROOT } from "../config";

const STORE_PATH = join(DEEPTHINK_ROOT, "data", "deepthink.store");

function ensureStoreExists(): void {
  if (!existsSync(STORE_PATH)) {
    throw new Error(`DeepThink workspace not found at ${STORE_PATH}. Launch the DeepThink app once to initialize it.`);
  }
}

function parseDateToCD(value: string): number {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) throw new Error(`invalid date: ${value}`);
  return toCD(d);
}

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

// Converts a 32-char hex UUID (from SQLite hex()) to the canonical lowercase
// dashed format matching Swift's UUID.uuidString, so app and CLI share the
// same entry IDs in vectors.db.
export function hexToUUID(hex: string): string {
  const h = hex.toLowerCase();
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

function nextPK(db: Database, entity: string): { pk: number; ent: number } {
  let result: { pk: number; ent: number } | undefined;
  db.transaction(() => {
    const row = db.query("SELECT Z_ENT, Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME = ?").get(entity) as any;
    if (!row) throw new Error(`unknown entity: ${entity}`);
    // Guard against a stale Z_MAX: the running app allocates PKs from its own cached
    // counter and may have inserted rows without this connection seeing the bump. Taking
    // the higher of Z_MAX and the table's actual MAX(Z_PK) avoids colliding with them.
    const table = `Z${entity.toUpperCase()}`;
    let tableMax = 0;
    try {
      const m = db.query(`SELECT MAX(Z_PK) AS m FROM ${table}`).get() as { m: number | null };
      tableMax = m?.m ?? 0;
    } catch {}
    const pk = Math.max(row.Z_MAX, tableMax) + 1;
    db.query("UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_NAME = ?").run(pk, entity);
    result = { pk, ent: row.Z_ENT };
  })();
  return result!;
}

// Core Data assigns Z_<n> numeric prefixes to entities and their many-to-many join tables
// based on model ordering; those numbers shift whenever the SwiftData schema changes. Resolve
// the join table and owning FK column at runtime by matching the column suffix (e.g. "TASKS",
// "NOTES") instead of hardcoding the number. Returns null if absent or ambiguous so callers
// skip the cleanup safely rather than corrupting unrelated rows.
const _joinCache = new Map<string, { table: string; col: string } | null>();
function resolveJoin(db: Database, ownerSuffix: string): { table: string; col: string } | null {
  const key = ownerSuffix.toUpperCase();
  if (_joinCache.has(key)) return _joinCache.get(key) ?? null;
  const tables = db.query("SELECT name FROM sqlite_master WHERE type='table' AND name GLOB 'Z_[0-9]*'").all() as {
    name: string;
  }[];
  const re = new RegExp(`^Z_\\d+${key}$`);
  const matches: { table: string; col: string }[] = [];
  for (const { name } of tables) {
    const cols = db.query(`PRAGMA table_info('${name}')`).all() as { name: string }[];
    for (const c of cols) {
      if (re.test(c.name.toUpperCase())) matches.push({ table: name, col: c.name });
    }
  }
  const result = matches.length === 1 ? matches[0] : null;
  _joinCache.set(key, result);
  return result;
}

let _db: Database | null = null;
let _writeDb: Database | null = null;

function getDB(): Database {
  if (!_db) {
    ensureStoreExists();
    _db = new Database(STORE_PATH, { readonly: true });
  }
  return _db;
}

function getWriteDB(): Database {
  if (!_writeDb) {
    ensureStoreExists();
    _writeDb = new Database(STORE_PATH);
    _writeDb.exec("PRAGMA journal_mode=WAL");
    _writeDb.exec("PRAGMA busy_timeout=5000");
    _writeDb.exec("PRAGMA synchronous=NORMAL");
    _writeDb.exec(`
      CREATE TABLE IF NOT EXISTS dt_audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_pk INTEGER NOT NULL,
        operation TEXT NOT NULL,
        snapshot TEXT,
        changed_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS dt_trash (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_pk INTEGER NOT NULL,
        snapshot TEXT NOT NULL,
        deleted_at INTEGER NOT NULL
      );
    `);
  }
  return _writeDb;
}

function auditLog(db: Database, op: "create" | "update" | "delete", type: string, pk: number, snapshot?: object): void {
  db.query(
    "INSERT INTO dt_audit_log (entity_type, entity_pk, operation, snapshot, changed_at) VALUES (?, ?, ?, ?, ?)"
  ).run(type, pk, op, snapshot ? JSON.stringify(snapshot) : null, Date.now());
}

function trashEntity(db: Database, type: string, pk: number, snapshot: object): void {
  db.query("INSERT INTO dt_trash (entity_type, entity_pk, snapshot, deleted_at) VALUES (?, ?, ?, ?)").run(
    type,
    pk,
    JSON.stringify(snapshot),
    Date.now()
  );
}

function notifySync(): void {
  try {
    execSync("notifyutil -p com.deepthink.workspace.changed 2>/dev/null || true", { stdio: "ignore" });
  } catch {}
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
  const rows = db
    .query(`
    SELECT p.Z_PK, hex(p.ZID) as id, p.ZNAME, p.ZSUMMARY, p.ZCOLOR, p.ZISARCHIVED,
           p.ZCREATEDAT, p.ZMODIFIEDAT,
           (SELECT COUNT(*) FROM ZTASKITEM WHERE ZPROJECT = p.Z_PK) as taskCount,
           (SELECT COUNT(*) FROM ZNOTE WHERE ZPROJECT = p.Z_PK) as noteCount
    FROM ZPROJECT p ORDER BY p.ZMODIFIEDAT DESC
  `)
    .all() as any[];
  return rows.map((r) => ({
    pk: r.Z_PK,
    id: r.id,
    name: r.ZNAME,
    summary: r.ZSUMMARY ?? "",
    color: r.ZCOLOR ?? "#007AFF",
    isArchived: !!r.ZISARCHIVED,
    createdAt: fromCD(r.ZCREATEDAT),
    modifiedAt: fromCD(r.ZMODIFIEDAT),
    taskCount: r.taskCount,
    noteCount: r.noteCount,
  }));
}

export function getProject(nameOrPk: string): ProjectRow | null {
  if (/^\d+$/.test(nameOrPk)) {
    const db = getDB();
    const row = db
      .query(`
      SELECT p.Z_PK, hex(p.ZID) as id, p.ZNAME, p.ZSUMMARY, p.ZCOLOR, p.ZISARCHIVED,
             p.ZCREATEDAT, p.ZMODIFIEDAT,
             (SELECT COUNT(*) FROM ZTASKITEM WHERE ZPROJECT = p.Z_PK) as taskCount,
             (SELECT COUNT(*) FROM ZNOTE WHERE ZPROJECT = p.Z_PK) as noteCount
      FROM ZPROJECT p WHERE p.Z_PK = ?
    `)
      .get(Number(nameOrPk)) as any;
    if (!row) return null;
    return {
      pk: row.Z_PK,
      id: row.id,
      name: row.ZNAME,
      summary: row.ZSUMMARY ?? "",
      color: row.ZCOLOR ?? "#007AFF",
      isArchived: !!row.ZISARCHIVED,
      createdAt: fromCD(row.ZCREATEDAT),
      modifiedAt: fromCD(row.ZMODIFIEDAT),
      taskCount: row.taskCount,
      noteCount: row.noteCount,
    };
  }
  if (!nameOrPk) return null;
  const projects = listProjects();
  const lower = nameOrPk.toLowerCase();
  const exact = projects.find((p) => p.name.toLowerCase() === lower);
  if (exact) return exact;
  const partial = projects.filter((p) => p.name.toLowerCase().includes(lower));
  return partial.length === 1 ? partial[0] : null;
}

export function createProject(
  name: string,
  opts: { summary?: string; color?: string } = {}
): { pk: number; id: string } {
  const db = getWriteDB();
  const { pk, ent } = nextPK(db, "Project");
  const now = toCD(new Date());
  const id = uuidHex();
  db.query(`
    INSERT INTO ZPROJECT (Z_PK, Z_ENT, Z_OPT, ZISARCHIVED, ZCREATEDAT, ZMODIFIEDAT, ZNAME, ZSUMMARY, ZCOLOR, ZID)
    VALUES (?, ?, 1, 0, ?, ?, ?, ?, ?, x'${id}')
  `).run(pk, ent, now, now, name, opts.summary ?? "", opts.color ?? "#007AFF");
  auditLog(db, "create", "project", pk);
  notifySync();
  return { pk, id };
}

export function updateProject(pk: number, fields: Record<string, any>): void {
  const db = getWriteDB();
  const sets: string[] = [];
  const vals: any[] = [];

  if (fields.name !== undefined) {
    sets.push("ZNAME = ?");
    vals.push(fields.name);
  }
  if (fields.summary !== undefined) {
    sets.push("ZSUMMARY = ?");
    vals.push(fields.summary);
  }
  if (fields.color !== undefined) {
    sets.push("ZCOLOR = ?");
    vals.push(fields.color);
  }
  if (fields.archived !== undefined) {
    sets.push("ZISARCHIVED = ?");
    vals.push(fields.archived ? 1 : 0);
  }

  if (sets.length === 0) {
    return;
  }

  sets.push("ZMODIFIEDAT = ?");
  vals.push(toCD(new Date()));
  vals.push(pk);

  db.query(`UPDATE ZPROJECT SET ${sets.join(", ")} WHERE Z_PK = ?`).run(...vals);
  auditLog(db, "update", "project", pk);
  notifySync();
}

export function deleteProject(pk: number): void {
  const db = getWriteDB();
  db.transaction(() => {
    const snap = db.query("SELECT * FROM ZPROJECT WHERE Z_PK = ?").get(pk) as object | undefined;
    if (snap) trashEntity(db, "project", pk, snap);
    db.query("UPDATE ZTASKITEM SET ZPROJECT = NULL WHERE ZPROJECT = ?").run(pk);
    db.query("UPDATE ZNOTE SET ZPROJECT = NULL WHERE ZPROJECT = ?").run(pk);
    db.query("DELETE FROM ZPROJECT WHERE Z_PK = ?").run(pk);
    auditLog(db, "delete", "project", pk);
  })();
  notifySync();
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
  completedAt: Date | null;
  projectPk: number | null;
  projectName: string | null;
  isArchived: boolean;
  createdAt: Date;
  modifiedAt: Date;
}

export function listTasks(
  opts: { status?: string; priority?: string; project?: string; excludeArchived?: boolean } = {}
): TaskRow[] {
  const db = getDB();
  let where = opts.excludeArchived ? "(t.ZISARCHIVED = 0 OR t.ZISARCHIVED IS NULL)" : "1=1";
  const params: any[] = [];

  if (opts.status) {
    where += " AND t.ZSTATUSRAW = ?";
    params.push(opts.status);
  }
  if (opts.priority) {
    where += " AND t.ZPRIORITYRAW = ?";
    params.push(opts.priority);
  }
  if (opts.project) {
    const proj = getProject(opts.project);
    if (proj) {
      where += " AND t.ZPROJECT = ?";
      params.push(proj.pk);
    }
  }

  const rows = db
    .query(`
    SELECT t.Z_PK, hex(t.ZID) as id, t.ZTITLE, t.ZDETAIL, t.ZSTATUSRAW, t.ZPRIORITYRAW,
           t.ZSTORYPOINTS, t.ZDUEDATE, t.ZCOMPLETEDAT, t.ZPROJECT, t.ZISARCHIVED, t.ZCREATEDAT, t.ZMODIFIEDAT,
           p.ZNAME as projectName
    FROM ZTASKITEM t LEFT JOIN ZPROJECT p ON t.ZPROJECT = p.Z_PK
    WHERE ${where}
    ORDER BY t.ZMODIFIEDAT DESC
  `)
    .all(...params) as any[];
  return rows.map((r) => ({
    pk: r.Z_PK,
    id: r.id,
    title: r.ZTITLE,
    detail: r.ZDETAIL ?? "",
    status: r.ZSTATUSRAW,
    priority: r.ZPRIORITYRAW,
    storyPoints: r.ZSTORYPOINTS,
    dueDate: r.ZDUEDATE ? fromCD(r.ZDUEDATE) : null,
    completedAt: r.ZCOMPLETEDAT ? fromCD(r.ZCOMPLETEDAT) : null,
    projectPk: r.ZPROJECT,
    projectName: r.projectName ?? null,
    isArchived: !!r.ZISARCHIVED,
    createdAt: fromCD(r.ZCREATEDAT),
    modifiedAt: fromCD(r.ZMODIFIEDAT),
  }));
}

export function getTask(pkStr: string): TaskRow | null {
  if (!pkStr) return null;
  const tasks = listTasks();
  const byPk = tasks.find((t) => t.pk.toString() === pkStr);
  if (byPk) return byPk;
  const lower = pkStr.toLowerCase();
  const exact = tasks.find((t) => t.title.toLowerCase() === lower);
  if (exact) return exact;
  // Only resolve a substring match when it's unambiguous — an ambiguous ref must not
  // silently pick the first of several (a delete/update would hit the wrong task).
  const partial = tasks.filter((t) => t.title.toLowerCase().includes(lower));
  return partial.length === 1 ? partial[0] : null;
}

export function createTask(
  title: string,
  opts: {
    detail?: string;
    status?: string;
    priority?: string;
    storyPoints?: number;
    dueDate?: string;
    project?: string;
  } = {}
): { pk: number; id: string } {
  const db = getWriteDB();
  const { pk, ent } = nextPK(db, "TaskItem");
  const now = toCD(new Date());
  const id = uuidHex();

  let projectPk: number | null = null;
  if (opts.project) {
    const proj = getProject(opts.project);
    if (proj) projectPk = proj.pk;
  }

  let dueDateCD: number | null = null;
  if (opts.dueDate) {
    dueDateCD = parseDateToCD(opts.dueDate);
  }

  db.query(`
    INSERT INTO ZTASKITEM (Z_PK, Z_ENT, Z_OPT, ZSTORYPOINTS, ZPROJECT, ZCOMPLETEDAT, ZCREATEDAT, ZDUEDATE, ZMODIFIEDAT, ZDETAIL, ZPRIORITYRAW, ZSTATUSRAW, ZTITLE, ZID)
    VALUES (?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, x'${id}')
  `).run(
    pk,
    ent,
    opts.storyPoints ?? null,
    projectPk,
    now,
    dueDateCD,
    now,
    opts.detail ?? "",
    opts.priority ?? "None",
    opts.status ?? "To Do",
    title
  );
  auditLog(db, "create", "task", pk);
  notifySync();
  return { pk, id };
}

export function updateTask(pk: number, fields: Record<string, any>): void {
  const db = getWriteDB();
  const sets: string[] = [];
  const vals: any[] = [];

  if (fields.title !== undefined) {
    sets.push("ZTITLE = ?");
    vals.push(fields.title);
  }
  if (fields.detail !== undefined) {
    sets.push("ZDETAIL = ?");
    vals.push(fields.detail);
  }
  if (fields.status !== undefined) {
    sets.push("ZSTATUSRAW = ?");
    vals.push(fields.status);
    if (fields.status === "Done") {
      sets.push("ZCOMPLETEDAT = ?");
      vals.push(toCD(new Date()));
    } else {
      sets.push("ZCOMPLETEDAT = ?");
      vals.push(null);
    }
  }
  if (fields.priority !== undefined) {
    sets.push("ZPRIORITYRAW = ?");
    vals.push(fields.priority);
  }
  if (fields.storyPoints !== undefined) {
    sets.push("ZSTORYPOINTS = ?");
    vals.push(fields.storyPoints);
  }
  if (fields.dueDate !== undefined) {
    sets.push("ZDUEDATE = ?");
    vals.push(fields.dueDate ? parseDateToCD(fields.dueDate) : null);
  }
  if (fields.project !== undefined) {
    if (fields.project === null || fields.project === "none") {
      sets.push("ZPROJECT = ?");
      vals.push(null);
    } else {
      const proj = getProject(fields.project);
      if (proj) {
        sets.push("ZPROJECT = ?");
        vals.push(proj.pk);
      }
    }
  }

  if (sets.length === 0) {
    return;
  }

  sets.push("ZMODIFIEDAT = ?");
  vals.push(toCD(new Date()));
  vals.push(pk);

  db.query(`UPDATE ZTASKITEM SET ${sets.join(", ")} WHERE Z_PK = ?`).run(...vals);
  auditLog(db, "update", "task", pk);
  notifySync();
}

export function listSubtaskIds(parentPk: number): string[] {
  const rows = getDB().query("SELECT hex(ZID) as id FROM ZTASKITEM WHERE ZPARENT = ?").all(parentPk) as {
    id: string;
  }[];
  return rows.map((r) => r.id);
}

export function deleteTask(pk: number): void {
  const db = getWriteDB();
  const taskJoin = resolveJoin(db, "TASKS");
  db.transaction(() => {
    const subtaskPKs = db.query("SELECT Z_PK FROM ZTASKITEM WHERE ZPARENT = ?").all(pk) as { Z_PK: number }[];
    for (const sub of subtaskPKs) {
      const subSnap = db.query("SELECT * FROM ZTASKITEM WHERE Z_PK = ?").get(sub.Z_PK) as object | undefined;
      if (subSnap) trashEntity(db, "task", sub.Z_PK, subSnap);
      if (taskJoin) db.query(`DELETE FROM ${taskJoin.table} WHERE ${taskJoin.col} = ?`).run(sub.Z_PK);
      db.query("DELETE FROM ZTASKITEM WHERE Z_PK = ?").run(sub.Z_PK);
      auditLog(db, "delete", "task", sub.Z_PK);
    }
    const snap = db.query("SELECT * FROM ZTASKITEM WHERE Z_PK = ?").get(pk) as object | undefined;
    if (snap) trashEntity(db, "task", pk, snap);
    if (taskJoin) db.query(`DELETE FROM ${taskJoin.table} WHERE ${taskJoin.col} = ?`).run(pk);
    db.query("DELETE FROM ZTASKITEM WHERE Z_PK = ?").run(pk);
    auditLog(db, "delete", "task", pk);
  })();
  notifySync();
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

  if (opts.pinned !== undefined) {
    where += " AND n.ZISPINNED = ?";
    params.push(opts.pinned ? 1 : 0);
  }
  if (opts.project) {
    const proj = getProject(opts.project);
    if (proj) {
      where += " AND n.ZPROJECT = ?";
      params.push(proj.pk);
    }
  }

  const rows = db
    .query(`
    SELECT n.Z_PK, hex(n.ZID) as id, n.ZTITLE, n.ZCONTENT, n.ZISPINNED, n.ZISARCHIVED, n.ZPROJECT,
           n.ZCREATEDAT, n.ZMODIFIEDAT, p.ZNAME as projectName
    FROM ZNOTE n LEFT JOIN ZPROJECT p ON n.ZPROJECT = p.Z_PK
    WHERE ${where}
    ORDER BY n.ZMODIFIEDAT DESC
  `)
    .all(...params) as any[];
  return rows.map((r) => ({
    pk: r.Z_PK,
    id: r.id,
    title: r.ZTITLE,
    content: r.ZCONTENT ?? "",
    isPinned: !!r.ZISPINNED,
    isArchived: !!r.ZISARCHIVED,
    projectPk: r.ZPROJECT,
    projectName: r.projectName ?? null,
    createdAt: fromCD(r.ZCREATEDAT),
    modifiedAt: fromCD(r.ZMODIFIEDAT),
  }));
}

export function getNote(pkStr: string): NoteRow | null {
  if (!pkStr) return null;
  const notes = listNotes();
  const byPk = notes.find((n) => n.pk.toString() === pkStr);
  if (byPk) return byPk;
  const lower = pkStr.toLowerCase();
  const exact = notes.find((n) => n.title.toLowerCase() === lower);
  if (exact) return exact;
  const partial = notes.filter((n) => n.title.toLowerCase().includes(lower));
  return partial.length === 1 ? partial[0] : null;
}

export function createNote(
  title: string,
  opts: {
    content?: string;
    pinned?: boolean;
    project?: string;
  } = {}
): { pk: number; id: string } {
  const db = getWriteDB();
  const { pk, ent } = nextPK(db, "Note");
  const now = toCD(new Date());
  const id = uuidHex();

  let projectPk: number | null = null;
  if (opts.project) {
    const proj = getProject(opts.project);
    if (proj) projectPk = proj.pk;
  }

  db.query(`
    INSERT INTO ZNOTE (Z_PK, Z_ENT, Z_OPT, ZISPINNED, ZPROJECT, ZCREATEDAT, ZMODIFIEDAT, ZCONTENT, ZTITLE, ZID)
    VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, x'${id}')
  `).run(pk, ent, opts.pinned ? 1 : 0, projectPk, now, now, opts.content ?? "", title);
  auditLog(db, "create", "note", pk);
  notifySync();
  return { pk, id };
}

export function updateNote(pk: number, fields: Record<string, any>): void {
  const db = getWriteDB();
  const sets: string[] = [];
  const vals: any[] = [];

  if (fields.title !== undefined) {
    sets.push("ZTITLE = ?");
    vals.push(fields.title);
  }
  if (fields.content !== undefined) {
    sets.push("ZCONTENT = ?");
    vals.push(fields.content);
  }
  if (fields.pinned !== undefined) {
    sets.push("ZISPINNED = ?");
    vals.push(fields.pinned ? 1 : 0);
  }
  if (fields.project !== undefined) {
    if (fields.project === null || fields.project === "none") {
      sets.push("ZPROJECT = ?");
      vals.push(null);
    } else {
      const proj = getProject(fields.project);
      if (proj) {
        sets.push("ZPROJECT = ?");
        vals.push(proj.pk);
      }
    }
  }

  if (sets.length === 0) {
    return;
  }

  sets.push("ZMODIFIEDAT = ?");
  vals.push(toCD(new Date()));
  vals.push(pk);

  db.query(`UPDATE ZNOTE SET ${sets.join(", ")} WHERE Z_PK = ?`).run(...vals);
  auditLog(db, "update", "note", pk);
  notifySync();
}

export function deleteNote(pk: number): void {
  const db = getWriteDB();
  db.transaction(() => {
    const noteJoin = resolveJoin(db, "NOTES");
    const snap = db.query("SELECT * FROM ZNOTE WHERE Z_PK = ?").get(pk) as object | undefined;
    if (snap) trashEntity(db, "note", pk, snap);
    if (noteJoin) db.query(`DELETE FROM ${noteJoin.table} WHERE ${noteJoin.col} = ?`).run(pk);
    db.query("DELETE FROM ZNOTE WHERE Z_PK = ?").run(pk);
    auditLog(db, "delete", "note", pk);
  })();
  notifySync();
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

  const rows = db
    .query(`
    SELECT r.Z_PK, hex(r.ZID) as id, r.ZTITLE, r.ZNOTES, r.ZREMINDERDATE,
           r.ZISCOMPLETED, r.ZCOMPLETEDAT, r.ZCREATEDAT, r.ZMODIFIEDAT
    FROM ZREMINDER r
    WHERE ${where}
    ORDER BY r.ZMODIFIEDAT DESC
  `)
    .all(...params) as any[];
  return rows.map((r) => ({
    pk: r.Z_PK,
    id: r.id,
    title: r.ZTITLE,
    notes: r.ZNOTES ?? "",
    reminderDate: r.ZREMINDERDATE ? fromCD(r.ZREMINDERDATE) : null,
    isCompleted: !!r.ZISCOMPLETED,
    completedAt: r.ZCOMPLETEDAT ? fromCD(r.ZCOMPLETEDAT) : null,
    createdAt: fromCD(r.ZCREATEDAT),
    modifiedAt: fromCD(r.ZMODIFIEDAT),
  }));
}

export function getReminder(pkStr: string): ReminderRow | null {
  if (!pkStr) return null;
  const reminders = listReminders();
  const byPk = reminders.find((r) => r.pk.toString() === pkStr);
  if (byPk) return byPk;
  const lower = pkStr.toLowerCase();
  const exact = reminders.find((r) => r.title.toLowerCase() === lower);
  if (exact) return exact;
  const partial = reminders.filter((r) => r.title.toLowerCase().includes(lower));
  return partial.length === 1 ? partial[0] : null;
}

export function createReminder(
  title: string,
  opts: {
    notes?: string;
    reminderDate?: string;
  } = {}
): { pk: number; id: string } {
  const db = getWriteDB();
  const { pk, ent } = nextPK(db, "Reminder");
  const now = toCD(new Date());
  const id = uuidHex();

  let reminderDateCD: number | null = null;
  if (opts.reminderDate) {
    reminderDateCD = parseDateToCD(opts.reminderDate);
  }

  db.query(`
    INSERT INTO ZREMINDER (Z_PK, Z_ENT, Z_OPT, ZISCOMPLETED, ZNOTIFICATIONSCHEDULED, ZCOMPLETEDAT, ZCREATEDAT, ZMODIFIEDAT, ZREMINDERDATE, ZNOTES, ZTITLE, ZID)
    VALUES (?, ?, 1, 0, 0, NULL, ?, ?, ?, ?, ?, x'${id}')
  `).run(pk, ent, now, now, reminderDateCD, opts.notes ?? "", title);
  auditLog(db, "create", "reminder", pk);
  notifySync();
  return { pk, id };
}

export function updateReminder(pk: number, fields: Record<string, any>): void {
  const db = getWriteDB();
  const sets: string[] = [];
  const vals: any[] = [];

  if (fields.title !== undefined) {
    sets.push("ZTITLE = ?");
    vals.push(fields.title);
  }
  if (fields.notes !== undefined) {
    sets.push("ZNOTES = ?");
    vals.push(fields.notes);
  }
  if (fields.completed !== undefined) {
    sets.push("ZISCOMPLETED = ?");
    vals.push(fields.completed ? 1 : 0);
    if (fields.completed) {
      sets.push("ZCOMPLETEDAT = ?");
      vals.push(toCD(new Date()));
    } else {
      sets.push("ZCOMPLETEDAT = ?");
      vals.push(null);
    }
  }
  if (fields.reminderDate !== undefined) {
    sets.push("ZREMINDERDATE = ?");
    vals.push(fields.reminderDate ? parseDateToCD(fields.reminderDate) : null);
  }

  if (sets.length === 0) {
    return;
  }

  sets.push("ZMODIFIEDAT = ?");
  vals.push(toCD(new Date()));
  vals.push(pk);

  db.query(`UPDATE ZREMINDER SET ${sets.join(", ")} WHERE Z_PK = ?`).run(...vals);
  auditLog(db, "update", "reminder", pk);
  notifySync();
}

export function deleteReminder(pk: number): void {
  const db = getWriteDB();
  db.transaction(() => {
    const snap = db.query("SELECT * FROM ZREMINDER WHERE Z_PK = ?").get(pk) as object | undefined;
    if (snap) trashEntity(db, "reminder", pk, snap);
    db.query("DELETE FROM ZREMINDER WHERE Z_PK = ?").run(pk);
    auditLog(db, "delete", "reminder", pk);
  })();
  notifySync();
}

// ── Helpers ──

export { formatDate };
