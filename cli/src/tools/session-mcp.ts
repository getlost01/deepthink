import { retrieveContextHybrid } from "../core/context-engine";
import { createProject, createTask, getProject, hexToUUID, listNotes, listTasks } from "../core/db";
import { indexEntry, taskContent } from "../core/embedding-service";
import {
  type Bucket,
  type BucketType,
  gitInfo,
  linkedProject,
  listBuckets,
  resolveBucket,
  touchBucket,
} from "./buckets";
import * as knowledge from "./knowledge";

export interface MCPTool {
  name: string;
  description: string;
  inputSchema: Record<string, any>;
  execute: (params: Record<string, any>) => any;
}

const SESSION_SOURCE = "sessions";

// Pull bullet items out of a markdown section whose header matches `re`.
function extractSection(content: string, re: RegExp): string[] {
  const lines = content.split("\n");
  const items: string[] = [];
  let inSection = false;
  for (const line of lines) {
    if (/^#{1,6}\s/.test(line)) {
      inSection = re.test(line.replace(/^#{1,6}\s*/, "").trim());
      continue;
    }
    if (!inSection) continue;
    const m = line.match(/^\s*[-*]\s+(.*)$/);
    if (m) {
      const text = m[1].trim();
      if (text && !/^none\.?$/i.test(text)) items.push(text);
    }
  }
  return items;
}

function bucketTags(b: Bucket, extra: string[] = []): string[] {
  return ["session-log", `bucket:${b.id}`, `type:${b.type}`, ...extra].filter(Boolean);
}

// First markdown heading of a session log, used as a compact title.
function sessionTitle(content: string): string {
  const h = content.split("\n").find((l) => l.startsWith("#"));
  return h ? h.replace(/^#+\s*/, "").trim() : "(untitled session)";
}

type NoteKind = "decision" | "gotcha" | "snippet" | "insight" | "context";

// Best-effort classification of a free-form fact into a note kind, so a single
// "remember this" capture lands with the right kind without the caller choosing.
function classifyKind(content: string): NoteKind {
  const c = content.toLowerCase();
  if (/```|\bfunction\b|\bconst \w+ =|\bimport \b|\bdef \b|\bclass \b/.test(content)) return "snippet";
  if (/\b(decided|decision|chose|opted|going with|we'?ll use|will use|settled on|approach is)\b/.test(c))
    return "decision";
  if (/\b(gotcha|caveat|careful|watch out|pitfall|footgun|do ?n'?t|broke|breaks|fails?|bug|workaround)\b/.test(c))
    return "gotcha";
  if (/\b(til|learned|turns out|realized|insight|noticed|note that|fyi)\b/.test(c)) return "insight";
  return "context";
}

// First non-trivial line of content, stripped of markdown markers — used as a
// compact, human-readable title when none is supplied.
function firstMeaningfulLine(content: string): string {
  return (
    content
      .split("\n")
      .map((l: string) =>
        l
          .replace(/^#+\s*/, "")
          .replace(/^[-*>]\s*/, "")
          .trim()
      )
      .find((l: string) => l.length > 3) ?? ""
  );
}

// Persist a single atomic fact to a bucket's session-notes channel, indexed on its
// own so it surfaces independently in retrieval. Shared by the `note` action and the
// generic `remember` tool.
function saveNote(
  bucket: Bucket,
  content: string,
  kind: NoteKind,
  explicitTitle?: string,
  extraTags: string[] = []
): { kind: NoteKind; title: string; path: string } {
  const title = explicitTitle ?? `${kind}: ${firstMeaningfulLine(content).slice(0, 70)}`.trim();
  const tags = bucketTags(bucket, [`kind:${kind}`, ...extraTags]);
  const path = knowledge.saveIntegrationData(
    "session-notes",
    bucket.id,
    content,
    { bucket: bucket.id, bucket_type: bucket.type, kind },
    title,
    tags
  );
  return { kind, title, path };
}

// Normalize a task title for fuzzy duplicate detection (case/punctuation-insensitive).
function normalizeTitle(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

// Create workspace tasks for open follow-ups, linked to a project named after
// the bucket (auto-created if missing). Skips items that already exist as an open
// task in the project so repeated syncs don't pile up duplicates. Returns the
// titles actually created.
function promoteOpenItems(bucket: Bucket, items: string[]): string[] {
  if (items.length === 0) return [];
  const projectName = bucket.name;
  if (!getProject(projectName)) {
    try {
      createProject(projectName, { summary: `Auto-created for ${bucket.id} session follow-ups` });
    } catch {}
  }

  // Existing open tasks in this project — used to suppress duplicates.
  const seen = new Set<string>();
  try {
    for (const t of listTasks({ project: projectName, excludeArchived: true })) {
      if (!/^done$/i.test(t.status)) seen.add(normalizeTitle(t.title));
    }
  } catch {}
  const isDuplicate = (title: string): boolean => {
    const n = normalizeTitle(title);
    if (!n) return true;
    if (seen.has(n)) return true;
    for (const e of seen) {
      if (e.length > 8 && (e.includes(n) || n.includes(e))) return true;
    }
    return false;
  };

  const created: string[] = [];
  for (const item of items.slice(0, 25)) {
    const title = item.length > 200 ? item.slice(0, 200) : item;
    if (isDuplicate(title)) continue;
    seen.add(normalizeTitle(title));
    try {
      const { id } = createTask(title, {
        detail: `From session sync · bucket ${bucket.id}`,
        project: projectName,
      });
      indexEntry({
        id: `task:${hexToUUID(id)}`,
        type: "task",
        title,
        content: taskContent(title, "", "To Do", false),
        tags: [],
        source: "task",
        importedAt: new Date(),
      });
      created.push(title);
    } catch {}
  }
  return created;
}

export const SESSION_TOOLS: MCPTool[] = [
  {
    name: "knowledge_session",
    description:
      "Capture and recall Claude Code session context, scoped to a bucket (a repo, topic, or area). " +
      "Buckets are resolved from the git remote of `cwd` (falling back to the folder name), so the same repo always maps to the same bucket. Set `action`:\n" +
      "- sync: persist a session summary to the bucket. Requires content; optional cwd, bucket, type, title, branch, date, tags, openItems, promoteOpenItems (default true → creates workspace tasks for follow-ups).\n" +
      "- note: capture a single atomic fact mid-session (a decision, gotcha, snippet, or insight) scoped to the bucket. Requires content; optional kind, title, cwd, bucket, type, tags. Indexed on its own so it's retrievable independently — prefer this over a full sync for one-off learnings.\n" +
      "- recall: warm a new session with this bucket's recent history. Optional cwd, bucket, type, limit (default 5), query (scoped relevance search).\n" +
      "- list: list all known buckets with session counts and last-active time.",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["sync", "note", "recall", "list"], description: "Operation to perform" },
        kind: {
          type: "string",
          enum: ["decision", "gotcha", "snippet", "insight", "context"],
          description: "note: the kind of atomic fact being captured (default: context)",
        },
        cwd: {
          type: "string",
          description:
            "Working directory of the agent's repo — used to resolve the bucket from git. Defaults to the server cwd.",
        },
        bucket: {
          type: "string",
          description: "Explicit bucket name/id, overriding git resolution (required for topic/area)",
        },
        type: { type: "string", enum: ["repo", "topic", "area"], description: "Bucket type (default: repo)" },
        content: { type: "string", description: "Session summary markdown (sync)" },
        title: { type: "string", description: "Session title (sync; auto-derived if omitted)" },
        branch: { type: "string", description: "Git branch (sync; auto-detected from cwd if omitted)" },
        date: { type: "string", description: "Session date YYYY-MM-DD (sync; defaults to today)" },
        tags: { type: "array", items: { type: "string" }, description: "Extra tags (sync)" },
        openItems: {
          type: "array",
          items: { type: "string" },
          description:
            "Open follow-ups (sync). If omitted, parsed from an 'Open items'/'Follow-ups' section in content.",
        },
        promoteOpenItems: {
          type: "boolean",
          description: "sync: create workspace tasks for open items (default true)",
        },
        limit: { type: "number", description: "recall: number of recent sessions (default 5)" },
        query: { type: "string", description: "recall: run a relevance search scoped to this bucket" },
      },
      required: ["action"],
    },
    execute: async (p) => {
      switch (p.action) {
        case "list": {
          const buckets = listBuckets();
          return { buckets, count: buckets.length };
        }

        case "sync": {
          if (!p.content) throw new Error(`'content' is required for action 'sync'`);
          const bucket = resolveBucket({ cwd: p.cwd, name: p.bucket, type: p.type as BucketType });
          const branch = p.branch ?? (bucket.type === "repo" && p.cwd ? gitInfo(p.cwd).branch : undefined);
          const date = p.date ?? new Date().toISOString().slice(0, 10);
          const title = p.title ?? `Session ${date}`;
          const tags = bucketTags(bucket, [date, ...(branch ? [branch] : []), ...(p.tags ?? [])]);

          const path = knowledge.saveIntegrationData(
            SESSION_SOURCE,
            bucket.id,
            p.content,
            { bucket: bucket.id, bucket_type: bucket.type, ...(branch ? { branch } : {}) },
            title,
            tags
          );
          touchBucket(bucket.id);

          const openItems =
            (p.openItems as string[] | undefined) ?? extractSection(p.content, /open items|follow.?ups/i);
          const promote = p.promoteOpenItems !== false;
          const tasksCreated = promote ? promoteOpenItems(bucket, openItems) : [];

          // Keep the bucket lean — roll up older sessions once it grows past the threshold.
          let compactedArchive: string | null = null;
          try {
            compactedArchive = await knowledge.compactSessions(bucket.id);
          } catch {}

          return { bucket, title, path, openItems, tasksCreated, ...(compactedArchive ? { compactedArchive } : {}) };
        }

        case "note": {
          if (!p.content) throw new Error(`'content' is required for action 'note'`);
          const bucket = resolveBucket({ cwd: p.cwd, name: p.bucket, type: p.type as BucketType });
          const kind = (p.kind as NoteKind) ?? "context";
          const saved = saveNote(bucket, p.content, kind, p.title, p.tags ?? []);
          return { bucket, ...saved };
        }

        case "recall": {
          const bucket = resolveBucket({ cwd: p.cwd, name: p.bucket, type: p.type as BucketType });
          const limit = p.limit ?? 5;
          const entries = knowledge.loadIntegrationData(SESSION_SOURCE, bucket.id, limit);
          const sessions = entries.map((e) => ({ file: e.file, content: e.content }));
          const openFollowUps = [
            ...new Set(entries.flatMap((e) => extractSection(e.content, /open items|follow.?ups/i))),
          ];

          const relevant = p.query
            ? retrieveContextHybrid(p.query, { topK: 8, agentScope: [`bucket:${bucket.id}`] }).parts
            : undefined;

          return {
            bucket,
            sessionCount: sessions.length,
            sessions,
            openFollowUps,
            ...(relevant ? { relevant } : {}),
            hint:
              sessions.length === 0
                ? "No prior sessions for this bucket yet. Run /deepthink:sync-session at the end of your work to start the history."
                : "Use these to resume context. openFollowUps are unresolved items from past sessions.",
          };
        }

        default:
          throw new Error(`unknown action: ${p.action}. Use one of: sync, note, recall, list`);
      }
    },
  },
];

// 360° view of a project: unifies the session bucket, its workspace tasks/notes,
// and its knowledge (decisions/context) under one resolved identity.
SESSION_TOOLS.push({
  name: "project_context",
  description:
    "Full 360° snapshot of a project, resolved from the git remote of `cwd` (or an explicit bucket). " +
    "Unifies three things that are otherwise separate: the session bucket (recent sessions + open follow-ups), " +
    "the workspace project (open tasks, notes), and the knowledge project (decisions, context). " +
    "Use at the start of work, or to answer 'where does this project stand?'. Optional `query` adds a bucket-scoped relevance search.",
  inputSchema: {
    type: "object",
    properties: {
      cwd: {
        type: "string",
        description: "Repo working directory — resolves the project from git. Defaults to server cwd.",
      },
      bucket: { type: "string", description: "Explicit bucket/project name, overriding git resolution" },
      type: { type: "string", enum: ["repo", "topic", "area"], description: "Bucket type (default: repo)" },
      query: { type: "string", description: "Optional focus query → bucket-scoped relevance search" },
      sessionLimit: { type: "number", description: "Recent sessions to include (default 5)" },
      taskLimit: { type: "number", description: "Open tasks to include (default 15)" },
    },
    required: [],
  },
  execute: (p) => {
    const bucket = resolveBucket({ cwd: p.cwd, name: p.bucket, type: p.type as BucketType });
    const projName = linkedProject(bucket);

    // Sessions + open follow-ups
    const sessionEntries = knowledge.loadIntegrationData("sessions", bucket.id, p.sessionLimit ?? 5);
    const sessions = sessionEntries.map((e) => ({ title: sessionTitle(e.content), file: e.file }));
    const openFollowUps = [
      ...new Set(sessionEntries.flatMap((e) => extractSection(e.content, /open items|follow.?ups/i))),
    ];

    // Workspace project
    const wsProject = getProject(projName);
    const allTasks = wsProject ? listTasks({ project: projName, excludeArchived: true }) : [];
    const openTasks = allTasks.filter((t) => !/^done$/i.test(t.status));
    const taskCounts: Record<string, number> = {};
    for (const t of allTasks) taskCounts[t.status] = (taskCounts[t.status] ?? 0) + 1;
    const notes = wsProject ? listNotes({ project: projName, excludeArchived: true }) : [];

    // Knowledge project (decisions/context)
    const k = knowledge.loadProjectKnowledge(projName);
    const trim = (s: string, n: number) => (s.length > n ? `${s.slice(-n)}` : s);

    // Optional scoped relevance search
    const relevant = p.query
      ? retrieveContextHybrid(p.query, { topK: 8, agentScope: [`bucket:${bucket.id}`] }).parts.map((r) => ({
          title: r.title,
          score: r.score,
        }))
      : undefined;

    return {
      project: {
        id: bucket.id,
        name: bucket.name,
        type: bucket.type,
        gitRemote: bucket.gitRemote,
        path: bucket.path,
        sessionCount: bucket.sessionCount,
        lastSessionAt: bucket.lastSessionAt,
        links: {
          workspaceProject: wsProject ? projName : null,
          knowledgeProject: k.context || k.decisions || k.artifacts.length ? projName : null,
        },
      },
      sessions,
      openFollowUps,
      tasks: {
        open: openTasks
          .slice(0, p.taskLimit ?? 15)
          .map((t) => ({ pk: t.pk, title: t.title, status: t.status, priority: t.priority })),
        counts: taskCounts,
        openCount: openTasks.length,
      },
      notes: notes.slice(0, 15).map((n) => ({ pk: n.pk, title: n.title })),
      knowledge: {
        decisions: k.decisions ? trim(k.decisions, 2000) : "",
        contextTail: k.context ? trim(k.context, 1500) : "",
        artifacts: k.artifacts.length,
      },
      ...(relevant ? { relevant } : {}),
      hint:
        !wsProject && bucket.sessionCount === 0
          ? "New project — no sessions, tasks, or knowledge yet."
          : "Unified view: sessions+follow-ups (bucket), tasks+notes (workspace), decisions+context (knowledge).",
    };
  },
});

// The one generic "save this" entry point. Auto-classifies the fact's kind and
// auto-scopes it to the current repo's bucket (resolved from git via `cwd`), so the
// caller doesn't have to choose between note/sync/project-knowledge or compute a
// scope. Use this for any mid-work decision, gotcha, snippet, or insight worth
// keeping; it's indexed on its own and surfaces precisely in later retrieval.
SESSION_TOOLS.push({
  name: "remember",
  description:
    "Save a single fact to long-term memory, auto-scoped to the current repo. THE default capture tool — " +
    "use it whenever something is worth remembering (a decision, gotcha, snippet, or insight) without deciding where it goes. " +
    "The kind is auto-detected from the content unless you pass `kind`; the bucket is resolved from the git remote of `cwd`. " +
    "For a whole-session summary use `knowledge_session {action:'sync'}` instead; for cross-repo/general knowledge use `knowledge_project {action:'save'}`.",
  inputSchema: {
    type: "object",
    properties: {
      content: { type: "string", description: "The fact to remember (markdown ok). Required." },
      kind: {
        type: "string",
        enum: ["decision", "gotcha", "snippet", "insight", "context"],
        description: "Override the auto-detected kind",
      },
      title: { type: "string", description: "Optional title (auto-derived from content if omitted)" },
      cwd: {
        type: "string",
        description: "Repo working directory — resolves the bucket from git. Defaults to server cwd.",
      },
      bucket: {
        type: "string",
        description: "Explicit bucket name/id, overriding git resolution (required for topic/area)",
      },
      type: { type: "string", enum: ["repo", "topic", "area"], description: "Bucket type (default: repo)" },
      tags: { type: "array", items: { type: "string" }, description: "Extra tags" },
    },
    required: ["content"],
  },
  execute: (p) => {
    if (!p.content) throw new Error(`'content' is required`);
    const bucket = resolveBucket({ cwd: p.cwd, name: p.bucket, type: p.type as BucketType });
    const kind = (p.kind as NoteKind) ?? classifyKind(p.content);
    const saved = saveNote(bucket, p.content, kind, p.title, p.tags ?? []);
    return {
      bucket,
      ...saved,
      hint: `Remembered as ${kind} in "${bucket.name}". Retrieve later with smart_query / unified_search (auto-scoped to this repo).`,
    };
  },
});

export const SESSION_TOOL_MAP: Record<string, MCPTool> = Object.fromEntries(SESSION_TOOLS.map((t) => [t.name, t]));
