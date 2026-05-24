# App features

Documentation for the macOS app (`DeepThink.xcodeproj`). For a concise feature overview and screenshots context, see the [repository README](../../README.md).

DeepThink is **local-first**: data lives under `~/DeepThink/` (see [storage](../storage.md)). **MIT licensed** - contributions welcome via [CONTRIBUTING](../../CONTRIBUTING.md).

## Highlights

| Area | Capabilities |
|------|----------------|
| **Workspace** | Projects, markdown notes with backlinks & version history, kanban tasks, reminders |
| **Appearance** | System / Light / Dark theme across app, editor, chat, and terminal |
| **Knowledge** | Multi-source capture, buckets/tags, hybrid search (BM25 + semantic via shared [RAG pipeline](../rag-pipeline.md)) |
| **AI** | Agents + optional slash skills; **MCP defaults on** so every agent inherits **`mcp__deepthink__*`** tools; Claude Code gets the same via optional global **`/deepthink`** (`~/.claude/commands/deepthink.md`) |
| **Integrations** | Built-in terminal, bundled **CLI** and **MCP** server (`~/.local/bin/`), see [MCP Integration](../mcp-integration.md) |

## Workspace & productivity

| Doc | What it covers |
|-----|---------------|
| [Workspace](workspace.md) | Projects, notes, tasks - kanban, backlinks, version history |
| [Reminders](reminders.md) | Scheduled reminders with macOS notifications |
| [Command palette](command-palette.md) | `Cmd+K` launcher, fuzzy search; navigation shortcuts mirror the menu bar |
| [Terminal](terminal.md) | Built-in multi-tab terminal with AI output analysis |
| [Appearance & theme](appearance.md) | Light / dark / system theme, Settings, developer notes |

## Knowledge

| Doc | What it covers |
|-----|---------------|
| [Knowledge Base](knowledge-base.md) | Multi-source capture, buckets, tagging, dedup |
| [Data Collection](data-collection.md) | Automated URL scraping, RSS, folders, scripts |
| [Obsidian Import](obsidian-import.md) | Vault import with wiki-link conversion |
| [Quick Capture](quick-capture.md) | In-app floating panel via menu or Quick Search |

## AI

| Doc | What it covers |
|-----|---------------|
| [Agents, Skills & Rules](agents-skills-rules.md) | Custom AI personas, slash-command skills, auto-triggered rules |
| [Deep Search](deep-search.md) | Global workspace + knowledge search with AI analysis |

## Shared (app + CLI)

| Doc | What it covers |
|-----|---------------|
| [RAG Pipeline](../rag-pipeline.md) | Hybrid BM25 + semantic retrieval end-to-end |
| [Semantic Search](../semantic-search.md) | NLEmbedding vectors, shared vector store |
| [MCP Integration](../mcp-integration.md) | MCP server setup, tool categories, external clients |
| [Keyboard shortcuts](../shortcuts.md) | Full shortcuts reference |
