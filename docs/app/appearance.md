# Appearance & theme

DeepThink supports **System**, **Light**, and **Dark** appearance. The choice applies across the native UI, markdown editor, chat markdown, and built-in terminal.

## Change theme

1. Open **Settings** (sidebar → gear, or **⌘,**)
2. Under **General**, find **Appearance → Theme**
3. Pick **System**, **Light**, or **Dark**

**System** follows macOS light/dark mode and updates automatically when you change the system setting.

Your choice is saved in app preferences and restored on launch.

## What updates with the theme

| Surface | Behavior |
|---------|----------|
| **App chrome** | Sidebar, headers, panels, modals, and settings use the active palette |
| **Markdown editor** | TipTap editor in notes receives CSS variables from the theme |
| **AI chat** | Rendered markdown in assistant messages matches light or dark |
| **Terminal** | Background and foreground colors sync with the theme |
| **Quick Capture** | Sheet modal uses the same palette |

Light and dark palettes share the same layout and accent semantics; only colors and contrast shift.

## For developers

All UI must use `DS.*` tokens from `DesignSystem.swift` — colors resolve through `DSThemeManager.shared.palette`. Do not use raw `Color.primary`, system materials, or inline hex values.

- Wrap top-level windows in `DSThemeRoot { }` so palette changes re-render
- Read colors via `DS.Colors.*` (theme-aware)
- Web views (editor, chat) sync via `DSThemeManager` JavaScript injection

See [DESIGN_SYSTEM.md](../../DESIGN_SYSTEM.md) and [CLAUDE.md](../../CLAUDE.md) for token rules and component patterns.
