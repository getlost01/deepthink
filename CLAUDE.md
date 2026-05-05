# DeepThink Development Guide

## Tech Stack
- **Language:** Swift 6 / SwiftUI
- **Platform:** macOS (AppKit + SwiftUI)
- **Data:** SwiftData for persistence
- **Terminal:** SwiftTerm for embedded terminal views

## Design System (`DS`)
All UI must use the design system defined in `DeepThink/Views/Shared/DesignSystem.swift`.

- **Colors:** `DS.Colors.*` — never use raw Color literals or system colors directly
- **Typography:** `DS.Font.*` (heading, body, caption, small, micro, monoSmall) — no ad-hoc font calls
- **Spacing:** `DS.Spacing.*` (xs, sm, md, lg, xl) — consistent padding/gaps
- **Radius:** `DS.Radius.*` (sm, md, lg) — rounded corners
- **Icons:** `DS.IconSize.*` (xs, sm, md, lg, xl, xxl) — icon sizing
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
- Reusable components live in `DeepThink/Views/Shared/`
- Use `DS.Colors.fill` / `DS.Colors.fillSecondary` for card backgrounds
- Use `DS.Colors.border` / `DS.Colors.borderHover` for strokes

## Architecture
- Services in `DeepThink/Services/` — singletons via `.shared`, `@Observable`
- Views in `DeepThink/Views/` — organized by feature (Settings, Shared, etc.)
- MCP server binary at `DeepThink/CLI/Sources/MCP/`
- CLI binary at `DeepThink/CLI/Sources/CLI/`

## Code Style
- No comments unless explaining a non-obvious "why"
- Prefer editing existing files over creating new ones
- Keep views small — extract subviews as private structs in same file
- Use `@ViewBuilder` for computed view properties
