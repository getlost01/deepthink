# MCP Integration

Model Context Protocol (MCP) integration lets AI access external tools — databases, APIs, file systems, and more — through a standardized protocol.

## How It Works

```
User sends chat message
    ↓
MCPService detects tool need (workspace request keywords)
    ↓
Generates MCP config JSON from enabled servers
    ↓
Spawns Claude CLI with --mcp-config <path>
    ↓
Claude uses tools → returns response
```

## Built-in MCP Server

DeepThink ships its own MCP server (`deepthink-mcp`) providing 50 tools for workspace management:

| Category | Count | Examples |
|----------|-------|---------|
| Smart Context | 4 | `smart_query`, `knowledge_context`, `workspace_context`, `deepthink_overview` |
| Workspace | 21 | Task/note/project/reminder CRUD |
| Knowledge Base | 8 | Save, load, search project knowledge |
| Memory | 5 | Short/long-term persistent memory |
| Agents | 4 | Agent management |
| Rules | 4 | Rule management |
| Skills | 4 | Skill management |

### Resources

Read-only JSON access:

| URI | Description |
|-----|-------------|
| `deepthink://tasks` | All tasks |
| `deepthink://notes` | All notes |
| `deepthink://projects` | All projects |
| `deepthink://reminders` | All reminders |
| `deepthink://overview` | Compact overview (~200 tokens) |
| `deepthink://knowledge/stats` | Knowledge base stats |

## Server Discovery

MCP servers are discovered from multiple sources:

1. **DeepThink Workspace** — auto-installed, always available
2. **Claude config files** — reads from `.claude.json`, `claude_desktop_config.json`
3. **npm registry** — `MCPCatalogService` searches for `mcp-server`, `@modelcontextprotocol` packages
4. **Preset catalog** — built-in list of popular servers (GitHub, Postgres, Filesystem, etc.)

## Server Configuration

### In DeepThink App

Settings → Connections → MCP Servers:
- Browse available servers
- Enable/disable per server
- Core servers (DeepThink Workspace) can't be disabled

### For External Clients

Add to your MCP client's config:

**Claude CLI** (`~/.claude.json`):
```json
{ "mcpServers": { "deepthink": { "command": "deepthink-mcp", "args": [] } } }
```

**Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`):
```json
{ "mcpServers": { "deepthink": { "command": "/Users/YOU/.local/bin/deepthink-mcp", "args": [] } } }
```

**Cursor / VS Code** (`.cursor/mcp.json`):
```json
{ "mcpServers": { "deepthink": { "command": "deepthink-mcp", "args": [] } } }
```

## MCP Catalog

The app includes an npm-based catalog browser:

- Searches npm for MCP server packages
- Caches results (refreshes after 1 hour, lazy refresh after 24 hours)
- Auto-categorizes: Communication, Dev, Data, Files, Search, Web, Knowledge, Project Management
- One-click install guidance

## Workspace Detection

When the user's message contains workspace keywords (`create`, `task`, `note`, `project`, `list`, etc.), DeepThink automatically:

1. Ensures the DeepThink Workspace MCP server is in the active server list
2. Switches to MCP query mode
3. Claude uses workspace tools to fulfill the request

## Key Files

| File | Role |
|------|------|
| `Services/MCPService.swift` | Config generation, query dispatch, server discovery |
| `Services/MCPCatalogService.swift` | npm registry search, caching, categorization |
| `Models/MCPServer.swift` | SwiftData model for server config |
| `Views/Settings/IntegrationsView.swift` | Server browser, enable/disable UI |
| `cli/src/mcp-server.ts` | DeepThink MCP server implementation (50 tools) |
