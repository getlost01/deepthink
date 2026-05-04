# Deep Search

Global search across workspace (notes, tasks, projects) and knowledge base, with optional AI-powered analysis.

## Two Search Modes

### 1. Workspace Search (Local)

Instant substring search across:

| Source | Fields Searched |
|--------|----------------|
| Notes | title, content |
| Tasks | title, detail |
| Projects | name, summary |
| Knowledge | title, content, tags (via `KnowledgeService.search()`) |

Results grouped by type with context snippets (100 chars before/after match).

### 2. AI Search (Claude-Powered)

Takes top 5 workspace search results as context, sends to Claude for analysis:

- System prompt: "You are a knowledge assistant analyzing a user's workspace"
- Returns markdown analysis in a sheet
- Copy-to-clipboard for results
- Useful for questions like "What did I work on this week?" or "Summarize my API-related notes"

## Search Suggestions

Pre-populated suggestions for common queries:
- "What did I work on this week?"
- "Summarize recent meeting notes"
- "What tasks are overdue?"

Clicking a suggestion triggers AI search mode.

## Result Navigation

Click any result to navigate directly:
- Note → opens note editor
- Task → opens task detail
- Project → opens project overview
- Knowledge → opens knowledge entry

## Key Files

| File | Role |
|------|------|
| `Views/DeepSearch/DeepSearchView.swift` | Search UI, dual-mode logic, AI analysis |
