---
description: Warm up a new Claude Code session with prior DeepThink context for this repo — recent sessions, open follow-ups, and (optionally) a scoped relevance search.
---

Load the DeepThink history for this repo's bucket so we resume with full context instead of starting cold. The counterpart to `/deepthink:sync-session`.

## Step 1 — Locate the repo

```bash
pwd    # cwd to pass to the tool (it resolves the bucket from git)
```

If `$ARGUMENTS` is provided, treat it as a focus query (and/or an explicit bucket name).

## Step 2 — Recall from DeepThink

Call `mcp__deepthink__knowledge_session` with:
- `action`: `"recall"`
- `cwd`: the `pwd` from Step 1
- `limit`: `5` (recent sessions; raise if you need more history)
- `query`: `$ARGUMENTS` if it reads like a topic to focus on (otherwise omit)
- `bucket` / `type`: only if `$ARGUMENTS` names an explicit non-repo bucket

## Step 3 — Brief the user

Synthesize the tool's response into a short briefing — do **not** dump raw JSON:

```
## Resuming "<bucket.name>" — <N> prior sessions

**Last worked on:** <topic + date of most recent session>

**Recent context**
<2–4 bullets distilled from the recent sessions>

**Open follow-ups**
<bullet list from openFollowUps — "none" if empty>

<if query was given: a short "Most relevant to '<query>'" section from `relevant`>
```

If there are open follow-ups, ask whether to pick one up now. To see how the ledger stands
before choosing, call `workspace_task {action:"list", topLevelOnly:true}` — then
`workspace_task {action:"get", ref}` on the one you pick to see its `subtasks`.

If the bucket has no prior sessions, say so in one line and suggest running
`/deepthink:sync-session` at the end of this session to start the history.
