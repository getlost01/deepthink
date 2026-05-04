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
- System notifications (when `notificationScheduled = true`)
- Optional project assignment
- Sort by date, completion status

## Navigation

- `Cmd+5` — go to Reminders section
- `Shift+Cmd+R` — create new reminder
- Also accessible via Command Palette (`Cmd+K` → "New Reminder")
- MCP tools: `workspace_create_reminder`, `workspace_list_reminders`, etc.

## Key Files

| File | Role |
|------|------|
| `Models/Reminder.swift` | SwiftData model |
| `Views/Reminders/` | List, detail, and row views |
