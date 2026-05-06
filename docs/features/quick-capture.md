# Global Quick Capture

System-wide floating panel for instant note, knowledge, or task capture without leaving your current app.

## How To Use

Press **Cmd+Shift+D** from anywhere on your Mac. A floating panel appears:

1. Pick type: **Note**, **Knowledge**, or **Task**
2. Enter title and content
3. For Notes/Tasks: optionally select a project
4. For Knowledge: select a bucket and add tags
5. Press **Cmd+Enter** to save (or **Escape** to dismiss)

The panel shows a brief "Saved!" animation and auto-dismisses.

## Capture Types

### Note
- Creates a new note in SwiftData
- Optional project assignment via dropdown
- Appears in Workspace → Notes

### Knowledge
- Creates a markdown entry in the knowledge base
- Select destination bucket (defaults to "General")
- Add comma-separated tags
- Immediately indexed for BM25 + semantic search
- AI can reference it in the next conversation

### Task
- Creates a new task in SwiftData
- Optional project assignment via dropdown
- Defaults to "todo" status
- Appears in Workspace → Tasks

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+D` | Toggle Quick Capture (works globally) |
| `Cmd+Enter` | Save and dismiss |
| `Escape` | Dismiss without saving |

## Accessibility Permission

The global hotkey (Cmd+Shift+D from other apps) requires macOS Accessibility permission:

1. First trigger from outside DeepThink → macOS prompts for permission
2. Go to **System Settings → Privacy & Security → Accessibility**
3. Enable DeepThink

The hotkey works inside the app without this permission. If permission is denied, Quick Capture is still accessible via:
- Menu bar: **File → Quick Capture**
- Command palette: **Cmd+K** → "Quick Capture"

## Technical Details

### Panel Implementation

Uses `NSPanel` (not `NSWindow`) with these properties:
- `.nonactivatingPanel` — doesn't steal focus from current app
- `.hudWindow` — no close/minimize/maximize buttons
- `.fullSizeContentView` — custom chrome
- `.floating` level — stays above other windows
- `becomesKeyOnlyIfNeeded = false` — accepts keyboard input immediately
- `canJoinAllSpaces` — visible on all desktops/spaces
- `.ultraThickMaterial` background — frosted glass appearance

### Hotkey Registration

Two monitors registered in `DeepThinkApp.swift`:
- `NSEvent.addGlobalMonitorForEvents` — captures Cmd+Shift+D when app is not focused
- `NSEvent.addLocalMonitorForEvents` — captures when app is focused

### Cursor Behavior

- I-beam cursor on text fields (title, content, tags)
- Pointing hand on buttons and menus

## Key Files

| File | Role |
|------|------|
| `Views/QuickCapture/QuickCapturePanel.swift` | NSPanel wrapper, singleton, toggle logic |
| `Views/QuickCapture/QuickCaptureView.swift` | SwiftUI content, save logic, project/bucket pickers |
| `DeepThinkApp.swift` | Global hotkey registration, menu item |
