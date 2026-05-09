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
      { value: 'CLI + MCP', label: 'same SwiftData workspace as the app' },
      { value: 'Hybrid', label: 'keyword + semantic retrieval' },
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
        'Bundled binaries connect to the live SwiftData workspace so agents and shell scripts can search, append, and report without a second database.',
      icon: 'NotebookPen',
    },
    {
      title: 'Hybrid context engine',
      description:
        'BM25 and embeddings surface phrases and semantic matches so answers rely on archived passages instead of generic AI filler.',
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
        '~/DeepThink is the source of truth interface with ingestion, backlinks, reminders, embedding jobs, graph views, and a terminal tab sharing the same state.',
      points: [
        'SwiftUI on macOS 14+',
        'Hybrid search previews before agents run',
        'Built in terminal with AI focused log review',
      ],
    },
    {
      title: 'CLI workflow',
      description:
        'Build automations that stay aligned with the GUI: query the workspace, export context packs, and chain shell tools without fragile exports.',
      points: [
        'Shared SwiftData backed workspace',
        'Scriptable stdin/stdout',
        'Cron and CI compatible',
      ],
    },
    {
      title: 'MCP integration',
      description:
        'Connect Cursor, Claude Desktop, or any MCP host to curated tools and resources so assistants operate on snippets you intentionally exposed.',
      points: [
        'deepthink-mcp exposes workspace tools',
        'Optional /deepthink command in Claude Code',
        'Agent defaults inherit MCP tooling in app',
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
        'Yes. Install the bundled deepthink CLI to script against the SwiftData backed workspace and pair it with git hooks or server side jobs while staying local first.',
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
