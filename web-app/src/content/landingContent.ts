import { REPO_RELEASES_LATEST_URL } from '../constants/repo'

export const landingContent = {
  hero: {
    badge: 'macOS 14+ · Open source · Local-first · Bundled CLI & MCP',
    title:
      'Connected Workspace and Knowledge Base for AI Agents with Hybrid RAG and Native CLI + MCP Support',
    subtitle:
      'DeepThink keeps your corpus in ~/DeepThink: indexed notes, captures, imports, and linked knowledge. Hybrid retrieval (BM25 + semantic search) powers Claude. The bundled deepthink CLI and MCP server use that same store with no duplicate wiki or hidden uploads.',
    primaryCta: { label: 'Download for macOS', href: REPO_RELEASES_LATEST_URL },
    secondaryCta: { label: 'Documentation', to: '/documentation' },
    stats: [
      { value: '100%', label: 'your vault stays on disk' },
      { value: 'CLI + MCP', label: 'MCP server — same workspace as the app' },
      { value: 'BM25 + RRF', label: 'keyword + semantic hybrid retrieval' },
    ],
  },
  snapshot: {
    title: 'What DeepThink delivers',
    intro:
      'A native macOS workspace for owning context: capture and connect material, inspect relationships through the graph, and run hybrid retrieval grounded in what you saved. Agents in Cursor or the terminal reuse that knowledge through MCP and the CLI instead of rebuilding summaries in disposable chats.',
    badges: [
      'Bundled deepthink CLI',
      'deepthink-mcp tools',
      'Hybrid RAG pipeline',
      'SwiftUI + SwiftData',
      'MIT licensed',
    ],
    pillars: [
      {
        title: 'Wire agents to your corpus',
        description:
          'MCP exposes tools under your control so editors pull specs, bookmarks, and notes from ~/DeepThink with explicit wiring, not a SaaS scraping your repo.',
      },
      {
        title: 'Script and automate the same brain',
        description:
          'The CLI speaks to the live workspace for search, capture, and jobs: cron, git hooks, and headless workflows without exporting a second copy of your notes.',
      },
      {
        title: 'Browse and curate locally',
        description:
          'The SwiftUI app is where you ingest, organize, and preview context so what agents retrieve stays aligned with what you see on disk.',
      },
    ],
  },
  whyLocalFirst: {
    title: 'Why local first matters',
    subtitle:
      'We do not run a cloud vault for your knowledge. The source of truth stays in your files and SwiftData beside them. You control when anything leaves your machine because MCP only connects when you enable it.',
    points: [
      {
        title: 'Ownership you can verify',
        body:
          'Open ~/DeepThink, diff it, encrypt it, or sync it with tools you already trust instead of handing your graph to another vendor.',
      },
      {
        title: 'Retrieval without extra latency',
        body:
          'Indexes stay beside your documents so assistants remain responsive even when upstream APIs slow down or quotas hit.',
      },
      {
        title: 'One workspace with consistent surfaces',
        body:
          'The GUI, MCP tools, and CLI all operate on the same workspace with no drift between dashboards and terminal workflows.',
      },
    ],
  },
  sections: {
    capabilities: {
      title: 'Core capabilities',
      subtitle:
        'Everything below stays local and feeds the retrieval stack powering Claude, MCP, and the CLI.',
    },
    appCliMcp: {
      title: 'App, CLI, and MCP',
      subtitle:
        'Use the interface that fits the moment. All three share the same on disk workspace and hybrid index.',
    },
    workflow: {
      title: 'How context flows',
      subtitle:
        'Capture material once, reconnect it through the graph, then let retrieval respond through tools you already use.',
    },
  },
  features: [
    {
      title: 'CLI & MCP on your workspace',
      description:
        'Bundled binaries share the live SwiftData workspace. All 45 MCP tools carry a readonly flag so agents can distinguish safe reads from state-changing writes.',
      icon: 'NotebookPen',
    },
    {
      title: 'Hybrid RAG — BM25 + semantic + RRF',
      description:
        'BM25 (k1=1.5, b=0.75) and Apple NLEmbedding vectors fused via RRF (K=60). Query embedding cached 5 min. Archive entries excluded by default. Threshold 0.1 / 0.3.',
      icon: 'Search',
    },
    {
      title: 'Knowledge ingestion',
      description:
        'URLs, files, RSS feeds, clipboard captures, and Obsidian vaults sit beside notes in one searchable index the MCP and CLI can query.',
      icon: 'Database',
    },
    {
      title: 'Workspace + graph',
      description:
        'Projects, markdown, tasks, backlinks, reminders, and the context graph stay unified in one interface tied to ~/DeepThink.',
      icon: 'Zap',
    },
    {
      title: 'Command palette & capture',
      description:
        '⌘K moves across every surface while quick capture saves snippets before retrieval workflows miss them.',
      icon: 'Command',
    },
    {
      title: 'Private by design',
      description:
        'Core data stays inside your user folder. Cloud integrations are optional and we do not host your corpus.',
      icon: 'ShieldCheck',
    },
  ],
  platformContext: [
    {
      title: 'Native app',
      description:
        '~/DeepThink is the source of truth. CLI writes sync live via Darwin notification → CLISyncService → AppState so the UI always reflects the latest state.',
      points: [
        'SwiftUI on macOS 14+',
        'Live sync from CLI/MCP writes via Darwin notification',
        'Built-in terminal with AI-focused log review',
      ],
    },
    {
      title: 'CLI workflow',
      description:
        'Every CLI write is atomic: snapshot → dt_trash → SQL mutation → dt_audit_log in one transaction. notifyutil fires after commit to sync the app.',
      points: [
        'Shared SwiftData-backed workspace (WAL mode)',
        'Atomic deletes with full row snapshot in dt_trash',
        'Audit log on every create / update / delete',
      ],
    },
    {
      title: 'MCP integration',
      description:
        '45 tools across smart, workspace, knowledge, and config categories. Read-only tools carry readonly: true so MCP clients can enforce safe-read boundaries.',
      points: [
        '45 MCP tools — smart_query, unified_search, workspace_*, knowledge_*',
        'readonly flag distinguishes reads from mutations',
        'All writes go through audit log + Darwin sync',
      ],
    },
  ],
  productTour: {
    title: 'How context flows through DeepThink',
    subtitle:
      'Capture context, connect it with the graph, and retrieve it anywhere — assistant, MCP, or terminal.',
    steps: [
      {
        title: 'Workspace',
        description:
          'Projects, tasks, and notes live together with shared progress tracking across the GUI, MCP, and CLI.',
        image: '/images/workspace.png',
      },
      {
        title: 'Knowledge',
        description:
          'Chats, imports, and clippings are structured into searchable summaries, facts, and entities.',
        image: '/images/knowledge.png',
      },
      {
        title: 'Context graph',
        description:
          'Link chats, notes, and projects through semantic relationships for smarter context retrieval.',
        image: '/images/context-graph.png',
      },
      {
        title: 'AI assistant',
        description:
          'Resume threads, use MCP tools, and access live workspace context directly from the assistant.',
        image: '/images/ai-assistant.png',
      },
      {
        title: 'Integrations',
        description:
          'Manage MCP servers, skills, assistants, and rules from one unified integration panel.',
        image: '/images/integrations.png',
      },
      {
        title: 'Terminal',
        description:
          'Run Claude, DeepThink, and shell tools with the same shared context and MCP integration.',
        image: '/images/terminal.png',
      },
    ],
  },
  workflow: [
    {
      step: '01',
      title: 'Capture with intention',
      description:
        'Bring URLs, files, drafts, snippets, reminders, todos, and backlinks into ~/DeepThink through one ingestion flow.',
    },
    {
      step: '02',
      title: 'Connect the graph',
      description:
        'Organize buckets, backlinks, and semantic neighbors so retrieval relies on structure instead of disconnected PDFs.',
    },
    {
      step: '03',
      title: 'Reuse through CLI and MCP',
      description:
        'Hybrid retrieval answers inside the app while the same corpus powers terminal scripts and editor agents through enabled MCP tooling.',
    },
  ],
  faqs: [
    {
      question: 'Does the MCP server require Claude?',
      answer:
        'No. deepthink-mcp works with any MCP-capable AI agent — Claude Code, Cursor, VS Code Copilot, Windsurf, Continue, or any host that speaks MCP over stdio. The MCP server is model-agnostic. Only the in-app AI chat (agents, skills, rules) requires the Claude CLI, because the app spawns Claude as a local subprocess for conversational AI.',
    },
    {
      question: 'Can the CLI or MCP server run without the app open?',
      answer:
        'Yes. Both deepthink and deepthink-mcp read and write ~/DeepThink directly over SQLite (WAL mode) and the knowledge filesystem — the app does not need to be running. When the app is open, CLI and MCP writes automatically sync to it via a Darwin notification so the UI stays current. When it is closed, changes persist to disk and appear the next time the app launches.',
    },
    {
      question: 'What platform does DeepThink support?',
      answer:
        'DeepThink is a native SwiftUI app for macOS 14+. The MCP server and CLI ship alongside the app and target the same local workspace.',
    },
    {
      question: 'Does DeepThink require cloud sync?',
      answer:
        'No. Data and embeddings stay under ~/DeepThink unless you choose your own sync solution. The core workflow does not depend on hosted infrastructure.',
    },
    {
      question: 'Can I use DeepThink from terminal tools?',
      answer:
        'Yes. The bundled deepthink CLI is model-agnostic — it reads and writes the same workspace regardless of which AI you use. Pair it with git hooks, cron jobs, or any shell automation.',
    },
    {
      question: 'Does DeepThink upload my codebase to external servers?',
      answer:
        'No. Indexing only reads content you imported into ~/DeepThink on your machine. MCP shares only what configured tools explicitly expose.',
    },
    {
      question: 'What is the `/deepthink` command?',
      answer:
        'Inside DeepThink, agents already inherit the MCP toolset while MCP stays enabled by default. In Claude Code, you can optionally install ~/.claude/commands/deepthink.md so /deepthink routes requests to the same MCP tools.',
    },
    {
      question: 'How can I import an Obsidian vault or files?',
      answer:
        'The importer supports vault folders, Markdown, attachments, URLs, feeds, clipboard captures, folders, and scripted collectors inside one unified hybrid index.',
    },
    {
      question: 'Is telemetry or a DeepThink account required?',
      answer:
        'No subscription is required for offline use, and there is no obligation to route your corpus through our infrastructure.',
    },
    {
      question: 'How do I connect Cursor or Claude Desktop to DeepThink?',
      answer:
        'Point the MCP host at the bundled deepthink-mcp binary in your DeepThink install. Once registered, the editor sees the same workspace tools the app uses, and you decide which tools stay enabled per project.',
    },
  ],
  finalCta: {
    title: 'Keep context where MCP and the CLI can reuse it.',
    subtitle:
      'Download the macOS app to access the bundled toolchain, then connect editors and terminal workflows to ~/DeepThink without giving up ownership.',
    primaryLabel: 'Download latest release',
    secondaryLabel: 'Open documentation',
  },
}
