# Reminders

Todo-style reminders with optional scheduled dates and timed notifications.

## Model

| Field | Type | Description |
|-------|------|-------------|
| `title` | String | Reminder text |
| `notes` | String | Extended description |
| `reminderDate` | Date? | Optional scheduled date/time |
| `isCompleted` | Bool | Completion status |
| `completedAt` | Date? | When marked done |
| `notificationScheduled` | Bool | Whether system notification is set |
| `project` | Project? | Optional project link |

## States

| State | Condition |
|-------|-----------|
| **Pending** | Has date, date > now, not completed |
| **Overdue** | Has date, date < now, not completed |
| **Completed** | `isCompleted = true` |
| **No date** | No reminder date set (simple todo) |

## Features

- Create reminders with or without scheduled dates
- Overdue detection and highlighting
- Native macOS notifications at scheduled date/time (banner + sound)
- "Acknowledge" action on notification marks reminder as completed and cancels any remaining pending notification requests for that reminder
- Clicking notification opens the app and navigates to that reminder
- Optional project assignment
- Sort by date, completion status
- Filter pills (All, Today, This Week, No Date) with trailing fade on scroll
- **Inline date/time pickers** - date and time chips use native compact `DatePicker` that expands in-place on click; `×` button on the date chip clears the scheduled date

## Navigation

- `Cmd+5` - go to Reminders section
- `Shift+Cmd+R` - create new reminder
- Also accessible via Command Palette (`Cmd+K` → "New Reminder")
- MCP tool: `workspace_reminder` (with `action: create | list | …`)

## CLI & MCP

Reminders are fully accessible via the single `workspace_reminder` MCP tool, which takes an `action`:

| `action` | Description |
|----------|-------------|
| `list` | List all reminders, optionally filter by `completed` |
| `get` | Get by ID or fuzzy title match (`ref`) |
| `create` | Create with `title` + optional `notes` / ISO `reminderDate` |
| `update` | Update `title`, `notes`, `reminderDate` (`'none'` clears), `completed` |
| `delete` | Delete by ID (`ref`) |

MCP resource: `deepthink://reminders`

> **Note:** Reminders created via CLI/MCP do not schedule macOS notifications. Notifications are only scheduled when setting a date through the app UI.

## Key Files

| File | Role |
|------|------|
| `Models/Reminder.swift` | SwiftData model |
| `Views/Reminders/` | List, detail, and row views |
| `DeepThinkApp.swift` | Notification delegate, categories, and action handling |
