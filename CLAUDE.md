# DeepThink Development Guide

## Tech Stack
- **Language:** Swift 5 / SwiftUI
- **Platform:** macOS (AppKit + SwiftUI)
- **Data:** SwiftData for persistence
- **Terminal:** SwiftTerm for embedded terminal views

## Design System (`DS`) — STRICT ENFORCEMENT
All UI must use the design system defined in `DeepThink/Views/Shared/DesignSystem.swift`.
**No raw values allowed.** Every color, font size, spacing value, corner radius, and opacity MUST come from a DS token. If a needed token doesn't exist, add it to DesignSystem.swift first — never inline a raw literal.

- **Colors:** `DS.Colors.*` — theme-aware tokens from `DSThemeManager` (light/dark/system). Never use `Color.white`, `Color.black`, `Color.primary`, system materials, or raw `Color(...)`. Use `DS.Colors.onAccent` on accent backgrounds, `DS.Colors.danger` for errors, shadow tokens for shadows. User picks appearance in Settings → General.
- **Theme root:** Wrap top-level windows in `DSThemeRoot { }` so palette changes re-render. Markdown editor, chat markdown, and terminal sync via `DSThemeManager`.
- **Surface roles:** Tight neutral ramp — `page` (base) → `surfaceElevated` (sidebar + global header, ~1 step lighter) → `modal`/`card` (dialogs/cards, slightly more lift). Content column uses `page` everywhere (`.dsPage()`, `.dsListPanel()`, `DSToolbarBar`). Chrome: `SidebarView`, `GlobalHeader`. Overlays: `.dsModalChrome()`.
- **Chips/badges:** Use `DS.Colors.badgeFill(_:)` and `DS.Colors.badgeBorder(_:)` — never ad-hoc `.opacity(0.1)` on semantic colors.
- **Typography:** `DS.Font.*` (hero, display, titleLarge, titleSmall, title, heading, body, bodySmall, caption, small, micro, badge, mono, monoSmall) — no `.font(.system(size: <number>))` calls. For icons with custom weight, use `DS.IconSize.*` for the size: `.font(.system(size: DS.IconSize.xs, weight: .semibold))`.
- **Spacing:** `DS.Spacing.*` (xxs=2, xs=4, xs2=6, sm=8, sm2=10, md=12, lg=16, xl=24, xxl=32) — consistent padding/gaps
- **Radius:** `DS.Radius.*` (sm=6, md=8, lg=12, xl=14, pill=20) — rounded corners
- **Icons:** `DS.IconSize.*` (micro=7, nano=8, xs=9, sm2=10, sm=12, md=14, lg=16, xl=20, xxl=24, xxxl=28, hero=40) — icon sizing
- **Opacity:** `DS.Opacity.*` — hover/pressed states
- **Animation:** `DS.Animation.standard` / `.quick` — transitions
- **Page style:** `.dsPage()` modifier on ScrollView roots

## Button Styles & Cursor
Every clickable element MUST have a pointer cursor. Use one of:
- `.buttonStyle(.plainPointer)` — plain buttons, icon buttons, cards
- `.buttonStyle(.dsPrimary)` — primary action buttons
- `.buttonStyle(.dsSecondary)` — secondary action buttons

Never use bare `.buttonStyle(.plain)` or `.borderless` — they lack the pointer cursor.

## Component Patterns
- Section headers: `DSSectionHeader(title:)`
- Stat cards: `UsageStatCard(title:value:icon:color:)`
- Dismissible hint banners: `DSSectionBanner(icon:title:subtitle:color:onDismiss:)` — pass `onDismiss` to show an `×` button; persist dismissed state with `@AppStorage`
- Reusable components live in `DeepThink/Views/Shared/`
- Use `DS.Colors.fill` / `DS.Colors.fillSecondary` for card backgrounds
- Use `DS.Colors.border` / `DS.Colors.borderHover` for strokes

### Scroll fade mask
Horizontal filter pill rows should fade out at the trailing edge so overflow is implied rather than cut off:
```swift
ScrollView(.horizontal, showsIndicators: false) { ... }
    .mask(
        HStack(spacing: 0) {
            Rectangle().frame(maxWidth: .infinity)
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: DS.Spacing.xl)
        }
    )
```

### Resizable sidebars
Use `DSSplitHandle` + drag gesture instead of a fixed frame when a panel should be user-resizable:
```swift
@State private var panelWidth: CGFloat = 240

DSSplitHandle(axis: .vertical)
    .gesture(DragGesture(minimumDistance: 1).onChanged { value in
        panelWidth = min(max(panelWidth - value.translation.width, minW), maxW)
    })
SomePanel().frame(width: panelWidth)
```

### Infinite scroll
Replace "Load More" buttons with a `ProgressView` that increments the count on `.onAppear`:
```swift
if hasMore {
    ProgressView()
        .controlSize(.small)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .onAppear { displayedCount += pageSize }
}
```

### Inline date/time pickers
Use native `.compact` `DatePicker` inside chip-styled `HStack` containers instead of custom popover pickers:
```swift
DatePicker("", selection: $date, displayedComponents: .date)
    .labelsHidden()
    .datePickerStyle(.compact)
```

## Architecture
- Services in `DeepThink/Services/` — singletons via `.shared`, `@Observable`
- Views in `DeepThink/Views/` — organized by feature (Settings, Shared, etc.)
- MCP server source at `cli/src/mcp-server.ts` — built with Bun, output to `cli/out/deepthink-mcp`
- CLI source at `cli/src/index.ts` — built with Bun, output to `cli/out/deepthink`
- Both binaries are bundled into the app resources via Xcode post-compile script

## Code Style
- No comments unless explaining a non-obvious "why"
- Prefer editing existing files over creating new ones
- Keep views small — extract subviews as private structs in same file
- Use `@ViewBuilder` for computed view properties

## Working Philosophy
- **macOS 14+ compatibility:** All UI must render consistently across macOS 14–26. Avoid raw system colors that resolve differently across OS versions — always go through DS tokens.
- **Token-first:** When you need a value not in DS, add the token to `DesignSystem.swift` first, then use it. Never scatter raw literals.
- **Pointer cursor on everything clickable:** Every `Button`, `onTapGesture`, or interactive element must show a pointer cursor. Use `.buttonStyle(.plainPointer)`, `.dsPrimary`, `.dsSecondary`, or `.pointerOnHover()`.
- **No visual regressions:** When refactoring styles to use DS tokens, the rendered output must not change. Map to tokens with identical numeric values.
