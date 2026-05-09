# Command Palette

Quick launcher for all app actions via `Cmd+K`. Fuzzy search across commands, notes, tasks, projects, and knowledge.

## Usage

1. Press `Cmd+K` anywhere in the app
2. Type to filter
3. Arrow keys to navigate
4. Enter to execute
5. Escape to dismiss

## Command categories

**Navigation shortcuts:** the menu bar (**DeepThink → Go to Recent / Workspace / …**) defines the authoritative **⌘0–⌘7** sequence. Prefer that or [Keyboard shortcuts](../shortcuts.md); the palette may show overlapping labels for subset of these.

### Create (5 commands)

| Command | Shortcut |
|---------|----------|
| Quick Capture | — (launch from Quick Search) |
| New Note | `Cmd+N` |
| New Task | `Cmd+T` |
| New Project | `Shift+Cmd+N` |
| New Reminder | `Shift+Cmd+R` |

### Navigate (sidebar + tabs)

Commands below appear in the palette; **`Cmd+0` … `Cmd+7`** match the **Go to** menu items in `DeepThinkApp`.

| Command | Menu shortcut |
|---------|----------------|
| Recent | `Cmd+0` |
| Workspace | `Cmd+1` |
| Knowledge | `Cmd+2` |
| Context Graph | `Cmd+3` |
| AI Assistant | `Cmd+4` |
| Reminders | `Cmd+5` |
| Integration | `Cmd+6` |
| Terminal | `Cmd+7` |
| Projects (workspace tab) | `Shift+Cmd+1` |
| All Notes (workspace tab) | `Shift+Cmd+2` |
| All Tasks (workspace tab) | `Shift+Cmd+3` |
| Reload Knowledge | — |
| Capture to Knowledge | — |
| Assistants / Skills / Rules | — (navigate within Integration to the right tab) |
| Settings | `Cmd+,` |

### Skills (dynamic)

All installed skills appear as commands:
- "Run: Summarize"
- "Run: Extract Action Items"
- etc.

Executing navigates to AI Assistant and triggers the skill.

## Fuzzy Matching

Search algorithm:
1. Exact substring match (prioritized)
2. Character-by-character fuzzy match (fallback)
3. Results grouped by type: Commands, Notes, Tasks, Projects, Knowledge
4. Max 5 items per type

## Workspace Search

The palette also searches workspace items in real-time:
- Notes by title
- Tasks by title
- Projects by name
- Knowledge entries by title

Clicking navigates to the item.

## How Commands Are Registered

In `DeepThinkApp.registerCommands()`:
1. Skill commands generated dynamically from `SkillFileService.shared.skills`
2. Static navigation and create commands added
3. All registered via `commandPaletteState.registerCommands()`

## Key Files

| File | Role |
|------|------|
| `State/CommandPaletteState.swift` | Command model, fuzzy search, keyboard navigation |
| `Views/CommandPalette/` | Palette UI |
| `DeepThinkApp.swift` | Command registration |
