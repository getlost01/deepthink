# Data Collection

Automated and manual knowledge capture from multiple sources with scheduling support.

## Sources

| Type | Description | Scheduling |
|------|-------------|-----------|
| **URL** | Scrape web pages → HTML to markdown | Manual or recurring |
| **RSS/Atom Feed** | Parse feeds, scrape articles | Recurring |
| **Folder** | Watch directory, incremental file sync | Recurring |
| **Clipboard** | Capture system pasteboard content | Manual or recurring |
| **Script** | Run shell command, capture output | Recurring |
| **MCP** | External data via Model Context Protocol | On-demand |

## Data Source Model

Each configured source is stored as a SwiftData `DataSource`:

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Display name |
| `type` | DataSourceType | folder, url, script, mcp, clipboard, rssFeed |
| `path` | String? | Filesystem path (for folder type) |
| `url` | String? | Web URL (for url/rssFeed types) |
| `scriptCommand` | String? | Shell command (for script type) |
| `scheduleInterval` | Int | Seconds between syncs (0 = manual only) |
| `isEnabled` | Bool | Whether sync is active |
| `lastSyncAt` | Date? | Last successful sync timestamp |
| `itemCount` | Int | Total items collected |

## How Each Source Works

### URL Scraping

1. `URLSession` fetches HTML
2. Regex strips `<script>`, `<style>` tags
3. Converts `<br>`, `<p>`, `<h1-6>`, `<li>` to markdown equivalents
4. Strips remaining HTML tags, decodes entities
5. Extracts `<title>` for entry title
6. Creates knowledge entry in `knowledge/web/`

### RSS/Atom Feeds

1. Fetch XML feed
2. Parse `<item>` (RSS) or `<entry>` (Atom) elements
3. Extract title, description/content/summary, link
4. Dedup against existing entries (Jaccard similarity >0.7)
5. For items with links: scrape the full article URL
6. For items without links: use feed content directly

### Folder Watch

1. Enumerate directory recursively (skip hidden files)
2. Filter for `.md`, `.markdown`, `.txt` files
3. Compare modification dates with destination copies
4. Copy only new/modified files (incremental sync)
5. Destination: `knowledge/{folder-name}/`

### Clipboard Capture

1. Read `NSPasteboard.general` string content
2. Create entry titled "Clipboard {date}"
3. Store in `knowledge/clipboard/`

### Script Runner

1. Execute command via `/bin/zsh -c`
2. Capture stdout
3. Create entry titled "Script Output {date}"
4. Store in `knowledge/scripts/`

## Scheduling

`CollectorScheduler` manages recurring syncs:

1. On `start(container:)`, loads all enabled `DataSource` records
2. Creates `Timer` for each source with `scheduleInterval > 0`
3. Timer fires → calls `DataCollectorService.shared.sync(source:container:)`
4. Sync updates `lastSyncAt` and `itemCount`
5. Manual sync via `runNow(source:)` for immediate collection

### Sync Logic

```text
Timer fires
    ↓
Check: never synced OR (now - lastSyncAt) > interval?
    YES → run sync
    NO  → skip
```

## Deduplication

Before creating any entry:
1. `ContextEngine.isDuplicate(content:)` — exact hash match
2. `ContextEngine.isDuplicateOrSimilar(content:, threshold: 0.75)` — Jaccard similarity check
3. Duplicate → skipped, logged to "collector" log

## Configuration

Settings → Connections → Data Sources:
- Add new sources
- Configure schedule intervals
- Enable/disable individual sources
- View sync history and item counts

## Key Files

| File | Role |
|------|------|
| `Models/DataSource.swift` | SwiftData model for configured sources |
| `Services/DataCollectorService.swift` | All capture methods (URL, RSS, folder, clipboard, script) |
| `Services/CollectorScheduler.swift` | Timer-based recurring sync management |
| `Views/Settings/IntegrationsView.swift` | Source configuration UI |
