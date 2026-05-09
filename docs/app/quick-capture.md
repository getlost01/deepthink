# Global Quick Capture

System-wide floating panel for instant note, knowledge, or task capture without leaving your current app.

## How to use

Press **Option+Space** (`⌥Space`) from anywhere on your Mac. A floating panel appears:

1. Pick type: **Note**, **Knowledge**, or **Task**
2. Enter title and content
3. For Notes/Tasks: optionally select a project
4. For Knowledge: select a bucket and add tags
5. Press **Cmd+Enter** to save (or **Escape** to dismiss)

You can also open Quick Capture from the menu bar (**File → Quick Capture**), from the command palette (**⌘K** → “Quick Capture”), or via **DeepThink** menu shortcuts where shown as **⌥Space**.

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
| `Option+Space` | Toggle Quick Capture when DeepThink has registered the global hotkey |
| `Cmd+Enter` | Save and dismiss |
| `Escape` | Dismiss without saving |

## Accessibility permission

Showing the panel **from another app** uses a registered **global hotkey**. macOS may require **Accessibility** access for DeepThink:

1. First trigger from outside DeepThink → macOS may prompt for permission
2. **System Settings → Privacy & Security → Accessibility**
3. Enable **DeepThink**

Panel access from inside the app, the menu bar, or the command palette does not rely on this global registration.

If permission is denied, Quick Capture is still available via:

- Menu: **File → Quick Capture**
- Command palette: **⌘K** → “Quick Capture”

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

### Hotkey registration

The global shortcut **`Option+Space`** is registered with Carbon `RegisterEventHotKey` in **`Services/GlobalHotKey.swift`** (keyCode `49`, modifier `optionKey`). `DeepThinkApp` calls **`GlobalHotKey.shared.register`** on launch.

Menu and command palette labels use **`⌥Space`** for the same action.

### Cursor behavior

- I-beam cursor on text fields (title, content, tags)
- Pointer cursor on buttons and menus

## Key files

| File | Role |
|------|------|
| `Views/QuickCapture/QuickCapturePanel.swift` | `NSPanel` wrapper, singleton, toggle logic |
| `Views/QuickCapture/QuickCaptureView.swift` | SwiftUI content, save logic, project/bucket pickers |
| `Services/GlobalHotKey.swift` | Global `⌥Space` registration |
| `DeepThinkApp.swift` | Register hotkey on launch; menu → Quick Capture |
