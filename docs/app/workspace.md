# Workspace

Projects, notes, and tasks — the core productivity layer of DeepThink.

## Projects

Container for organizing related notes and tasks.

### Model

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Project name |
| `summary` | String | One-line description |
| `color` | String | Hex color code for visual identity |
| `isArchived` | Bool | Hidden from active views when true |
| `notes` | [Note] | Related notes |
| `tasks` | [TaskItem] | Related tasks |

### Computed Properties

- `openTaskCount` — tasks not done/cancelled
- `completedTaskCount` — tasks marked done
- `totalStoryPoints` / `completedStoryPoints` — sprint tracking

### Views

- **Project List** — grid of project cards with stats
- **Project Detail** — overview with notes list, task list, stats panel
- **Project Inspector** — edit name, summary, color, view archive

## Notes

Rich markdown notes with backlinks, versioning, and AI integration.

### Model

| Field | Type | Description |
|-------|------|-------------|
| `title` | String | Note title |
| `content` | String | Markdown content |
| `isPinned` | Bool | Pin to top of lists |
| `project` | Project? | Optional project assignment |
| `tags` | [Tag] | Categorization tags |
| `createdAt` / `modifiedAt` | Date | Timestamps |

### Features

**Rich Markdown Editor:**
- Tiptap-based WYSIWYG via WebView
- Toggle between edit and preview modes
- Syntax highlighting for code blocks

**Backlinks (Wiki-Links):**
- Type `[[Note Name]]` to link notes
- `BacklinkService` parses links and creates `NoteLink` edges
- Bidirectional — backlinks panel at the bottom of the editor shows all notes that link here
- Click a backlink to navigate directly to that note

**Deep Links:**
- Insert typed links to any task, note, reminder, project, or knowledge entry via the toolbar
- Links render as clickable chips in the editor; clicking navigates to the target item
- Link previews (title, status, snippet) appear on hover
- Dead link detection: broken links to deleted items trigger a warning banner with a "Fix" button that removes them from content
- `deepthink://type/UUID` URL scheme; also handled in project descriptions and task/reminder editors

**Version History:**
- Auto-saves version snapshots via `VersioningService`
- `NoteVersion` model: `noteID`, `versionNumber`, `title`, `content`, `createdAt`
- Browse and restore previous versions

**Editor placeholder hints:**
- When content is empty, shows chip-style hints for `/` (skills), `[[` (link notes), `**bold**`, and `_italic_` — disappears on first keypress

**AI Integration:**
- Note content available as `{{note_content}}` template variable in skills
- Notes auto-analyzed for knowledge extraction when >30 words
- Active note context injected into AI chat

### Views

- **Note List** — sortable, filterable, with search
- **Note Editor** — split or full-screen editing with toolbar
- **Note Inspector** — metadata, tags, backlinks, versions
- **Note Versions** — timeline of changes with restore

## Tasks

Full task management with kanban board, priorities, subtasks, and story points.

### Model

| Field | Type | Description |
|-------|------|-------------|
| `title` | String | Task title |
| `detail` | String | Extended description |
| `status` | TaskStatus | Backlog, Todo, InProgress, Done, Cancelled |
| `priority` | TaskPriority | None, Low, Medium, High, Urgent |
| `storyPoints` | Int | Effort estimate |
| `dueDate` | Date? | Optional deadline |
| `project` | Project? | Optional project assignment |
| `parent` | TaskItem? | Parent task (for subtasks) |
| `subtasks` | [TaskItem] | Child tasks |
| `completedAt` | Date? | When marked done |

### Status Flow

```text
Backlog → Todo → In Progress → Done
                              → Cancelled
```

Each status has an associated color and icon.

### Priority Levels

| Priority | Color | Sort Weight |
|----------|-------|-------------|
| Urgent | Red | 4 |
| High | Orange | 3 |
| Medium | Yellow | 2 |
| Low | Blue | 1 |
| None | Gray | 0 |

### Overdue Detection

`isOverdue` = due date < now AND status != done/cancelled. Overdue tasks highlighted in UI.

### Features

**Rich Markdown Editor:**
- Same Tiptap-based editor as notes, with deep link insertion and dead link detection
- Backlink panel shows notes that link to this task via `deepthink://task/UUID`

### Views

- **Task List** — tasks grouped by status; filter pills (All, Today, Upcoming, Overdue) with trailing fade; `+` button in each status header to add a task directly in that status; `⌘T` shortcut
- **Task Board** — kanban columns (Backlog, Todo, In Progress, Done)
- **Task Detail** — edit all fields, manage subtasks, rich markdown detail with deep links; backlinks panel expanded by default
- **Task Inspector** — sidebar with metadata and project assignment

## Navigation

```text
Workspace (Cmd+1)
├── Projects (Shift+Cmd+1)  — project cards grid
├── Notes (Shift+Cmd+2)     — all notes list
└── Tasks (Shift+Cmd+3)     — all tasks list / board view
```

Inside a project:
- Overview tab with stats
- Notes tab (filtered to project)
- Tasks tab (filtered to project)

## Key Files

| File | Role |
|------|------|
| `Models/Note.swift` | Note SwiftData model |
| `Models/TaskItem.swift` | Task SwiftData model |
| `Models/Project.swift` | Project SwiftData model |
| `Models/NoteLink.swift` | Backlink edges |
| `Models/NoteVersion.swift` | Version snapshots |
| `Services/BacklinkService.swift` | Wiki-link parsing + deep link backlink queries |
| `Services/DeadLinkScanner.swift` | Scans content for broken `deepthink://` links |
| `Services/VersioningService.swift` | Auto-versioning |
| `Views/Shared/SharedViews.swift` | `DeepLinkPickerSheet` — insert links to any item |
| `Views/Shared/DesignSystem.swift` | `RichMarkdownEditor` — deep link click/insert/preview/dead-link wiring |
| `Views/Workspace/WorkspaceView.swift` | Tab container |
| `Views/Projects/ProjectDetailView.swift` | Project detail with markdown-preview description |
| `Views/Tasks/TaskBoardView.swift` | Kanban board |
| `Views/Notes/NoteEditorView.swift` | Markdown editor with backlinks panel and dead link detection |
