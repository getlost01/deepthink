# Agents, Skills & Rules

Three interconnected systems that customize AI behavior: **Agents** define who the AI is, **Skills** define what it can do, **Rules** define how it should behave.

## Agents

Custom AI personas with specialized knowledge and behavior.

### Structure

Stored as markdown files in `~/DeepThink/.claude/agents/`:

```markdown
---
name: Researcher
role: Deep-dives into knowledge, synthesizes findings
icon: magnifyingglass.circle
model: claude-sonnet-4-6
skills: [Summarize, Extract Action Items]
knowledge_scope: [web, manual]
built_in: true
---

You are a research agent. Your job is to...
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Display name |
| `role` | String | One-line description |
| `icon` | String | SF Symbol name |
| `model` | String? | Override Claude model (haiku/sonnet/opus) |
| `skills` | [String] | Skills this agent can suggest using |
| `knowledge_scope` | [String] | Buckets/tags to filter RAG retrieval |
| `built_in` | Bool | Whether it's a default template |

### How Agents Work

When a user chats with an agent, `AgentFileService.buildSystemPrompt()`:

1. Loads agent's system prompt from markdown body
2. Appends matching rules (`agent:AgentName` trigger)
3. Lists assigned skills in prompt so Claude knows they exist
4. Retrieves knowledge filtered by `knowledge_scope` + user query
5. Combines into full system prompt

When **MCP is enabled** for that chat, the UI appends one more block: **`mcp__deepthink__*` tools apply to every agent (and to the default assistant)**—you never have to duplicate that in YAML. That is the same routing surface area as **`/deepthink`** in Claude Code; the slash skill is an optional Claude Code UX layer, while the app wires tools into the system prompt whenever the DeepThink server is attached.

### Skills in Agents

When an agent has skills assigned, they appear in the system prompt:

```text
# Available Skills
You have the following skills available. When a user request matches a skill, suggest using it with /command-name:
- /summarize: Summarize content concisely
- /extract-action-items: Extract actionable tasks
```

The agent can then suggest `/summarize` when the user asks to condense something.

## Skills

Reusable AI actions invokable via `/slash-commands` in chat.

### `/deepthink` — Claude Code slash vs in-app (default for agents)

There are **two** ways you see the same “route everything through DeepThink” behavior:

**In the DeepThink macOS app (default behavior):** Leave **MCP** on with the bundled DeepThink server. **Every conversation—Researcher, Standup, or a custom agent—automatically inherits the full `mcp__deepthink__*` toolbelt.** You do *not* add `/deepthink` to each agent’s `skills:` list; MCP is wired per chat, so agents act as personas *on top of* shared workspace tools, not instead of them. Optional YAML skills (`Summarize`, `Extract Action Items`, …) are *additional* slash commands stored under `~/DeepThink/.claude/commands/`.

**In [Claude Code](https://claude.com/claude-code):** DeepThink installs a **global slash command** at **`~/.claude/commands/deepthink.md`** so you can type `/deepthink …` after the **`deepthink` MCP server** is registered (`claude mcp add …` — see [MCP Integration](../mcp-integration.md)). That file encodes how to decide which MCP tool to call when wording is vague (search vs capture vs tasks vs summaries, …).

Install or refresh `deepthink.md` from **Settings → Claude / Integrations** (the app shows status next to CLI and MCP). Slash skills you edit under **Agents & Skills** remain separate—they are workspace-local commands under `~/DeepThink/.claude/commands/`.

### Structure

Stored in `~/DeepThink/.claude/commands/`:

```markdown
---
name: Summarize
trigger: manual
icon: text.justify.leading
category: Writing
knowledge_scope: [research, web]
---

You are a concise summarizer. Output only bullet points.

---

Summarize the following in 2-3 bullet points:

{{input}}
```

The first `---` separator splits system prompt from prompt template.

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Display name and command name source |
| `trigger` | String | How skill is invoked (currently `manual`) |
| `icon` | String | SF Symbol name |
| `category` | String | Grouping for UI |
| `model` | String? | Override Claude model |
| `knowledge_scope` | [String] | Buckets/tags for scoped RAG during execution |
| `pinned` | Bool | Show in quick-access area |

### Template Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `{{input}}` | User text after `/command` | Primary input |
| `{{note_content}}` | Active note | Full note content |
| `{{note_title}}` | Active note | Note title |
| `{{note_tags}}` | Active note | Comma-separated tags |
| `{{selected_text}}` | Text selection | Currently selected text |
| `{{project_name}}` | Active project | Current project name |
| `{{current_date}}` | System | Today's date (formatted) |
| `{{current_time}}` | System | Current time (formatted) |

### Input Resolution

When `/command` is invoked without explicit input:

1. Check for text after command (`/summarize some text`) → use that
2. Check for selected text in active note → use that
3. Check for current note content → use that
4. Fall back to empty string

### Knowledge Scope

Skills can have their own `knowledge_scope` to narrow RAG retrieval:

- `/summarize` with scope `[research]` → only research entries used as context
- Without scope → generic RAG across entire knowledge base

## Rules

Always-on instructions that auto-inject into AI prompts based on context.

### Structure

Stored in `~/DeepThink/.claude/rules/`:

```markdown
---
name: Code Review
trigger: tag:code
icon: chevron.left.forwardslash.chevron.right
category: Development
priority: 10
---

When reviewing code:
1. Check for security vulnerabilities
2. Identify performance issues
3. Suggest simplifications
```

### Trigger System

Structured trigger matching (replaced fuzzy substring matching):

| Trigger Format | Matches When | Example |
|----------------|-------------|---------|
| `always` | Every query | Always active |
| `tag:meeting` | Note has "meeting" tag | `tag:code`, `tag:research` |
| `agent:Researcher` | Agent with that name selected | `agent:Code Reviewer` |
| `event:task.created` | Event key exists in context | `event:note.created` |
| `content:code` | Content type detected as code | `content:code` |
| `section:aiAssistant` | User in that app section | `section:workspace` |

### Priority

Rules with higher `priority` value appear first in the system prompt. Default is 0.

### Disabled State

Rules can be toggled on/off via pills in the chat toolbar. Disabled state persists across app restarts (stored in UserDefaults + rule frontmatter).

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Display name |
| `trigger` | String | When to activate (see trigger system) |
| `icon` | String | SF Symbol name |
| `category` | String | Grouping for UI |
| `priority` | Int | Sort order (higher = first, default 0) |
| `disabled` | Bool | Persisted disabled state |

## How They Connect

```text
User sends chat message
        ↓
┌─ Agent selected? ──────────────────────────┐
│  YES: Load agent system prompt             │
│       + Append matching rules (agent:X)    │
│       + List assigned skills               │
│       + Retrieve scoped knowledge          │
│  NO:  Use default assistant prompt         │
│       + Append active rules                │
└────────────────────────────────────────────┘
        ↓
Slash command? (/summarize)
  YES: Execute skill with rich context dict
       + Scoped RAG from skill's knowledge_scope
  NO:  Normal chat flow
        ↓
Response displayed
```

## Key Files

| File | Role |
|------|------|
| `Models/AgentFile.swift` | Agent data structure |
| `Models/SkillFile.swift` | Skill + Rule data structures |
| `Services/AgentFileService.swift` | Agent CRUD, system prompt building, skill listing |
| `Services/SkillFileService.swift` | Skill CRUD, template interpolation, execution |
| `Services/RuleFileService.swift` | Rule CRUD, structured trigger matching, priority sorting |
| `State/AppState.swift` | Active context, disabled rules persistence |
| `Views/Shared/AIChatView.swift` | Skill execution, context assembly |
| `Views/Shared/ActiveRulesBar.swift` | Toggleable rule pills in toolbar |
