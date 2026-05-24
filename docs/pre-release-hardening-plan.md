# Pre-Release Hardening Plan

## Context

DeepThink is about to ship publicly. A deep-dive review found the architecture sound and all three layers (macOS app, CLI, MCP server) connecting correctly, but identified seven critical/high-priority issues that will surface as user-facing bugs immediately after launch. Item #1 (`--dangerously-skip-permissions` on Claude CLI invocations) is intentionally deferred; this document covers the remaining six.

Goal: fix the failure modes most likely to cause data loss, silent breakage, or "it just doesn't work" reports in v1.0 - without rewriting any architectural pieces.

---

## Scope

Six fixes, ordered by risk × effort:

1. **CLI status check** - detect Claude CLI + Swift toolchain, print actionable setup info
2. **Atomic archive writes** - temp-file + rename in `compressKnowledge`/`archiveProject`
3. **Embed-helper logging** - surface `swiftc -O` compile failures + clear fallback message (folded into Fix 1)
4. **`@MainActor` isolation** - fix SwiftData write races in CollectorScheduler/DataCollectorService
5. **App-level error surfacing** - wire `AppState.presentError` + reuse existing `ToastState`
6. **Backup safety** - WAL checkpoint before copy, validate restore, surface failures

Deferred (ship as known limitations in v1.0 changelog): full-text knowledge search, knowledge base ↔ SwiftData referential integrity, script execution sandbox, intent classification quality, service startup race coordination, request size limits, deeplink UUID validation.

---

## Fix 1 - CLI Status: Claude CLI + Embedding Toolchain Detection

**Files:** `cli/src/core/llm.ts`, `cli/src/core/embedding-service.ts`, `cli/src/index.ts`

**Problem:** `deepthink status` shows `claude: not found` with no path searched, no install hint. Embedding helper fails silently (returns null vectors forever) if `swiftc` isn't installed; user never learns semantic search is disabled.

**Approach:**

In `llm.ts` (lines 5–20):
- Export a new `CLAUDE_SEARCH_PATHS` constant from the existing inline candidates array.
- Add `findClaudePath(): { path: string | null; searched: string[] }` - non-throwing structured result.
- Keep `findClaude()` as the throwing wrapper; have `isClaudeAvailable()` delegate to the new helper.

In `embedding-service.ts`:
- Add a module-level `_lastEmbedError: { stage: 'compile' | 'runtime'; message: string } | null` flag.
- In `ensureHelper()` catch (lines 98–100): capture `err.stderr || err.message`, distinguish ENOENT (swiftc missing) from compile errors, store in `_lastEmbedError`.
- In `embedBatch()` catch (lines 148–150): set runtime error similarly.
- Extend `embeddingStats()` (line 470) to include `available: boolean` plus `reason?: string` when unavailable.

In `index.ts` `cmdStatus()` (lines 39–49):
- When `isClaudeAvailable()` is false, print the searched list + `install: https://claude.ai/code`.
- Add an `embeddings:` line: when unavailable, print "disabled - install Xcode Command Line Tools: `xcode-select --install`".
- When available, print `embeddings: ready`.

**Verification:**
- `mv ~/.local/bin/claude ~/.local/bin/claude.bak && deepthink status` → shows searched paths + install URL. Move it back.
- Rename `swiftc` temporarily on `$PATH`, run `deepthink ask "test"` → see clear log message; `deepthink status` reports embeddings disabled with install hint.

---

## Fix 2 - Atomic Archive Writes

**Files:** `cli/src/tools/knowledge.ts` (`compressKnowledge` lines 195–222, `archiveProject` lines 224–275)

**Problem:** Both functions (a) `writeFileSync` archive directly (non-atomic), (b) then `unlinkSync` originals. If the process dies between archive-write and original-delete, archive may be partial AND originals may be gone. The LLM `query()` call is not wrapped - failures throw raw errors to the CLI dispatcher.

**Approach:**

Add a helper at the top of `knowledge.ts`:
```ts
function atomicWrite(targetPath: string, content: string): void {
  const tmp = `${targetPath}.tmp-${process.pid}-${Date.now()}`;
  writeFileSync(tmp, content, "utf-8");
  renameSync(tmp, targetPath);
}
```

In both `compressKnowledge` and `archiveProject`:
- Wrap the full body in `try/catch`; on error, attempt cleanup of any `.tmp` file and rethrow with context.
- Replace `writeFileSync(archiveFile, content, ...)` with `atomicWrite(archiveFile, content)`.
- Only delete originals AFTER `renameSync` succeeds (existing order is roughly right but not enforced - make it explicit).
- If any original `unlinkSync` fails, log a warning but do not throw (archive succeeded; user can manually clean up).
- Wrap the `query()` LLM call in try/catch and rethrow with a "compression failed for <source>/<channel>" prefix.

Leave `notifyAppSync()` fire-and-forget.

**Verification:**
- `deepthink knowledge capture testsrc testch "hello world"` (a few times).
- `deepthink knowledge compress testsrc testch` → archive file exists, originals gone.
- Simulate failure: temporarily make `~/DeepThink/knowledge/archive/` read-only, retry → originals untouched, no `.tmp` file left behind.
- Re-enable, retry → succeeds normally.

---

## Fix 3 - Embed-Helper Logging (folded into Fix 1)

Already covered by Fix 1:
- Distinguish `swiftc` missing (ENOENT) from compile errors and from runtime helper failures.
- One-time `console.warn` gated by a `_warned` flag to avoid spam (helper is called from `embedBatch` and `embeddingStats`).
- `embeddingStats()` returns a `reason` so `cmdStatus` can show it.

No separate work item.

---

## Fix 4 - `@MainActor` Isolation for SwiftData Writes

**Files:** `DeepThink/Services/CollectorScheduler.swift`, `DeepThink/Services/DataCollectorService.swift`

**Problem:** `CollectorScheduler.syncSource(id:)` (lines 75–90) creates a background `ModelContext`, fetches a `DataSource` model on that context, then passes the model across actor boundaries into `DataCollectorService.sync(source:container:)`, which mutates `source.itemCount` / `source.lastSyncAt` inside `MainActor.run { ... }`. Mutating a model fetched on a different context's thread is undefined behavior in SwiftData and can corrupt the store. `try? context.save()` (line 85) silently swallows failures.

**Approach:**

Refactor the boundary so we pass `PersistentIdentifier` across threads, never the model instance:

1. Change `DataCollectorService.sync` signature to `sync(sourceID: PersistentIdentifier, container: ModelContainer) async` - the function constructs its own `ModelContext` on `@MainActor`, refetches by ID, performs the work, then saves.
2. Mark `DataCollectorService.sync` (and helpers that touch the model) as `@MainActor`. Heavy data-collection work (URL scraping, folder walking) already runs on its own queues inside helper functions - only the model mutations need to be main-isolated.
3. In `CollectorScheduler.syncSource(id:)`, look up the `PersistentIdentifier` on `@MainActor`, then call the new signature. Drop the manual `ModelContext` creation on the detached task.
4. Replace the four `try? context.save()` calls in `CollectorScheduler.swift` with `do/catch` + `appState.presentError(error, context: "Collector sync save")` (uses Fix 5).
5. Remove the five now-redundant `MainActor.run` blocks in `DataCollectorService.sync` (lines 439–473) - they become unnecessary once the function is `@MainActor`.

`activeSources` mutation already hops to MainActor; leave as is.

**Verification:**
- Build with `-strict-concurrency=complete` and confirm no warnings from the touched files.
- Add a folder DataSource and a URL DataSource; toggle both enabled.
- Trigger several concurrent "Run Now" syncs on different sources from the UI - no crashes, `itemCount` updates correctly, `lastSyncAt` advances.
- Force-quit during a sync - relaunch, no Core Data validation errors in logs.

---

## Fix 5 - App-Level Error Surfacing

**Files:** `DeepThink/State/AppState.swift`, `DeepThink/Views/ContentView.swift`, targeted Service files

**Problem:** 162 `try?` calls across `DeepThink/Services/`. Four are `try? context.save()` (highest data-loss risk); 24 are SwiftData fetches; ~80 are file I/O. `AppState` has no error surface. Restore failures currently use blocking `NSAlert` (BackupService.swift:140–157).

**Approach:**

In `AppState.swift` (alongside existing properties around lines 82–87):
```swift
struct PresentedError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let context: String
}

@MainActor var presentedError: PresentedError?

@MainActor func presentError(_ error: Error, context: String) {
    presentedError = PresentedError(
        title: "Something went wrong",
        message: error.localizedDescription,
        context: context
    )
    ToastState.shared.showError("\(context): \(error.localizedDescription)")
}
```

Reuse the existing `ToastState` / `DSToastView` in `DesignSystem.swift:1379–1429` - already supports `showError(_:)` with red danger styling. No new component needed.

In `ContentView.swift`, attach a single `.alert(item: $appState.presentedError) { err in ... }` at the root for critical errors.

**Triage of the 162 `try?` calls (target ~25–30 highest-risk sites in this pass):**
- **Keep `try?`** for genuinely best-effort writes (cache cleanup, sentinel writes, optional directory creation) - ~40 sites.
- **Convert to `do/catch` + log only** for most file I/O on non-user data - defer to follow-up.
- **Convert to `do/catch` + `appState.presentError`** for: all 4 `context.save()`; all ~10 `try? md.write(to:)` in KnowledgeService; all empty `catch { }` in BackupService; the `try?` chain in `applyPendingRestoreIfNeeded` (lines 52–68).

Don't attempt to convert all 162 in this pass - schedule a follow-up audit post-launch.

**Verification:**
- Temporarily make `~/DeepThink/knowledge/` read-only, try to capture a note → toast appears + alert shows.
- Restore permissions.
- Corrupt the backup manifest JSON, restart app → surfaced error rather than empty backup list.

---

## Fix 6 - Backup Safety

**Files:** `DeepThink/Services/BackupService.swift`

**Problem:** `performBackup(to:)` (lines 171–195) uses `FileManager.copyItem` while SwiftData has the WAL open. No `wal_checkpoint(TRUNCATE)` before copy → backed-up `.store` may be missing recent writes still in `-wal`. `performRestore` silent rollback (lines 219–225). `applyPendingRestoreIfNeeded` swallows errors (lines 66–68). Manifest load/save (lines 296–304) silently corrupts.

**Approach:**

1. **WAL checkpoint before backup.** SwiftData doesn't expose `PRAGMA wal_checkpoint` directly. Briefly open the SwiftData store via raw `sqlite3_open_v2` in read-write mode, run `PRAGMA wal_checkpoint(TRUNCATE)`, close. Do this immediately before `fm.copyItem`. The main `ModelContainer` stays open; SQLite handles the concurrent checkpoint cleanly because `journal_mode=WAL` is already set.

2. **Restore validation.** After `performRestore(from:)` copies subdirs, confirm `data/deepthink.store` exists and is openable by `sqlite3_open` (read-only). If the open fails, treat as a failed restore and trigger the existing rollback path.

3. **Surface restore failures.** Replace the empty `catch { // Leave pending file; will retry next launch }` at lines 66–68 with: persist the error to a `restore-error.txt` sentinel next to `pending-restore.txt`. After `ModelContainer` opens and `AppState` exists, `BackupService.start()` reads the sentinel, calls `appState.presentError(...)`, then deletes it.

4. **Surface manifest corruption.** Wrap manifest load (lines 296–297) and save (lines 303–304) in `do/catch`; on load failure, rename the corrupt file to `manifest.corrupt.json` and call `presentError`; on save failure, log + presentError.

5. **Replace the existing `NSAlert` in BackupService** (lines 140–157) with `appState.presentError` for consistency.

**Verification:**
- Trigger a manual backup; inspect the resulting `data/deepthink.store-wal` size before and after - checkpoint should have flushed it.
- Force a restore from a known-good snapshot → succeeds.
- Replace a snapshot's `deepthink.store` with garbage bytes, queue restore, relaunch → restore fails, original data preserved, error surfaced.
- Corrupt the manifest JSON → app launches, surfaces error, renames file, regenerates clean manifest.

---

## Backlog - Picks for After v1.0

Full list of remaining issues from the pre-release review, grouped by priority and layer. Pick from here when scheduling the next pass.

### Priority A - Security / Data Integrity

| ID | Issue | Layer | File / Location | Effort |
|----|-------|-------|------------------|--------|
| A1 | `--dangerously-skip-permissions` passed on every Claude CLI call - bypasses all permission gating. Originally #1 in release sequence; intentionally deferred for v1.0. | CLI | `cli/src/core/llm.ts:39` | 10 min + UX design for prompt |
| A2 | Service startup race: `KnowledgeService.reload`, `EmbeddingService.indexWorkspaceItems`, `ContextEngine.rebuildIndex` all fire concurrently with no coordinator. Searches in the first ~5s return incomplete results silently. | App | `DeepThinkApp.swift:151–154` + the three services | 3–4 hrs |
| A3 | Knowledge base ↔ SwiftData have no referential integrity. Deleting a `Note` in UI doesn't remove the markdown file. Re-importing duplicates aren't deduped. Drifts over time. | App | `KnowledgeService.swift` + Note model | 4–6 hrs |
| A4 | `DataCollectorService.runScript` executes arbitrary zsh with no command whitelist or sandbox. 120s timeout only. | App | `DataCollectorService.swift:192` | 2 hrs |
| A5 | `MCPServer.envDict` parses env vars by splitting on `\n` then `=` - no escaping, fails on values containing `=` or newlines. Config also written to disk unencrypted (`mcp-active.json`) - secrets exposed. | App | `MCPServer` model + `StorageService` | 2 hrs |

### Priority B - Reliability / Failure Modes

| ID | Issue | Layer | File / Location | Effort |
|----|-------|-------|------------------|--------|
| B1 | SQLite accessed by both app and CLI concurrently. WAL + `busy_timeout=5000ms` mitigates but doesn't eliminate write contention. No coordination protocol. | App + CLI | `VectorStore.swift` + `cli/src/core/db.ts` | 4 hrs (add IPC layer) or document |
| B2 | Read-only `getDB()` in CLI doesn't set `busy_timeout` - reader can hit SQLITE_BUSY immediately if writer mid-tx. | CLI | `cli/src/core/db.ts:50` | 5 min |
| B3 | `notifyutil` duplicated between `db.ts:97` and `knowledge.ts:7`. Consolidate into one helper. | CLI | `cli/src/core/db.ts`, `cli/src/tools/knowledge.ts` | 15 min |
| B4 | Knowledge `searchIntegrationData()` is O(n×m) linear substring scan - unusable past ~1k entries. Needs SQLite FTS5 or similar. | CLI | `cli/src/tools/knowledge.ts` | 1 day |
| B5 | `knowledge_capture` MCP tool has no max size limit. Large pastes bloat `vectors.db`. | MCP | `cli/src/tools/knowledge.ts` + tool schema | 30 min |
| B6 | `workspace_resolve_deeplink` accepts any string as UUID - no format validation. Confusing "not found" instead of "invalid link". | MCP | `cli/src/tools/workspace.ts:532–574` | 15 min |
| B7 | `classifyIntent()` in smart-mcp uses simple keyword matching - fragile (e.g. "update the backup" misclassified as full data load). | MCP | `cli/src/tools/smart-mcp.ts:71–79` | 2 hrs (or accept) |
| B8 | `compressKnowledge` truncates content silently at 32KB. No warning or paging for large inputs. | CLI | `cli/src/tools/knowledge.ts:200–250` | 1 hr |
| B9 | `TaskNotificationService` checks daily at 9am - misses if app not running. DST transitions can also skip a day. | App | `TaskNotificationService.swift` | 2 hrs |
| B10 | No retry queue if `UNUserNotificationCenter` authorization is denied or scheduling fails. | App | `ReminderDetailView.swift`, `TaskNotificationService.swift` | 2 hrs |

### Priority C - Performance / Scalability

| ID | Issue | Layer | File / Location | Effort |
|----|-------|-------|------------------|--------|
| C1 | `ProjectDetailView` and `AllTasksView` each use `@Query` over all tasks. At 10k+ items this blocks UI thread. Needs `@SectionedFetchRequest` or paging. | App | Views/Projects, Views/Tasks | 4 hrs |
| C2 | Context Graph runs force simulation on 400+ nodes with no LOD. Zoom doesn't reduce node count. Semantic edges recomputed per search. | App | `ContextGraphView.swift` | 1 day |
| C3 | `KnowledgeExtractionService` auto-tagging fires Claude API call per new entry - no batching, no rate limit. 100 entries = 100 calls. | App | `KnowledgeExtractionService.swift` | 2 hrs |
| C4 | Embedding cache uses `_embeddingCache.delete(_embeddingCache.keys().next().value!)` - `!` will throw TypeError if cache empties during a race. | CLI | `cli/src/core/embedding-service.ts:142` | 5 min |
| C5 | MCP server streaming has hard 120s kill with no graceful shutdown. Large responses can OOM (no output buffer cap). | App + CLI | `MCPService.swift`, `DeepThinkCLIService` | 1 hr |
| C6 | `VectorStore` pruning happens after indexing; no transaction wrap. Concurrent reads can see partial state. | App | `VectorStore.swift` | 2 hrs |

### Priority D - Polish / UX

| ID | Issue | Layer | File / Location | Effort |
|----|-------|-------|------------------|--------|
| D1 | Remaining ~130 lower-risk `try?` call sites (file I/O on non-user data, optional cache cleanup). Audit + convert the ones that hide actionable failures. | App | `DeepThink/Services/*` | 4 hrs |
| D2 | Folder watcher: FSEventStreamRef release errors silently swallowed in deinit. Potential leak under rapid add/remove. | App | `FolderWatcher` in `DataCollectorService.swift` | 1 hr |
| D3 | Accessibility: most `systemImage:` uses lack `.accessibilityLabel`. Context Graph not navigable by keyboard or VoiceOver. | App | All views, esp. `ContextGraphView` | 1 day audit |
| D4 | Deep links (`deepthink://`) don't validate that target items exist before navigating. Fallback UI is inconsistent across views. | App | `AppState.handleDeepLink` + views | 2 hrs |
| D5 | `slugify()` in knowledge.ts loses special chars - filenames can't reliably round-trip. Two files created in same millisecond can collide. | CLI | `cli/src/tools/knowledge.ts` | 1 hr |
| D6 | Append-only `context.md` / `decisions.md` grow into giant files with no edit affordance. | CLI + App | `cli/src/tools/knowledge.ts` + Knowledge view | 1 day (UX redesign) |
| D7 | No backup/restore for knowledge archives - once compressed, originals gone with no rollback. Manifest of original paths in archive header would let "undo" work. | CLI | `cli/src/tools/knowledge.ts` | 3 hrs |
| D8 | No "saved searches" / smart collections model. No audit log. No conflict resolution for multi-device sync. | App | New SwiftData models | 1+ day per feature |
| D9 | CLI path stored in `UserDefaults` isn't validated on each launch. If PATH changes, app doesn't adapt. | App | `ClaudeService.swift` | 30 min |
| D10 | No offline queue: if network drops mid-CLI-call, no retry. | App + CLI | Multiple | 4 hrs |

### Suggested Next Sweep (post-v1.0)

If picking a single 1-day batch, recommend: **A2 + B2 + B5 + B6 + C4 + D2**. These together remove the next tier of silent-failure bugs without architectural change, and stack into a coherent "stability patch" v1.0.1.

For a 1-week batch: add **B4** (FTS5 search) + **C1** (paged queries) + **A3** (knowledge ↔ SwiftData sync) - these are the items most likely to bite power users with large datasets.

---

## Execution Order

Minimal cross-dependencies. Suggested order:

1. **Fix 5** (AppState error surface) - Fixes 4 and 6 depend on `appState.presentError`
2. **Fix 1** (CLI status detection) - independent, lowest risk
3. **Fix 2** (atomic archive writes) - independent, contained to one file
4. **Fix 4** (`@MainActor` isolation) - touches two service files, build/test carefully
5. **Fix 6** (backup safety) - depends on Fix 5
6. Final pass: re-run full app, run `deepthink status`, test backup + restore, force a sync error to confirm surfaced errors render correctly

Total expected effort: **~8–10 hours of focused work**, plus 1–2 hours of end-to-end verification.
