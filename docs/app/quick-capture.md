# Quick Capture

Fast in-app panel for instant note, knowledge, or task capture.

## How to use

Open Quick Capture from inside DeepThink. A floating panel appears:

1. Pick type: **Note**, **Knowledge**, or **Task**
2. Enter title and content
3. For Notes/Tasks: optionally select a project
4. For Knowledge: select a bucket and add tags
5. Press **Cmd+Enter** to save (or **Escape** to dismiss)

Open paths:

- Menu bar: **File → Quick Capture**
- Command palette / Quick Search: **⌘K** (or app-only **⌥Space**) → “Quick Capture”

The panel shows a brief “Saved!” animation and auto-dismisses.

## Capture types

### Note

- Creates a new note in SwiftData
- Optional project assignment via dropdown
- Appears in Workspace → Notes

### Knowledge

- Creates a markdown entry in the knowledge base
- Select destination bucket (defaults to “General”)
- Add comma-separated tags
- Immediately indexed for BM25 + semantic search
- AI can reference it in the next conversation

### Task

- Creates a new task in SwiftData
- Optional project assignment via dropdown
- Defaults to “todo” status
- Appears in Workspace → Tasks

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘K` / `⌥Space` | Open Quick Search, then run “Quick Capture” |
| `Cmd+Enter` | Save and dismiss |
| `Escape` | Dismiss without saving |

## Global shortcut behavior

Quick Capture no longer uses a global hotkey.

Global shortcut support is currently for app Quick Search behavior only. For capture, use in-app entry points (menu or Quick Search command).

## Technical details

### Panel implementation

Uses `NSPanel` (not `NSWindow`) with these properties:

- `.nonactivatingPanel` — does not steal focus from the current app
- `.hudWindow` — no close/minimize/maximize chrome
- `.fullSizeContentView` — custom chrome
- `.floating` level — stays above other windows
- `becomesKeyOnlyIfNeeded = false` — accepts keyboard input immediately
- `canJoinAllSpaces` — visible on all Spaces
- `.ultraThickMaterial` background — frosted glass appearance

### Shortcut integration

Quick Capture is exposed as an in-app command and can be launched from Quick Search.

### Cursor behavior

- I-beam cursor on text fields (title, content, tags)
- Pointer cursor on buttons and menus

## Key files

| File | Role |
|------|------|
| `Views/QuickCapture/QuickCapturePanel.swift` | `NSPanel` wrapper, singleton, toggle logic |
| `Views/QuickCapture/QuickCaptureView.swift` | SwiftUI content, save logic, project/bucket pickers |
| `DeepThinkApp.swift` | Menu + command registration for Quick Capture |
