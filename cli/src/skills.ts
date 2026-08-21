// Canonical source for the Claude Code skills DeepThink installs. The markdown
// lives in cli/skills/deepthink/ and is embedded into the compiled binary by Bun
// (text imports are bundled by `bun build --compile`), so the CLI, the app, and any
// agent all install the exact same files — no drift.

import recall from "../skills/deepthink/recall.md" with { type: "text" };
import remember from "../skills/deepthink/remember.md" with { type: "text" };
import syncSession from "../skills/deepthink/sync-session.md" with { type: "text" };
import router from "../skills/deepthink.md" with { type: "text" };

// path (relative to ~/.claude/commands/) → content. The top-level deepthink.md is
// the `/deepthink` router; the deepthink/ subdir holds the `/deepthink:<name>` skills.
export const SKILLS: Record<string, string> = {
  "deepthink.md": router,
  "deepthink/sync-session.md": syncSession,
  "deepthink/recall.md": recall,
  "deepthink/remember.md": remember,
};
