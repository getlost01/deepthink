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
- **Inline date/time pickers** — date and time chips use native compact `DatePicker` that expands in-place on click; `×` button on the date chip clears the scheduled date

## Navigation

- `Cmd+5` — go to Reminders section
- `Shift+Cmd+R` — create new reminder
- Also accessible via Command Palette (`Cmd+K` → "New Reminder")
- MCP tools: `workspace_create_reminder`, `workspace_list_reminders`, etc.

## CLI & MCP

Reminders are fully accessible via CLI and MCP tools:

| Tool | Description |
|------|-------------|
| `workspace_list_reminders` | List all reminders, optionally filter by completion |
| `workspace_get_reminder` | Get by ID or fuzzy title match |
| `workspace_create_reminder` | Create with optional date/time |
| `workspace_update_reminder` | Update title, notes, date, completion |
| `workspace_delete_reminder` | Delete by ID |

MCP resource: `deepthink://reminders`

> **Note:** Reminders created via CLI/MCP do not schedule macOS notifications. Notifications are only scheduled when setting a date through the app UI.

## Key Files

| File | Role |
|------|------|
| `Models/Reminder.swift` | SwiftData model |
| `Views/Reminders/` | List, detail, and row views |
| `DeepThinkApp.swift` | Notification delegate, categories, and action handling |
