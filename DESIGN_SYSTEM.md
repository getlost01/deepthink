# DeepThink Design System v2

Production-ready, minimal design system. Single accent color, monochrome UI, consistent spacing.

All tokens and components live in `DeepThink/Views/Shared/DesignSystem.swift` under the `DS` namespace. Theme palettes and switching live in `DeepThink/Services/DSThemeManager.swift`.

---

## Theming

DeepThink ships **Light** and **Dark** palettes (`DSThemePalette`). Users pick **System**, **Light**, or **Dark** in Settings → General; `DSThemeManager` resolves the active palette and pushes it to SwiftUI, AppKit, and WKWebView surfaces (markdown editor, chat markdown, terminal).

### Rules for contributors

1. **Token-only colors** — use `DS.Colors.*`. Never `Color.primary`, `Color.white`, system materials, or raw `Color(...)`.
2. **Theme root** — wrap top-level windows in `DSThemeRoot { }` so palette changes re-render.
3. **Environment** — optional `@Environment(\.dsPalette)` or `@Bindable var theme = DSThemeManager.shared` when you need the bottom sheets tied to appearance.
4. **Web views** — inject theme via `DSThemeManager.shared.editorThemeUserScript()` / `chatThemeUserScript(isLight:)`; do not hard-code CSS colors in HTML.
5. **macOS 14+** — palettes use explicit sRGB values so light/dark look consistent across OS versions.

User-facing theme docs: [docs/app/appearance.md](docs/app/appearance.md).

---

## Principles

1. **Monochrome + one accent** — UI is grayscale. Blue accent for interactive/selected states only.
2. **Consistent density** — Same spacing, widths, and heights everywhere. No one-off values.
3. **Minimal color** — Status colors (green/orange/red) only where semantically required. No decorative color.
4. **Clean icons** — Lightweight SF Symbols. No filled variants unless indicating active state.
5. **No purple/violet** — Anywhere. Period.

---

## Tokens

### Spacing

| Token | Value | Use |
|-------|-------|-----|
| `DS.Spacing.xs` | 4pt | Inline gaps, between icon and small text |
| `DS.Spacing.sm` | 8pt | Row vertical padding, chip gaps, tight grouping |
| `DS.Spacing.md` | 12pt | Default internal padding, icon-to-label gap |
| `DS.Spacing.lg` | 16pt | Card padding, section internal spacing |
| `DS.Spacing.xl` | 24pt | Page margins, between major sections |
| `DS.Spacing.xxl` | 32pt | Large section gaps, empty state spacing |

### Corner Radius

| Token | Value | Use |
|-------|-------|-----|
| `DS.Radius.sm` | 6pt | Buttons, pills, chips, small interactive elements |
| `DS.Radius.md` | 8pt | Inputs, cards, rows, containers |
| `DS.Radius.lg` | 12pt | Large cards, panels, modals |

### Icon Sizes

| Token | Value | Use |
|-------|-------|-----|
| `DS.IconSize.sm` | 12pt | Inline icons, row leading icons, status indicators |
| `DS.IconSize.md` | 14pt | Toolbar buttons, search field icon, section icons |
| `DS.IconSize.lg` | 16pt | Sidebar icons, stat card icons, primary actions |
| `DS.IconSize.xl` | 20pt | Empty state icons, hero actions |

### Typography

| Token | Size | Weight | Use |
|-------|------|--------|-----|
| `DS.Font.title` | 18pt | Semibold | Page titles, stat numbers |
| `DS.Font.heading` | 14pt | Semibold | Section headers, card titles, sidebar app name |
| `DS.Font.body` | 13pt | Regular | Primary body text, list items, descriptions |
| `DS.Font.caption` | 11pt | Regular | Secondary text, timestamps, metadata |
| `DS.Font.small` | 10pt | Medium | Badges, pills, tertiary labels |
| `DS.Font.mono` | 13pt | Monospaced | Code, terminal, file paths |
| `DS.Font.monoSmall` | 11pt | Monospaced | Small code, terminal details |

### Colors

Colors are **theme-aware** — each token reads from `DSThemeManager.shared.palette` (light or dark). Surface roles follow a neutral ramp: `page` → `surfaceElevated` → `modal` / `card`.

| Token | Use |
|-------|-----|
| **Text** | |
| `DS.Colors.textPrimary` | Titles, body, selected items |
| `DS.Colors.textSecondary` | Subtitles, descriptions, inactive UI |
| `DS.Colors.textTertiary` | Timestamps, placeholders, disabled |
| **Surfaces** | |
| `DS.Colors.page` | Main content background |
| `DS.Colors.surface` / `surfaceElevated` | Panels, sidebar, elevated chrome |
| `DS.Colors.modal` / `card` | Dialogs and card surfaces |
| `DS.Colors.fill` / `fillSecondary` | Subtle backgrounds, inputs, hover |
| **Borders** | |
| `DS.Colors.border` / `borderHover` / `borderFocused` | Dividers and focus rings |
| **Interactive** | |
| `DS.Colors.accent` / `accentFill` / `accentGradient` | Primary actions, selected states |
| `DS.Colors.onAccent` | Text/icons on accent backgrounds |
| **Semantic (use sparingly)** | |
| `DS.Colors.success` / `warning` / `danger` | Status and destructive actions |
| `DS.Colors.badgeFill(_:)` / `badgeBorder(_:)` | Chip/badge tints — not raw `.opacity` on semantic colors |

### Layout

| Token | Value | Use |
|-------|-------|-----|
| `DS.Layout.sidebarWidth` | 200pt | Sidebar expanded width |
| `DS.Layout.panelWidth` | 300pt | All list panels (notes, tasks, projects, sources) |
| `DS.Layout.toolbarHeight` | 44pt | All toolbars and tab bars |
| `DS.Layout.rowHeight` | 36pt | Standard row minimum height |

### Animation

| Token | Value | Use |
|-------|-------|-----|
| `DS.Animation.quick` | 0.15s easeInOut | Hover, small transitions |
| `DS.Animation.standard` | 0.2s easeInOut | Panel toggle, tab switch |

---

## Components

### DSToolbarBar
Top toolbar container. 44pt height, `.bar` material.
```swift
DSToolbarBar {
    DSTabButton(title: "Chat", isSelected: true, action: {})
    Spacer()
    DSSearchField(text: $query)
}
```

### DSTabButton
Text-only tab toggle. Selected = accent underline. No icons in tabs.
```swift
DSTabButton(title: "Projects", isSelected: appState.workspaceTab == .projects) {
    appState.workspaceTab = .projects
}
```

### DSPageHeader
Page header (44pt) with title + optional trailing.
```swift
DSPageHeader(title: "Settings") {
    DSToolbarButton(icon: "plus", action: {})
}
```

### DSSectionHeader
Section label with optional count + "View All" link.
```swift
DSSectionHeader(title: "Recent Notes", count: 12) { appState.workspaceTab = .notes }
```

### DSCard
Container with subtle border, rounded corners. No shadow by default.
```swift
VStack { content }.dsCard(padding: DS.Spacing.lg)
```

### DSPill
Small text badge. Uses `textSecondary` color by default. Color only for semantic meaning.
```swift
DSPill(text: "Urgent", color: .red)
DSPill(text: "3 tasks")  // neutral
```

### DSSearchField
Search input with magnifying glass.
```swift
DSSearchField(text: $searchText, placeholder: "Search...")
```

### DSToolbarButton
Compact icon button (28x28) with hover effect.
```swift
DSToolbarButton(icon: "trash", action: { delete() })
```

### DSActionButton
Button with icon + text. Neutral by default.
```swift
DSActionButton(title: "New Note", icon: "plus", action: { createNote() })
```

### DSEmptyState
Centered empty state with icon, title, subtitle, optional action.
```swift
DSEmptyState(
    icon: "folder",
    title: "No Projects",
    subtitle: "Create your first project.",
    action: { createProject() },
    actionTitle: "Create Project"
)
```

### DSRow
Generic row with leading, title/subtitle, trailing.
```swift
DSRow(leading: { Image(systemName: "folder") }, title: "Project", subtitle: "3 tasks") {
    Text("Active")
}
```

### DSStatChip
Inline stat: icon + value. Monochrome.
```swift
DSStatChip(label: "Tasks", value: "12", icon: "checklist")
```

### DSCalendarPicker
Calendar date picker with quick options.
```swift
DSCalendarPicker(selectedDate: $dueDate, isPresented: $showCalendar)
```

### DSSectionDivider
Divider with optional centered label.
```swift
DSSectionDivider(label: "OR")
```

### Form Inputs
```swift
DSLabeledTextField(label: "Name", text: $name, placeholder: "Enter name")
DSLabeledTextEditor(label: "Description", text: $description, minHeight: 120)
DSLabeledPicker(label: "Status", selection: $status) {
    ForEach(TaskStatus.allCases) { Text($0.rawValue).tag($0) }
}
```

### RichMarkdownEditor
WKWebView-based Tiptap markdown editor.
```swift
RichMarkdownEditor(text: $note.content)
```

---

## View Modifiers

| Modifier | Effect |
|----------|--------|
| `.dsCard(padding:)` | Border + rounded rect background (no shadow) |
| `.dsPage()` | Full-size frame with window background |
| `.dsInteractive()` | Hover bg + press scale |
| `.dsInputField()` | Input styling: padding + fill + border |
| `.dsClickable()` | Hover-reactive border |
| `.dsListPanel()` | Fixed width panel (300pt) |
| `.pointerOnHover()` | Hand cursor on hover |

## Button Styles

| Style | Effect |
|-------|--------|
| `.buttonStyle(.plainPointer)` | Press opacity (0.8) + hand cursor |

---

## Icons

### Sidebar Navigation
| Icon | Section |
|------|---------|
| `tray` | Context |
| `square.grid.2x2` | Workspace |
| `sparkles` | AI |
| `terminal` | Terminal |
| `gear` | Settings |

### Workspace Tabs (text-only, no icons in tabs)
Overview, Projects, Notes, Tasks, Knowledge

### Task Status
| Icon | Status |
|------|--------|
| `circle.dashed` | Backlog |
| `circle` | To Do |
| `circle.lefthalf.filled` | In Progress |
| `checkmark.circle.fill` | Done |
| `xmark.circle` | Cancelled |

### Task Priority
| Icon | Priority |
|------|----------|
| `minus` | None |
| `arrow.down` | Low |
| `equal` | Medium |
| `arrow.up` | High |
| `exclamationmark.triangle` | Urgent |

### Common Actions
| Icon | Action |
|------|--------|
| `plus` | Create new (all types) |
| `trash` | Delete |
| `doc.on.doc` | Copy |
| `arrow.up.circle.fill` | Send |
| `sidebar.left` | Toggle sidebar |
| `magnifyingglass` | Search |
| `calendar` | Due date |

---

## Layout Patterns

### Sidebar + Content (App Root)
```text
+----------+------------------------------------+
| Sidebar  | ContentRouter                      |
| (200pt)  |                                    |
|          | Routes based on selectedSection    |
+----------+------------------------------------+
```

### Tab Bar + Content
```text
+-----------------------------------------------+
| DSToolbarBar [Tab] [Tab] [Tab]   Spacer  [...] |
+-----------------------------------------------+
| Content (switches by tab)                      |
+-----------------------------------------------+
```

### List + Detail (HSplitView)
```text
+------------------+-------------------------------+
| List Panel       | Detail Panel                  |
| (300pt fixed)    | (flex)                        |
+------------------+-------------------------------+
```

### Dashboard Grid
```text
+--------+--------+--------+--------+
| Stat   | Stat   | Stat   | Stat   |
+--------+--------+--------+--------+
| Recent Notes (50%) | Tasks (50%)  |
+--------------------+--------------+
| Quick Actions                     |
+-----------------------------------+
```

---

## Color Usage Rules

1. Sidebar icons: **always gray** (`textSecondary`). Selected = `textPrimary`.
2. Stat cards: **no colored icons**. All monochrome.
3. Action buttons: **neutral** by default. Color only for destructive (red).
4. Task status: keeps semantic color (green/orange/red/blue/gray).
5. Task priority: keeps semantic color.
6. Project color: user-customizable hex (unchanged).
7. Everything else: grayscale + accent blue.
