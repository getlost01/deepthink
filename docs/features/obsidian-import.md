# Obsidian Vault Import

One-click import of Obsidian vaults into DeepThink's knowledge base. Converts Obsidian-specific syntax, preserves folder structure, and makes everything AI-searchable.

## Why Import

Obsidian is great for writing and organizing notes. But it has no AI RAG, no semantic search, no auto-context injection. DeepThink turns static Obsidian notes into active knowledge that AI uses automatically in every conversation.

## How To Use

1. Go to **Knowledge** section
2. Click **Add** → **Import Obsidian Vault**
3. Select your vault folder
4. Configure options (all on by default)
5. Click **Import Vault**
6. Wait for progress bar to complete

## What Gets Converted

### Wiki-Links

| Obsidian | DeepThink |
|----------|-----------|
| `[[Note Name]]` | `[Note Name](note-name)` |
| `[[Note Name\|Display Text]]` | `[Display Text](Note Name)` |
| `![[embedded.png]]` | `[Embedded: embedded.png]` |

### Callouts

| Obsidian | DeepThink |
|----------|-----------|
| `> [!note] Title` | `> **Note:** Title` |
| `> [!warning] Careful` | `> **Warning:** Careful` |
| `> [!tip]` | `> **Tip:**` |

### Other Syntax

| Obsidian | DeepThink |
|----------|-----------|
| `%%hidden comment%%` | Removed |
| `#inline-tag` | Extracted to frontmatter tags |
| YAML frontmatter | Preserved and merged |

### Tags

Inline `#tags` in note body are extracted and added to the entry's frontmatter tags array. Tags inside code blocks are ignored.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| Preserve folder structure | On | Keep vault subfolder hierarchy under destination |
| Convert wiki-links | On | Transform `[[links]]` and callouts to standard markdown |
| Extract inline tags | On | Pull `#tags` from body into frontmatter |
| Skip duplicates | On | Skip files >75% similar to existing knowledge entries |
| Destination folder | "obsidian" | Name of the knowledge folder to import into |

## Folder Structure

A vault like:

```
my-vault/
  daily/2024-03-15.md
  projects/api-redesign.md
  research/caching-strategies.md
```

Becomes:

```
~/DeepThink/knowledge/obsidian/
  daily/2024-03-15.md
  projects/api-redesign.md
  research/caching-strategies.md
```

Each file gets DeepThink frontmatter:

```markdown
---
title: API Redesign
source: obsidian
folder: obsidian/projects
tags: [architecture, backend]
imported_at: 2026-05-04T10:30:00Z
---

(converted content)
```

## After Import

- All entries appear in Knowledge browser under the destination folder
- BM25 + semantic indexes rebuilt automatically
- AI chat can reference imported knowledge immediately
- Agent `knowledge_scope` can target `obsidian` or subfolders like `obsidian/research`

## Handling Large Vaults

- Progress bar shows real-time count and percentage
- Uses `autoreleasepool` for memory management
- Yields to main thread every 50 files for UI responsiveness
- Dedup check prevents re-importing existing content

## Key Files

| File | Role |
|------|------|
| `Services/ObsidianImportService.swift` | Vault scanning, syntax conversion, import logic |
| `Views/Knowledge/ObsidianImportView.swift` | Import UI (folder picker, options, progress) |
| `Views/Knowledge/KnowledgeBrowserView.swift` | "Import Obsidian Vault" menu entry |
