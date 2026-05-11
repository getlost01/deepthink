# MCP Integration

DeepThink ships a full MCP (Model Context Protocol) server — `deepthink-mcp` — giving **any AI agent** access to your workspace, knowledge base, agents, skills, and rules through a standardized protocol.

> **Agent compatibility**
>
> `deepthink-mcp` is **not Claude-specific**. Any MCP-capable client works:
> Claude Code, Cursor, VS Code Copilot, Windsurf, Continue, or any host that speaks MCP over stdio.
>
> The **in-app AI** (chat, agents, skills, rules) is the only part that requires the **Claude CLI** — it spawns Claude as a local subprocess. Everything exposed through MCP and the CLI is model-agnostic: any agent can read and write your workspace, run hybrid retrieval, and query the knowledge base without Claude.

## Setup

### Claude Code (recommended)

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

---

## How It Works

```text
AI client (Claude Code, Cursor, etc.)
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

## readonly Flag

All read-only tools declare `readonly: true` in their tool definition. Mutating tools do not carry this field. MCP clients that support capability inspection can use this to distinguish safe reads from state-changing operations.

---

## Tool Reference (45 tools)

### Smart / Context Tools

These run hybrid BM25 + semantic retrieval and are the recommended starting point for any agent needing workspace context.

| Tool | readonly | Description |
|------|----------|-------------|
| `smart_query` | true | Auto-selects summary or full mode; runs hybrid retrieval; returns token-budgeted ranked results across knowledge + workspace |
| `knowledge_context` | true | Hybrid retrieval over knowledge FS only; supports `projectScope`, `knowledgeScope` (tags), `topK` (default 10), `maxTokens` (default 4000) |
| `workspace_context` | true | Hybrid retrieval over tasks, notes, reminders; returns scored items filtered by relevance |
| `unified_search` | true | Single call across all four types (knowledge, task, note, reminder); content field fully populated for workspace items; supports type filter |
| `deepthink_overview` | true | Compact system overview ~200 tokens: project count, task counts by status, note count, knowledge stats, recent activity |

### Workspace — Tasks

| Tool | readonly | Description |
|------|----------|-------------|
| `workspace_list_tasks` | true | List tasks with filters: status, priority, project, due date. Paginated (50/page). |
| `workspace_get_task` | true | Get a single task by ID or fuzzy name match. |
| `workspace_create_task` | — | Create a task: title, status, priority, due date, project. Logs to dt_audit_log. |
| `workspace_update_task` | — | Update task fields. Only provided fields changed. Logs to dt_audit_log. |
| `workspace_delete_task` | — | Soft-snapshot to dt_trash, then hard delete. Cascade-deletes vector chunks. |

### Workspace — Notes

| Tool | readonly | Description |
|------|----------|-------------|
| `workspace_list_notes` | true | List notes with optional project/pinned filters. Paginated. |
| `workspace_get_note` | true | Get a note by ID or name. Returns full markdown content. |
| `workspace_create_note` | — | Create a note: title, content (markdown), project, tags, pinned. Logs to dt_audit_log. |
| `workspace_update_note` | — | Update note fields. Only provided fields changed. Logs to dt_audit_log. |
| `workspace_delete_note` | — | Soft-snapshot to dt_trash, then hard delete. Cascade-deletes vector chunks. |

### Workspace — Projects

| Tool | readonly | Description |
|------|----------|-------------|
| `workspace_list_projects` | true | List all projects with task and note counts. Paginated. |
| `workspace_get_project` | true | Get a project by ID or name with full stats. |
| `workspace_create_project` | — | Create a project: name, summary, color. Logs to dt_audit_log. |
| `workspace_update_project` | — | Update project fields including archive status. Logs to dt_audit_log. |
| `workspace_delete_project` | — | Soft-snapshot to dt_trash, then hard delete. Tasks and notes become unassigned. Cascade-deletes all project vector chunks. |

### Workspace — Reminders

| Tool | readonly | Description |
|------|----------|-------------|
| `workspace_list_reminders` | true | List reminders, optionally filter by completion status. |
| `workspace_get_reminder` | true | Get a reminder by ID or fuzzy title match. |
| `workspace_create_reminder` | — | Create a reminder: title, notes, optional due date/time. Logs to dt_audit_log. |
| `workspace_update_reminder` | — | Update reminder fields. Logs to dt_audit_log. |
| `workspace_delete_reminder` | — | Soft-snapshot to dt_trash, then hard delete. Cascade-deletes vector chunks. |

### Workspace — Deep Links

| Tool | readonly | Description |
|------|----------|-------------|
| `workspace_resolve_deeplink` | true | Resolve a single `deepthink://type/UUID` URL to full item content. |
| `workspace_resolve_deeplinks` | true | Resolve multiple URLs in one call. Returns map of URL → item (or error). More efficient than looping single resolve. |

URL format: `deepthink://task/UUID`, `deepthink://note/UUID`, `deepthink://project/UUID`, `deepthink://reminder/UUID`, `deepthink://knowledge?id=<id>`.

### Workspace — Summary

| Tool | readonly | Description |
|------|----------|-------------|
| `workspace_summary` | true | Full workspace snapshot: project/task/note/reminder counts + recent items. |

### Knowledge Base

| Tool | readonly | Description |
|------|----------|-------------|
| `knowledge_stats` | true | Overview: project count, integration channels, archive count. |
| `knowledge_list_projects` | true | List all knowledge projects (slugs, titles). |
| `knowledge_load_project` | true | Load all knowledge for a project: context.md, decisions.md, and artifacts. |
| `knowledge_save_project` | — | Save to a project. Types: `context`, `decision`, `artifact`. |
| `knowledge_search` | true | Keyword search across integration data and captured entries. |
| `knowledge_list_integrations` | true | List all integration sources and their channels. |
| `knowledge_load_integration` | true | Load recent entries from an integration source/channel. |
| `knowledge_capture` | — | Capture data from an external source into the knowledge base. |
| `knowledge_compress` | — | Compress an integration channel's entries into a dense archive. |
| `knowledge_archive_project` | — | Archive a project's knowledge into a compressed summary file. |

### Config — Agents

| Tool | readonly | Description |
|------|----------|-------------|
| `agent_list` | true | List all agents: roles, icons, models, knowledge scopes. |
| `agent_get` | true | Get full agent details including system prompt. |
| `agent_create` | — | Create an agent: name, role, system prompt, knowledge scope. |
| `agent_delete` | — | Delete an agent by name. |

### Config — Rules

| Tool | readonly | Description |
|------|----------|-------------|
| `rule_list` | true | List all rules: triggers, categories, instructions. |
| `rule_get` | true | Get full rule details including instruction text. |
| `rule_create` | — | Create a rule: trigger, category, priority, instructions. |
| `rule_delete` | — | Delete a rule by name. |

### Config — Skills

| Tool | readonly | Description |
|------|----------|-------------|
| `skill_list` | true | List all slash-command skills: categories, triggers. |
| `skill_get` | true | Get full skill details including system prompt and template. |
| `skill_create` | — | Create a skill: name, category, system prompt, template variables. |
| `skill_delete` | — | Delete a skill by name. |

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
1. deepthink_overview          → orient: counts + recent activity
2. workspace_list_tasks        → filter status="In Progress"
3. knowledge_context           → query="blockers or decisions from last week"
```

### Research and capture

```text
1. smart_query                 → query="everything about auth architecture"
2. knowledge_save_project      → save findings as decision or artifact
```

### Create tasks from a meeting

```text
1. workspace_list_projects     → find the right project ID
2. workspace_create_task       → one call per action item
3. workspace_create_note       → save meeting notes with full markdown
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
