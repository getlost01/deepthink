---
description: Capture the current Claude Code session to DeepThink — what was worked on, decisions made, files changed, and open items. Scoped to the repo/project bucket.
---

Synthesize this Claude Code session and persist it to the DeepThink knowledge base, scoped to this repo's bucket.

## Step 1 — Gather context

Run these shell commands to ground the summary in facts:

```bash
pwd                                                       # cwd to pass to the tool
git rev-parse --show-toplevel 2>/dev/null || pwd          # repo root
git branch --show-current 2>/dev/null                     # current branch
git log --oneline -10 2>/dev/null                         # recent commits
git diff --stat HEAD 2>/dev/null                          # changed files
date +%Y-%m-%d                                            # today's date
```

The MCP tool resolves the **bucket** itself from the git remote of `cwd` (falling back to the
folder name), so you don't need to compute a project slug. Just capture `pwd` to pass along.

If `$ARGUMENTS` is provided, treat it as an explicit bucket name (use it as `bucket` and set
`type` to `topic` unless it's clearly a repo).

## Step 2 — Build the summary

Use conversation history as the primary source; use git output to fill gaps or verify file names.
Include only what actually happened — do not pad or invent.

```
# Session: <date> — <one-line topic>

**Date:** <date>

## What was worked on
<bullet list — features, bugs, refactors, investigations>

## Key decisions
<bullet list — architectural, approach, or design choices made>

## Files changed
<bullet list — notable files created or modified with a short reason>

## Outcomes
<what was completed, fixed, or shipped>

## Open items / follow-ups
<unresolved work, deferred items, or follow-ups — "none" if clean>
```

Omit any section with no content.

## Step 3 — Capture to DeepThink

Call `mcp__deepthink__knowledge_session` with:
- `action`: `"sync"`
- `cwd`: the `pwd` from Step 1 (lets the tool resolve the bucket + branch from git)
- `content`: full markdown from Step 2
- `title`: `"Session <date>: <one-line topic>"`
- `date`: today's date
- `bucket` / `type`: only if `$ARGUMENTS` gave an explicit bucket name
- `openItems`: the bullet list from the "Open items / follow-ups" section (omit if none)

The tool stores the session in the bucket, updates bucket stats, and — unless you pass
`promoteOpenItems: false` — creates workspace tasks for each open follow-up, linked to the
bucket's project. Pass `promoteOpenItems: false` if you don't want tasks created.

## Step 4 — Confirm

On success, output one line summarizing the tool's result:

```
Saved → DeepThink bucket "<bucket.name>": "<title>"  (<N> follow-up tasks created)
```

If the MCP tool is unavailable, print the full summary so nothing is lost:

```
DeepThink MCP not connected. Session summary:

<markdown from Step 2>
```

## Note: this often runs automatically

A `SessionEnd` hook (`deepthink session autosync`) summarizes and saves most sessions on
exit, so you usually don't need to run this by hand. Use `/deepthink:sync-session` when you
want a curated summary, an explicit bucket, or follow-up tasks created (autosync defaults to
**not** creating tasks).

## Capturing single facts mid-session

For a one-off decision, gotcha, or snippet — rather than a whole-session summary — call
`mcp__deepthink__knowledge_session` with `action: "note"`, `cwd`, a `kind`
(`decision` | `gotcha` | `snippet` | `insight` | `context`), and `content`. It's indexed on
its own and scoped to the repo's bucket, so it surfaces precisely in later retrieval.
