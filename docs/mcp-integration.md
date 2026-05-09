# MCP Integration

DeepThink ships a full MCP (Model Context Protocol) server — `deepthink-mcp` — giving any AI client access to your workspace, knowledge base, agents, skills, and rules through a standardized protocol.

## Quick Setup

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

> **Note:** `deepthink-mcp` must be on your `PATH` or use the full path `~/.local/bin/deepthink-mcp`. The binary is auto-installed by the DeepThink app on first launch.

---

## The deepthink-mcp Server

The server exposes your entire DeepThink workspace to any MCP-compatible AI client. It reads and writes the same data directory (`~/DeepThink/`) as the macOS app — changes made via MCP tools appear instantly in the app, and vice versa.

### How It Works

```text
AI client (Claude Code, Cursor, etc.)
    ↓  MCP request
deepthink-mcp (stdio server)
    ↓  reads/writes
~/DeepThink/data/deepthink.store   (tasks, notes, projects)
~/DeepThink/knowledge/             (knowledge base markdown)
~/DeepThink/.claude/               (agents, rules, skills)
```

No network calls. No auth. Purely local.

---

## Smart Context Tools

These are the highest-value tools — designed for AI agents that need to pull relevant context efficiently without reading everything.

### `smart_query`

The recommended starting point for any query about your workspace. Auto-detects whether you need a summary or full data, runs hybrid retrieval (BM25 + semantic), and returns a token-budgeted response.

```text
Input:  query (string), mode ("auto"|"summary"|"full"), maxTokens (number)
Output: ranked knowledge chunks + relevant workspace items, token-budgeted
```

**When to use:** "What's the context around X?", "What do I know about Y?", any open-ended question.

### `knowledge_context`

Retrieves knowledge base entries most relevant to a query using hybrid BM25 + semantic search. Supports scoping to specific knowledge buckets/tags and project boosting.

```text
Input:  query, maxTokens (default 4000), projectScope, knowledgeScope (tags), topK (default 10)
Output: ranked knowledge chunks with titles, sources, and relevance scores
```

**When to use:** "Find everything about auth", "What decisions were made for project X?".

### `workspace_context`

Retrieves workspace items (tasks, notes, reminders) most relevant to a query. Great for understanding what's in-progress or blocked.

```text
Input:  query, maxItems (default 5 per category)
Output: scored tasks, notes, reminders filtered by relevance to query
```

**When to use:** "What tasks are blocking the API migration?", "Show notes related to the release".

### `unified_search`

Single call to search across all data types simultaneously — knowledge, tasks, notes, reminders. Useful when you don't know where the information lives.

```text
Input:  query, maxItems (default 10), types (filter: "knowledge"|"task"|"note"|"reminder")
Output: ranked results with type labels
```

### `deepthink_overview`

Compact system overview in ~200 tokens. Counts, recent items, active projects. Good as a first call to orient an agent.

```text
Input:  none
Output: project count, task counts by status, note count, knowledge stats, recent activity
```

---

## Full tool reference

The server aggregates tool definitions in `cli/src/mcp-server.ts` (`ALL_TOOLS`): **50 tools** total as of the current codebase — **5** smart/context tools + **23** workspace tools + **10** knowledge tools + **12** agents/rules/skills configuration tools. If you add tools, bump this narrative or regenerate counts from source.

### Workspace — Tasks (5 tools)

| Tool | Description |
|------|-------------|
| `workspace_list_tasks` | List tasks with filters (status, priority, project, due date). Paginated (50/page). |
| `workspace_get_task` | Get a single task by ID or fuzzy name match. |
| `workspace_create_task` | Create a task with title, status, priority, due date, project assignment. |
| `workspace_update_task` | Update any task fields. Only provided fields are changed. |
| `workspace_delete_task` | Delete a task permanently. |

### Workspace — Notes (5 tools)

| Tool | Description |
|------|-------------|
| `workspace_list_notes` | List notes with optional project/pinned filters. Paginated. |
| `workspace_get_note` | Get a single note by ID or name. Returns full markdown content. |
| `workspace_create_note` | Create a note with title, content (markdown), project, tags, pinned. |
| `workspace_update_note` | Update note fields. Only provided fields are changed. |
| `workspace_delete_note` | Delete a note permanently. |

### Workspace — Projects (5 tools)

| Tool | Description |
|------|-------------|
| `workspace_list_projects` | List all projects with task and note counts. Paginated. |
| `workspace_get_project` | Get a single project by ID or name with full stats. |
| `workspace_create_project` | Create a project with name, summary, color. |
| `workspace_update_project` | Update project fields including archive status. |
| `workspace_delete_project` | Delete a project. Tasks and notes become unassigned. |

### Workspace — Reminders (5 tools)

| Tool | Description |
|------|-------------|
| `workspace_list_reminders` | List reminders, optionally filter by completion status. |
| `workspace_get_reminder` | Get a reminder by ID or fuzzy title match. |
| `workspace_create_reminder` | Create a reminder with title, notes, optional due date/time. |
| `workspace_update_reminder` | Update reminder fields. |
| `workspace_delete_reminder` | Delete a reminder permanently. |

### Workspace — Deep Links (2 tools)

| Tool | Description |
|------|-------------|
| `workspace_resolve_deeplink` | Resolve a single `deepthink://` URL to its full item content. Supports task, note, project, reminder. Returns archived warning if item is archived. |
| `workspace_resolve_deeplinks` | Resolve multiple `deepthink://` URLs in one call. Returns a map of URL → item (or error). More efficient than looping `workspace_resolve_deeplink`. |

**URL format:** `deepthink://type/UUID-WITH-DASHES` (task, note, project, reminder) or `deepthink://knowledge?id=<id>` (knowledge entries).

### Workspace — Summary (1 tool)

| Tool | Description |
|------|-------------|
| `workspace_summary` | Full workspace snapshot: project/task/note counts + recent items. |

### Knowledge Base (10 tools)

| Tool | Description |
|------|-------------|
| `knowledge_stats` | Overview: project count, integration channels, archive count. |
| `knowledge_list_projects` | List all knowledge projects. |
| `knowledge_load_project` | Load all knowledge for a project: context, decisions, and artifacts. |
| `knowledge_save_project` | Save to a project. Types: `context`, `decision`, `artifact`. |
| `knowledge_search` | Keyword search across all integration data and captured entries. |
| `knowledge_list_integrations` | List all integration sources and their channels. |
| `knowledge_load_integration` | Load recent entries from an integration source/channel. |
| `knowledge_capture` | Capture data from an external source into the knowledge base. |
| `knowledge_compress` | Compress an integration channel's entries into a dense archive. |
| `knowledge_archive_project` | Archive a project's knowledge into a compressed summary file. |

### Agents (4 tools)

| Tool | Description |
|------|-------------|
| `agent_list` | List all AI agents with roles, icons, models, knowledge scopes. |
| `agent_get` | Get full agent details including system prompt. |
| `agent_create` | Create an agent with name, role, system prompt, knowledge scope. |
| `agent_delete` | Delete an agent by name. |

### Rules (4 tools)

| Tool | Description |
|------|-------------|
| `rule_list` | List all rules with triggers, categories, instructions. |
| `rule_get` | Get full rule details including instruction text. |
| `rule_create` | Create a rule with trigger, category, priority, instructions. |
| `rule_delete` | Delete a rule by name. |

### Skills (4 tools)

| Tool | Description |
|------|-------------|
| `skill_list` | List all slash-command skills with categories and triggers. |
| `skill_get` | Get full skill details including system prompt and template. |
| `skill_create` | Create a skill with name, category, system prompt, template variables. |
| `skill_delete` | Delete a skill by name. |

---

## Resources (Read-only)

Resources expose data as JSON without consuming a tool call. Access via `deepthink://` URIs:

| URI | Description |
|-----|-------------|
| `deepthink://tasks` | All active (non-archived) tasks |
| `deepthink://notes` | All active notes |
| `deepthink://projects` | All active projects |
| `deepthink://reminders` | All reminders |
| `deepthink://overview` | Compact workspace overview (~200 tokens) |
| `deepthink://knowledge/stats` | Knowledge base overview |
| `deepthink://knowledge/projects` | All knowledge projects |
| `deepthink://knowledge/integrations` | All integration sources and channels |

---

## Common Workflows

### Morning standup prep

```text
1. deepthink_overview          → see what's active
2. workspace_list_tasks        → filter status="In Progress"
3. knowledge_context           → query="blockers or decisions from last week"
```

### Research and save

```text
1. smart_query                 → query="everything about auth architecture"
2. knowledge_save_project      → save findings as decision/artifact
```

### Create tasks from a meeting

```text
1. workspace_list_projects     → find the right project
2. workspace_create_task       → one call per action item
3. workspace_create_note       → save meeting notes
```

### Build a custom agent

```text
1. agent_list                  → see existing agents
2. agent_create                → name, role, system prompt, knowledge_scope
3. rule_create                 → add a trigger:always rule for it
```

---

## How the App Uses MCP

Inside the DeepThink app, `MCPService` auto-detects when a chat message needs workspace tools (keywords: `create`, `task`, `note`, `list`, `project`, etc.) and switches to MCP mode:

```text
User message
    ↓
Keyword detection → workspace intent?
    YES: build MCP config JSON from enabled servers
         spawn Claude CLI with --mcp-config <path>
         Claude calls workspace tools → response
    NO:  direct Claude CLI call (no tools)
```

The DeepThink Workspace server is always active and cannot be disabled.

---

## Third-party Server Catalog

The app includes an npm-based catalog browser (Settings → Connections → MCP Servers):

- Searches npm for `mcp-server` / `@modelcontextprotocol` packages
- Auto-categorizes: Communication, Dev, Data, Files, Search, Web, Knowledge, Project Management
- Results cached 1 hour (lazy refresh after 24 hours)
- One-click install guidance

Built-in preset servers:

| Server | Category | Package |
|--------|----------|---------|
| Filesystem | Files | `@modelcontextprotocol/server-filesystem` |
| GitHub | Dev | `@modelcontextprotocol/server-github` |
| PostgreSQL | Data | `@modelcontextprotocol/server-postgres` |
| SQLite | Data | `@modelcontextprotocol/server-sqlite` |
| Web Search | Search | `@modelcontextprotocol/server-brave-search` |
| Fetch | Web | `@modelcontextprotocol/server-fetch` |
| Memory | Knowledge | `@modelcontextprotocol/server-memory` |
| Slack | Communication | `@modelcontextprotocol/server-slack` |
| Google Drive | Files | `@modelcontextprotocol/server-gdrive` |
| Linear | Project Management | `@linear/mcp-server` |
| Sentry | Dev | `@sentry/mcp-server` |
| Puppeteer | Web | `@modelcontextprotocol/server-puppeteer` |

---

## Key Files

| File | Role |
|------|------|
| `cli/src/mcp-server.ts` | Server entry point, tool + resource registration |
| `cli/src/tools/smart-mcp.ts` | Smart context tools (smart_query, knowledge_context, workspace_context, unified_search, deepthink_overview) |
| `cli/src/tools/workspace.ts` | Workspace CRUD tools (tasks, notes, projects, reminders) |
| `cli/src/tools/knowledge-mcp.ts` | Knowledge base tools |
| `cli/src/tools/config-mcp.ts` | Agent, rule, and skill tools |
| `Services/MCPService.swift` | App-side MCP config generation and query dispatch |
| `Services/MCPCatalogService.swift` | npm registry search, caching, categorization |
| `Models/MCPServer.swift` | SwiftData model for configured servers |
| `Views/Settings/IntegrationsView.swift` | Server browser and enable/disable UI |
