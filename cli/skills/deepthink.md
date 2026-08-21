---
description: DeepThink universal assistant. Single entry point for knowledge, tasks, notes, projects, agents, skills, and rules. Routes any query — search, capture, CRUD, summarize, or reason — to the right tool.
---

Route `$ARGUMENTS` to the best `mcp__deepthink__*` tool. Call directly when intent is clear. When ambiguous, call `mcp__deepthink__smart_query` first (it auto-routes and auto-scopes to this repo), then decide.

All tools are called as `mcp__deepthink__<tool>`. Most are **action-based**: pass `action` plus the relevant fields.

## Start-of-work / "where does this stand?"

Before doing project work — and at the top of any subagent you spawn for this repo — call
`project_context` (optionally with `query`). It returns the unified 360° view: recent sessions,
open follow-ups, open tasks, notes, and decisions for the repo (resolved from git via `cwd`).
This is the cheapest way to give yourself or a subagent the right context before acting.

## Route map

| Intent signals | Tool / call |
|---|---|
| **Search / retrieve** | |
| anything ambiguous, or "what about / help me think / plan" | `smart_query {query}` — DEFAULT, auto-scopes to this repo |
| search / find / look for / do I have / where is (across all types) | `unified_search {query}` |
| what do I know about / context on / brief me on / catch me up | `knowledge_context {query}` |
| where does this project stand / project status / catch up on this repo | `project_context {cwd}` |
| knowledge stats / how much stored | `knowledge_stats` |
| **Knowledge** | |
| remember this / save this fact / note this down (auto-scoped, auto-classified) | `remember {content, cwd}` (or `/deepthink:remember`) — DEFAULT capture |
| save a one-off decision/gotcha/snippet with an explicit kind | `knowledge_session {action:"note", kind, content, cwd}` |
| save general knowledge / project context | `knowledge_project {action:"save", project, content, type}` |
| load project knowledge | `knowledge_project {action:"load", project}` |
| capture into an integration channel | `knowledge_integration {action:"capture", ...}` |
| **Sessions** | |
| save / sync this session | `knowledge_session {action:"sync", cwd, content}` (or `/deepthink:sync-session`) |
| warm up / resume / what was I doing here | `knowledge_session {action:"recall", cwd}` (or `/deepthink:recall`) |
| list buckets / known repos | `knowledge_session {action:"list"}` |
| **Workspace** (action ∈ list \| get \| create \| update \| delete) | |
| tasks / todos / add task / mark done / update / delete | `workspace_task {action, ...}` |
| break a task down / add a subtask / list a task's subtasks | `workspace_task` + `parent` (see Ledger below) |
| notes / jot down / edit note / delete note | `workspace_note {action, ...}` |
| projects / new project / rename / archive | `workspace_project {action, ...}` |
| reminders / remind me / reschedule / cancel | `workspace_reminder {action, ...}` |
| query-relevant tasks+notes+reminders snapshot | `workspace_context {query}` (auto-scopes to this repo) |
| workspace summary / counts / digest | `workspace_summary` |
| **Agents / Skills / Rules** (action ∈ list \| get \| create \| delete) | |
| agents | `agent {action, ...}` |
| skills | `skill {action, ...}` |
| rules | `rule {action, ...}` |
| **Overview** | |
| what can you do / what is deepthink / what data exists | `deepthink_overview` |

## Ledger: project → task → subtask

`workspace_task` is a two-level ledger. Use it for multi-step work instead of one vague task:

- **Create a subtask:** `workspace_task {action:"create", title, parent:"<parent task ID or title>"}`
  (add `project` on the parent; subtasks inherit nothing automatically).
- **Only the top level:** `workspace_task {action:"list", topLevelOnly:true}` — the right default
  for "what am I working on", since it hides the noise of every child.
- **One task's children:** `workspace_task {action:"list", parent:"<ref>"}`, or
  `workspace_task {action:"get", ref}` which returns a `subtasks` summary array.
- **Re-parent / promote:** `workspace_task {action:"update", ref, parent:"<ref>"}`;
  `parent:"none"` makes it top-level again. Cycles and self-parenting are rejected.
- **Deleting a parent deletes its subtasks** — promote anything worth keeping first.

Shape a plan as one parent task per outcome and subtasks per step, then close subtasks as you go.

## Notes on retrieval scope

`smart_query`, `workspace_context`, and `unified_search` automatically boost results from the
**current repo's project** (resolved from the working directory) — you don't need to pass a
bucket for the common case. Pass `cwd`/`bucket` only to target a *different* project, or
`bucket` on `unified_search` to hard-restrict knowledge to one repo's sessions.

## Multi-step requests

For compound asks ("find the auth notes and make a task"), chain calls: retrieve first
(`smart_query` / `unified_search`), then mutate (`workspace_task {action:"create"}`). Prefer the
summary/`*_context` tools over raw `{action:"list"}` dumps when you only need context.
