---
description: Save a fact to DeepThink long-term memory, auto-scoped to this repo. The quick "remember this" capture for a decision, gotcha, snippet, or insight worth keeping.
---

Persist a single fact so it surfaces in later retrieval — without a full session summary. Auto-scoped to this repo's bucket and auto-classified by kind.

## Step 1 — Locate the repo

```bash
pwd    # cwd to pass to the tool (it resolves the bucket from git)
```

## Step 2 — Decide what to save

`$ARGUMENTS` is the fact to remember. If it's empty, synthesize the most important
thing worth keeping from the current conversation — a decision made, a gotcha hit, a
useful snippet, or an insight — in one or two tight sentences. Don't pad or invent.

## Step 3 — Capture

Call `mcp__deepthink__remember` with:
- `content`: the fact (markdown ok)
- `cwd`: the `pwd` from Step 1
- `kind`: only if you want to override auto-detection (`decision` | `gotcha` | `snippet` | `insight` | `context`)
- `bucket` / `type`: only if `$ARGUMENTS` names an explicit non-repo bucket

The tool auto-detects the kind from the content and scopes it to the repo's bucket, so
you usually only need `content` + `cwd`.

## Step 4 — Confirm

Output one line: `Remembered (<kind>) → "<bucket.name>": "<title>"`.

## When to use what

- **One fact, right now** → this skill / `mcp__deepthink__remember`.
- **Whole-session summary** → `/deepthink:sync-session` (or it happens automatically on exit).
- **General/cross-repo knowledge** → `mcp__deepthink__knowledge_project {action:"save"}`.
