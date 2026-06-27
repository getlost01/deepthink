# MCP Integration

DeepThink ships a full MCP (Model Context Protocol) server - `deepthink-mcp` - giving **any AI agent** access to your workspace, knowledge base, agents, skills, and rules through a standardized protocol.

> **Agent compatibility**
>
> `deepthink-mcp` is **not Claude-specific**. Any MCP-capable client works:
> Claude Code, Cursor, VS Code Copilot, Windsurf, Continue, or any host that speaks MCP over stdio.
>
> The **in-app AI** (chat, agents, skills, rules) is the only part that requires the **Claude CLI** - it spawns Claude as a local subprocess. Everything exposed through MCP and the CLI is model-agnostic: any agent can read and write your workspace, run hybrid retrieval, and query the knowledge base without Claude.

## Setup

### Cursor / VS Code

`.cursor/mcp.json` or `.vscode/mcp.json`:

```json
{
  "mcpServers": {
    "deepthink": {
      "command": "deepthink-mcp",
      "args": []
    }
  }
}
```

`deepthink-mcp` must be on your `PATH` or referenced by full path. The binary is auto-installed by the DeepThink app on first launch to `~/.local/bin/deepthink-mcp`.

### Claude Code

```bash
claude mcp add --transport stdio --scope user deepthink -- ~/.local/bin/deepthink-mcp
```

Or from inside the app: **Settings → Claude → Register Global MCP** (runs the above automatically).

### Claude Desktop

`~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "deepthink": {
      "command": "/Users/YOU/.local/bin/deepthink-mcp",
      "args": []
    }
  }
}
```

---

## How It Works

```text
AI client (Cursor · Claude Code · Windsurf · VS Code Copilot · any MCP host)
    │  MCP request (stdio)
    ▼
deepthink-mcp
    │  reads/writes
    ├── ~/DeepThink/data/deepthink.store   (tasks, notes, projects, reminders)
    ├── ~/DeepThink/data/vectors.db        (embeddings, chunks)
    ├── ~/DeepThink/knowledge/             (knowledge base markdown)
    └── ~/DeepThink/.claude/              (agents, rules, skills)
```

No network calls. No authentication. Purely local.

Mutating operations (create/update/delete) go through `db.ts`, which:

1. Writes to `deepthink.store` via parameterized SQLite
2. Appends a record to `dt_audit_log`
3. Saves a snapshot to `dt_trash` before hard deletes
4. Fires `notifyutil -p com.deepthink.workspace.changed` to trigger live sync in the macOS app

---

## Reads vs. writes

CRUD is consolidated into one tool per entity that takes an `action` parameter, so read vs. write is determined by the `action`, not the tool: `list` and `get` (and `load`) are read-only; `create` / `update` / `delete` (and `save` / `capture` / `compress` / `archive`) mutate. The dedicated query tools (`smart_query`, `knowledge_context`, `workspace_context`, `unified_search`, `deepthink_overview`, `knowledge_search`, `knowledge_stats`, `workspace_summary`, `workspace_resolve_deeplink`) are always read-only.

---

## Tool Reference (19 tools)

### Smart / Context Tools

These run hybrid BM25 + semantic retrieval and are the recommended starting point for any agent needing workspace context.

| Tool | readonly | Description |
|------|----------|-------------|
| `smart_query` | true | Auto-selects summary or full mode; runs hybrid retrieval; returns token-budgeted ranked results across knowledge + workspace |
| `knowledge_context` | true | Hybrid retrieval over knowledge FS only; supports `projectScope`, `knowledgeScope` (tags), `topK` (default 10), `maxTokens` (default 4000) |
| `workspace_context` | true | Hybrid retrieval over tasks, notes, reminders; returns scored items filtered by relevance |
| `unified_search` | true | Single call across all four types (knowledge, task, note, reminder); content field fully populated for workspace items; supports type filter |
| `deepthink_overview` | true | Compact system overview ~200 tokens: project count, task counts by status, note count, knowledge stats, recent activity |


### Workspace - Entities (CRUD)

Each entity is a single tool that takes an `action` of `list` / `get` / `create` / `update` / `delete`. `list` and `get` are read-only; `create` / `update` / `delete` mutate (log to `dt_audit_log`, snapshot to `dt_trash` on delete, cascade vector-chunk cleanup).

| Tool | `action` values | Description |
|------|-----------------|-------------|
| `workspace_task` | list, get, create, update, delete | Tasks. `list` filters by status/priority/project, paginated (50/page); `get` by ID or fuzzy name; `create` needs `title`; `update`/`delete` need `ref`. `dueDate`/`project` accept `'none'` to clear. |
| `workspace_note` | list, get, create, update, delete | Notes. `list` filters by project/pinned, paginated; `create` needs `title` (+ markdown `content`); `update`/`delete` need `ref`. `project` accepts `'none'` to unassign. |
| `workspace_project` | list, get, create, update, delete | Projects. `list` returns task/note counts, paginated; `create` needs `name`; `update` toggles archive via `archived`; `delete` unassigns its tasks/notes. |
| `workspace_reminder` | list, get, create, update, delete | Reminders. `list` filters by `completed`; `create` needs `title` (+ optional ISO `reminderDate`); `update` sets `completed`/`reminderDate` (`'none'` clears). |

### Workspace - Deep Links

| Tool | readonly | Description |
|------|----------|-------------|
| `workspace_resolve_deeplink` | true | Resolve `deepthink://type/UUID` URLs to full item content. Pass `url` for one, or `urls` (array) to resolve many in one call (returns map of URL → item or error). |

URL format: `deepthink://task/UUID`, `deepthink://note/UUID`, `deepthink://project/UUID`, `deepthink://reminder/UUID`, `deepthink://knowledge?id=<id>`.

### Workspace - Utility

| Tool | readonly | Description |
|------|----------|-------------|
| `workspace_summary` | true | Full workspace snapshot: project/task/note/reminder counts + recent items. |
| `workspace_reindex` | - | Trigger a full re-embedding of all workspace items into `vectors.db`. Use after bulk imports or when search quality degrades. |

### Knowledge Base

| Tool | `action` values | Description |
|------|-----------------|-------------|
| `knowledge_project` | list, load, save, archive | Knowledge projects. `list` all projects; `load` a project's context/decisions/artifacts; `save` needs `content` (+ `type`: `context`/`decision`/`artifact`); `archive` compresses a project into a summary file. |
| `knowledge_integration` | list, load, capture, compress | Integration data. `list` sources + channels; `load` recent entries; `capture` needs `source`/`channel`/`content` (+ optional `title`/`tags`/`metadata`); `compress` archives a channel's entries. |
| `knowledge_search` | _(read-only)_ | Keyword search across integration data and captured entries. |
| `knowledge_stats` | _(read-only)_ | Overview: project count, integration channels, archive count. |

### Config - Agents / Rules / Skills

Each is a single tool taking an `action` of `list` / `get` / `create` / `delete`. `list` and `get` are read-only.

| Tool | `action` values | Description |
|------|-----------------|-------------|
| `agent` | list, get, create, delete | AI agents. `create` needs `name`, `role`, `systemPrompt` (+ optional `icon`, `model`, `skills`, `knowledgeScope`). |
| `rule` | list, get, create, delete | Prompt-injection rules. `create` needs `name`, `trigger`, `instruction` (+ optional `icon`, `category`). |
| `skill` | list, get, create, delete | Slash-command skills. `create` needs `name`, `promptTemplate` (+ optional `category`, `icon`, `model`, `trigger`, `systemPrompt`). |

---

## Governance

### Audit Log

Every mutating tool call appends a record to `dt_audit_log` in `deepthink.store`:

```text
entity_type | entity_pk | operation | snapshot (JSON) | changed_at (ms)
```

### Trash / Recovery

Before every hard delete, `db.ts` writes the full row JSON to `dt_trash`. Rows can be manually restored by inserting the snapshot back into the source table.

### Darwin Sync (CLI → App)

After every mutating operation, `db.ts` fires:

```bash
notifyutil -p com.deepthink.workspace.changed
```

The macOS app's `CLISyncService.swift` listens for this Darwin notification and increments `AppState.externalSyncToken`, triggering a SwiftUI re-render. Changes made via MCP tools appear in the app UI within milliseconds.

---

## Example Agent Workflows

### Morning standup prep

```text
1. deepthink_overview                    → orient: counts + recent activity
2. workspace_task {action:"list"}        → filter status="In Progress"
3. knowledge_context                     → query="blockers or decisions from last week"
```

### Research and capture

```text
1. smart_query                              → query="everything about auth architecture"
2. knowledge_project {action:"save"}        → save findings as decision or artifact
```

### Create tasks from a meeting

```text
1. workspace_project {action:"list"}      → find the right project ID
2. workspace_task {action:"create"}       → one call per action item
3. workspace_note {action:"create"}       → save meeting notes with full markdown
```

### Audit recent changes

```text
SELECT * FROM dt_audit_log ORDER BY changed_at DESC LIMIT 50;
```

### Recover a deleted item

```text
SELECT snapshot FROM dt_trash WHERE entity_type='task' ORDER BY deleted_at DESC LIMIT 1;
-- parse JSON, INSERT back into ZTASKITEM
```

---

## Key Files

| File | Role |
|------|------|
| `cli/src/mcp-server.ts` | Server entry point, tool + resource registration, ALL_TOOLS array |
| `cli/src/tools/smart-mcp.ts` | smart_query, knowledge_context, workspace_context, unified_search, deepthink_overview |
| `cli/src/tools/workspace.ts` | Workspace CRUD tools (tasks, notes, projects, reminders, deep links, summary) |
| `cli/src/tools/knowledge-mcp.ts` | Knowledge base tools |
| `cli/src/tools/config-mcp.ts` | Agent, rule, skill CRUD tools |
| `cli/src/core/db.ts` | SQLite writes, dt_audit_log, dt_trash, notifyutil sync |
| `Services/MCPService.swift` | App-side MCP config generation and query dispatch |
| `Services/CLISyncService.swift` | Darwin notification listener, bridges CLI writes to SwiftUI refresh |
