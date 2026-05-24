import { REPO_RELEASES_LATEST_URL } from '../constants/repo'

export const landingContent = {
  hero: {
    badge: 'macOS 14+ · Open source · Local-first · Works with any AI agent',
    title: 'Local-first workspace and AI memory layer.',
    subtitle:
      'Native macOS app for notes, tasks, projects, and a knowledge graph — backed by a 51-tool MCP server and CLI that plug Cursor, Claude Code, Windsurf, or any agent into your corpus. Your data lives in ~/DeepThink. No cloud, no upload, no lock-in.',
    primaryCta: { label: 'Download for macOS', href: REPO_RELEASES_LATEST_URL },
    secondaryCta: { label: 'Documentation', to: '/documentation' },
    stats: [
      { value: '51', label: 'MCP tools — any agent, no Claude required' },
      { value: '100%', label: 'on-device — BM25 + semantic, no cloud index' },
      { value: '3 surfaces', label: 'app · CLI · MCP server — one shared store' },
    ],
  },
  snapshot: {
    title: 'What DeepThink delivers',
    intro:
      'One tool for both halves of the job: a beautiful macOS workspace where you capture, organize, and think — and a production-grade MCP server and CLI that give any AI agent structured, searchable context from that same workspace.',
    badges: [
      'Native SwiftUI app',
      'Hybrid RAG (BM25 + semantic)',
      '51-tool MCP server',
      'Model-agnostic CLI',
      'On-device embeddings',
      'MIT licensed',
    ],
    pillars: [
      {
        title: 'Give every agent a persistent memory',
        description:
          'Connect deepthink-mcp once. Cursor, Claude Code, Windsurf, or VS Code Copilot call knowledge_context or smart_query instead of starting cold each session — no manual copy-paste, no disposable chat summaries.',
      },
      {
        title: 'Capture once, retrieve everywhere',
        description:
          'URLs, files, Obsidian vaults, RSS feeds, and clipboard clips land in ~/DeepThink and are instantly indexed. The same corpus powers in-app search, the CLI, and every MCP-connected agent.',
      },
      {
        title: 'A workspace that actually thinks with you',
        description:
          'Projects, notes with wiki backlinks, Kanban tasks, reminders, and a force-directed context graph — all managed from a native macOS app with Claude-powered AI chat, custom agents, and slash-command skills.',
      },
    ],
  },
  whyLocalFirst: {
    title: 'Why local-first matters',
    subtitle:
      'Your knowledge base is not a SaaS dashboard. It is a file on your disk that you can diff, encrypt, and sync however you like. DeepThink keeps it that way.',
    points: [
      {
        title: 'You own the data',
        body: 'Open ~/DeepThink in Finder, diff it, back it up, or sync it with your existing tools. Nothing leaves your machine unless you choose.',
      },
      {
        title: 'Fast retrieval, always',
        body: 'BM25 and Apple NLEmbedding indexes live next to your documents. Search stays instant even when upstream APIs are slow or rate-limited.',
      },
      {
        title: 'One store, every surface',
        body: 'The macOS app, MCP server, and CLI all read and write the same ~/DeepThink workspace — no drift between your GUI and terminal workflows.',
      },
    ],
  },
  sections: {
    capabilities: {
      title: 'Everything in one place',
      subtitle:
        'Workspace, knowledge, AI, and automation — local, connected, and queryable by any agent.',
    },
    appCliMcp: {
      title: 'App, CLI, and MCP',
      subtitle:
        'Use the interface that fits the moment. All three share the same on-disk workspace and hybrid index.',
    },
    workflow: {
      title: 'How context flows',
      subtitle:
        'Capture once, connect it through the graph, and retrieve it anywhere — app, terminal, or agent.',
    },
  },
  features: [
    {
      title: 'Hybrid RAG — on-device, instant',
      description:
        'BM25 keyword search and Apple NLEmbedding semantic vectors fused via Reciprocal Rank Fusion. Every search runs fully on-device — no cloud index, no latency, no quota limits.',
      icon: 'Search',
    },
    {
      title: 'Knowledge base & smart capture',
      description:
        'Ingest URLs, files, RSS feeds, Obsidian vaults, and clipboard clips in one flow. Entries are deduplicated, tagged, and structured into summaries and facts your agents can retrieve.',
      icon: 'Database',
    },
    {
      title: 'Context graph',
      description:
        'A force-directed graph that maps semantic relationships and wiki-link connections across all your notes, projects, and knowledge — so you discover what is related before you need to ask.',
      icon: 'Zap',
    },
    {
      title: 'AI agents, skills & rules',
      description:
        'Build custom agent personas with scoped knowledge and assigned slash commands. Rules auto-inject instructions into every Claude conversation — consistent tone and format without manual prompting.',
      icon: 'NotebookPen',
    },
    {
      title: '⌘K command palette & quick capture',
      description:
        'Jump to any note, project, task, or skill from anywhere in the app. Quick capture floats above every window so ideas land in your workspace before the moment passes.',
      icon: 'Command',
    },
    {
      title: 'Private by design',
      description:
        'Core data stays in ~/DeepThink. Cloud integrations are opt-in. The MCP server shares only what you explicitly expose, and the CLI writes go through a full audit log.',
      icon: 'ShieldCheck',
    },
  ],
  platformContext: [
    {
      title: 'Native macOS app',
      description:
        'Projects, notes, tasks, reminders, AI chat, custom agents, and a built-in terminal — all in a SwiftUI app that syncs live with CLI and MCP writes via Darwin notification.',
      points: [
        '⌘K command palette — jump anywhere instantly',
        'Claude-powered AI chat with workspace awareness',
        'Built-in terminal with AI log analysis',
      ],
    },
    {
      title: 'CLI — model-agnostic',
      description:
        'Every write is atomic: snapshot → trash → SQL mutation → audit log in one transaction. Works with any AI or shell workflow — Cursor, git hooks, cron jobs — Claude not required.',
      points: [
        'deepthink ask, note, task, search, context',
        'Shared SwiftData-backed workspace (WAL mode)',
        'Full audit log on every create / update / delete',
      ],
    },
    {
      title: 'MCP server — any agent',
      description:
        '51 tools across smart, workspace, knowledge, and config categories. Works with Claude Code, Cursor, Windsurf, VS Code Copilot, or any MCP-capable host. Claude is not required.',
      points: [
        '51 tools — smart_query, unified_search, workspace_*, knowledge_*',
        'readonly flag on every tool — safe reads vs. mutations',
        'All writes audited and synced to the app in real time',
      ],
    },
  ],
  productTour: {
    title: 'See DeepThink in action',
    subtitle:
      'From workspace and knowledge capture to AI agents and the built-in terminal — scroll through to see how the surfaces connect.',
    steps: [
      {
        title: 'Workspace',
        description:
          'Projects group your notes, tasks, and context. Kanban board with priorities, story points, and due dates. Every item is queryable through the MCP server and CLI — not just visible in the GUI.',
        image: '/images/workspace.png',
      },
      {
        title: 'Knowledge base',
        description:
          'Capture URLs, files, Obsidian vaults, and RSS feeds in one flow. Each entry is structured into summaries, facts, and entities — indexed with BM25 and semantic search so retrieval is precise whether you ask from the app, CLI, or an agent.',
        image: '/images/knowledge.png',
      },
      {
        title: 'Context graph',
        description:
          'A force-directed graph that maps semantic relationships and wiki-link connections across your entire workspace. Discover what is related before you need to ask — and let agents traverse the graph for richer context.',
        image: '/images/context-graph.png',
      },
      {
        title: 'AI assistant',
        description:
          'Streaming Claude with full workspace awareness, branch edits, and session compaction. Build custom agent personas with scoped knowledge, assign slash-command skills, and auto-inject rules so every conversation stays consistent.',
        image: '/images/ai-assistant.png',
      },
      {
        title: 'Integrations',
        description:
          'Manage MCP servers, custom agents, skills, and rules from one unified panel. Add a deepthink-mcp connection to Cursor, Claude Code, or Windsurf once — then every agent session starts with your full corpus already loaded.',
        image: '/images/integrations.png',
      },
      {
        title: 'Built-in terminal',
        description:
          'Multi-tab terminal with AI-powered output analysis. Run Claude, the deepthink CLI, and your shell tools side by side — all sharing the same workspace context and MCP integration.',
        image: '/images/terminal.png',
      },
    ],
  },
  workflow: [
    {
      step: '01',
      title: 'Capture with intention',
      description:
        'Bring URLs, files, vault imports, snippets, tasks, and reminders into ~/DeepThink through one ingestion flow. Everything lands in one indexed, searchable store.',
    },
    {
      step: '02',
      title: 'Connect through the graph',
      description:
        'Add wiki backlinks, browse semantic neighbors in the context graph, and organize into buckets and projects. Structure your corpus so retrieval finds the right context — not just the nearest keyword.',
    },
    {
      step: '03',
      title: 'Retrieve anywhere — app, CLI, or agent',
      description:
        'Hybrid search answers inside the app. The same corpus powers your terminal scripts and editor agents through the MCP server. Capture once, reuse everywhere.',
    },
  ],
  faqs: [
    {
      question: 'Does the MCP server require Claude?',
      answer:
        'No. deepthink-mcp works with any MCP-capable AI agent — Claude Code, Cursor, VS Code Copilot, Windsurf, Continue, or any host that speaks MCP over stdio. Only the in-app AI chat, agents, skills, and rules require the Claude CLI, because the app spawns Claude as a local subprocess.',
    },
    {
      question: 'Can the CLI or MCP server run without the app open?',
      answer:
        'Yes. Both deepthink and deepthink-mcp read and write ~/DeepThink directly over SQLite (WAL mode) — the app does not need to be running. When the app is open, CLI and MCP writes sync to it automatically via Darwin notification. Changes persist to disk either way.',
    },
    {
      question: 'What does "hybrid RAG" mean in practice?',
      answer:
        'When you or an agent calls knowledge_context or unified_search, DeepThink runs a BM25 keyword query and an Apple NLEmbedding semantic vector query in parallel, then fuses the ranked results with Reciprocal Rank Fusion. This catches exact-match terms BM25 is good at and conceptually related content semantic search surfaces — all fully on-device with no cloud index.',
    },
    {
      question: 'How do I import an Obsidian vault or files?',
      answer:
        'Open the Knowledge section in the app and use the importer — it supports vault folders, Markdown files, attachments, URLs, RSS feeds, clipboard captures, and scripted collectors. Everything lands in the same hybrid index the MCP and CLI query.',
    },
    {
      question: 'Does DeepThink require cloud sync?',
      answer:
        'No. Data and embeddings stay under ~/DeepThink unless you add your own sync solution. The core workflow does not depend on any hosted infrastructure.',
    },
    {
      question: 'What are agents, skills, and rules?',
      answer:
        'Agents are custom Claude personas with a scoped knowledge set and assigned skills. Skills are slash commands (/standup, /summarize, custom templates) that inject context before sending to Claude. Rules are always-on instructions — per-project tone, format, or constraints — auto-injected into every conversation without manual prompting.',
    },
    {
      question: 'How do I connect Cursor or Windsurf to DeepThink?',
      answer:
        'Point your MCP host at ~/.local/bin/deepthink-mcp (installed automatically on first app launch). In Cursor or VS Code, add a deepthink entry to your mcpServers config. In Claude Code, run: claude mcp add deepthink -- ~/.local/bin/deepthink-mcp. The editor then sees all 51 workspace tools.',
    },
    {
      question: 'Does DeepThink upload my notes or code?',
      answer:
        'No. Indexing only reads content you imported into ~/DeepThink on your machine. MCP shares only what configured tools explicitly expose. No telemetry, no account required for offline use.',
    },
    {
      question: 'What platform does DeepThink support?',
      answer:
        'DeepThink is a native SwiftUI app for macOS 14+. The MCP server and CLI are bundled with the app and share the same local workspace. There is no web or mobile version.',
    },
    {
      question: 'Is there a CLI without the app?',
      answer:
        'The CLI and MCP server are installed by the app on first launch to ~/.local/bin/. They operate independently — the app does not need to be running. You can use the CLI from cron, git hooks, CI, or any shell script without opening the GUI.',
    },
  ],
  finalCta: {
    title: 'Your workspace. Your agents. Your data.',
    subtitle:
      'Install via Homebrew and get the native macOS app, 51-tool MCP server, and model-agnostic CLI — all sharing one local knowledge base that any agent can query.',
    primaryLabel: 'Download latest release',
    secondaryLabel: 'Read the docs',
  },
}
