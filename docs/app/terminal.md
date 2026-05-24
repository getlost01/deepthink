# Terminal

Built-in multi-tab terminal emulator powered by SwiftTerm with AI-powered output analysis.

## Overview

A native terminal embedded in DeepThink so you can run commands, scripts, and tools without leaving the app. Each tab is an independent shell session.

## Multi-Tab Sessions

Sessions are managed in `AppState.terminalSessions` with `activeTerminalSessionID` tracking the current tab.

### Session Lifecycle

1. **Create** — click "+" or `Cmd+T` when the Terminal section is active
2. **Start** — initializes zsh/bash process with inherited environment
3. **Use** — full terminal emulation via SwiftTerm's `LocalProcessTerminalView`
4. **Analyze** — click "Analyze" to send output to Claude
5. **Terminate** — close tab (`Cmd+W`) or quit app

### Starting Directory

Each new session opens in `~/deepthink` if that directory exists, otherwise falls back to `~` (home). Pass an explicit `directory` to `TerminalSession(title:directory:)` to override.

### Session Properties

| Property | Description |
|----------|-------------|
| `id` | UUID |
| `title` | Auto-updates from terminal title escape sequences |
| `currentDirectory` | Tracked via `hostCurrentDirectoryUpdate` |
| `isRunning` | Green dot = running, faded = terminated |

## Keyboard Shortcuts

These shortcuts fire when the Terminal section is visible, even though SwiftTerm's NSView holds first responder. They are registered as menu-level shortcuts via hidden zero-size buttons in the view hierarchy.

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New tab |
| `Cmd+W` | Close active tab |
| `Cmd+F` | Toggle search bar |
| `Cmd+=` | Increase font size |
| `Cmd+-` | Decrease font size |
| `Cmd+0` | Reset font size to default |

## AI Output Analysis

Click "Analyze" on any terminal tab:

1. Captures the last 50 lines from the full scrollback buffer via `getTextBuffer(lastLines:)`
2. Sends to Claude with a system prompt for CLI output analysis
3. Displays results in a markdown sheet with copy-to-clipboard
4. Shows an error alert if Claude is unavailable or the request fails
5. Useful for parsing build errors, test results, log output, command output

### Scrollback Extraction

`TerminalSession.getAllText()` reads from the scrollback buffer using `getScrollInvariantLine`, so "Analyze" and search see the full session history — not just the visible rows. For very long sessions where the user has scrolled far up, it falls back to the visible rows.

## Key Files

| File | Role |
|------|------|
| `Views/Terminal/TerminalSession.swift` | Session model, shell process management, scrollback extraction |
| `Views/Terminal/TerminalHostView.swift` | SwiftTerm NSViewRepresentable wrapper |
| `Views/Terminal/TerminalView.swift` | Tab bar, keyboard shortcuts, search, analyze button |
