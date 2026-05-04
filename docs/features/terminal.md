# Terminal

Built-in multi-tab terminal emulator powered by SwiftTerm with AI-powered output analysis.

## Overview

A native terminal embedded in DeepThink so you can run commands, scripts, and tools without leaving the app. Each tab is an independent shell session.

## Multi-Tab Sessions

Sessions are managed in `AppState.terminalSessions` with `activeTerminalSessionID` tracking the current tab.

### Session Lifecycle

1. **Create** — click "+" or open Terminal section for the first time
2. **Start** — initializes zsh/bash process with inherited environment
3. **Use** — full terminal emulation via SwiftTerm's `LocalProcessTerminalView`
4. **Analyze** — click "Analyze" to send output to Claude
5. **Terminate** — close tab or quit app

### Session Properties

| Property | Description |
|----------|-------------|
| `id` | UUID |
| `title` | Auto-updates from terminal title escape sequences |
| `currentDirectory` | Tracked via `hostCurrentDirectoryUpdate` |
| `isRunning` | Green dot = running, faded = terminated |

## AI Output Analysis

The standout feature — click "Analyze" on any terminal tab:

1. Captures last 50 lines of terminal display via `getTextBuffer(lastLines:)`
2. Sends to Claude with system prompt for CLI output analysis
3. Displays results in a markdown sheet with copy-to-clipboard
4. Useful for parsing build errors, test results, log output, command output

## Key Files

| File | Role |
|------|------|
| `Views/Terminal/TerminalSession.swift` | Session model, shell process management |
| `Views/Terminal/TerminalHostView.swift` | SwiftTerm NSViewRepresentable wrapper |
| `Views/Terminal/TerminalView.swift` | Tab bar, session management UI, analyze button |
