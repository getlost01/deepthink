# Command Palette

Quick launcher for all app actions via `Cmd+K`. Fuzzy search across commands, notes, tasks, projects, and knowledge.

## Usage

1. Press `Cmd+K` anywhere in the app
2. Type to filter
3. Arrow keys to navigate
4. Enter to execute
5. Escape to dismiss

## Command Categories

### Create (4 commands)

| Command | Shortcut |
|---------|----------|
| Quick Capture | `Shift+Cmd+D` |
| New Note | `Cmd+N` |
| New Task | `Cmd+T` |
| New Project | `Shift+Cmd+N` |
| New Reminder | `Shift+Cmd+R` |

### Navigate (12 commands)

| Command | Shortcut |
|---------|----------|
| Recent | `Cmd+0` |
| Workspace | `Cmd+1` |
| Knowledge | `Cmd+2` |
| AI Assistant | `Cmd+3` |
| Connections | `Cmd+4` |
| Reminders | `Cmd+5` |
| Terminal | `Cmd+6` |
| Projects | `Shift+Cmd+1` |
| All Notes | `Shift+Cmd+2` |
| All Tasks | `Shift+Cmd+3` |
| Assistants | — |
| Automations | — |
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
