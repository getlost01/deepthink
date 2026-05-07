# CLI Documentation

The `deepthink` CLI and `deepthink-mcp` MCP server — built with Bun + TypeScript, compiled to standalone binaries. Both auto-installed to `~/.local/bin/` on app launch.

## Docs

| Doc | What it covers |
|-----|---------------|
| [Commands](commands.md) | All `deepthink` commands, agent system, context engine internals |

## Shared (App + CLI)

| Doc | What it covers |
|-----|---------------|
| [MCP Integration](../mcp-integration.md) | MCP server tools, resources, external client config |
| [RAG Pipeline](../rag-pipeline.md) | Hybrid retrieval — used by both CLI context engine and app |
| [Semantic Search](../semantic-search.md) | Shared `vectors.db`, embedding generation |
| [Storage](../storage.md) | Shared data directory layout |

## Quick Reference

```bash
# Context retrieval (for AI integrations)
deepthink context overview
deepthink context query "what's blocking v2?"

# AI queries
deepthink ask "summarize overdue tasks" --recall
deepthink run "analyze codebase and create migration plan"
deepthink react "find all stale tasks and draft summary"

# Workspace management
deepthink task list --status "In Progress"
deepthink note list --pinned
deepthink project list

# Knowledge base
deepthink knowledge search "auth flow"
deepthink knowledge save MyProject "decided to use JWT"

# Scheduled jobs
deepthink schedule run
deepthink schedule status
```

See [commands.md](commands.md) for the full reference.
