import { REPO_RELEASES_LATEST_URL } from '../constants/repo'

export const landingContent = {
  hero: {
    badge: 'macOS 14+ • Open source • Local-first',
    title:
      'One workspace for grounded knowledge and an AI that stays informed.',
    subtitle:
      'DeepThink unifies projects, notes, tasks, and knowledge under ~/DeepThink. Hybrid retrieval (BM25 + semantics) feeds Claude; one indexed store powers the CLI and MCP as a single source of truth.',
    primaryCta: { label: 'Download for macOS', href: REPO_RELEASES_LATEST_URL },
    secondaryCta: { label: 'Documentation', to: '/documentation' },
    stats: [
      { value: '100%', label: 'your data, your disk' },
      { value: '⌘K', label: 'jump to any surface fast' },
      { value: 'Hybrid', label: 'keyword + meaning for retrieval' },
    ],
  },
  snapshot: {
    title: 'What DeepThink is',
    intro:
      'SwiftUI workspace built for compound context: one store for notes and imports, a graph for links, retrieval that cites evidence in chat. SwiftData under ~/DeepThink; Claude uses hybrid search so answers reference what you saved.',
    badges: [
      'SwiftUI native',
      'Claude integrated',
      'MCP ready',
      'MIT licensed',
    ],
    pillars: [
      {
        title: 'Think in the app',
        description:
          'Markdown, Kanban, reminders, ingest, graph, and terminal together so daily work and long-term memory stay in one place.',
      },
      {
        title: 'Script against the same brain',
        description:
          'The deepthink CLI uses the same store: automate capture, search, and reporting without a second database.',
      },
      {
        title: 'Give editors real context',
        description:
          'MCP exposes tools so Cursor and others use your workspace with consent, not silent upload.',
      },
    ],
  },
  whyLocalFirst: {
    title: 'Why local-first matters',
    subtitle:
      'Ground truth lives where you can inspect and back it up. Local indexes cut latency; MCP connects when you choose, not by default.',
    points: [
      {
        title: 'Custody you can verify',
        body: 'Predictable paths under your user folder: snapshot, sync with tools you trust, audit when compliance matters.',
      },
      {
        title: 'Retrieval without the round-trip tax',
        body: 'Indexes live beside files; hybrid search stays responsive when the network flakes.',
      },
      {
        title: 'One store, many surfaces',
        body: 'Automations and MCP hit one SwiftData workspace so nothing drifts from what the app shows.',
      },
    ],
  },
  features: [
    {
      title: 'Unified workspace',
      description:
        'Projects, notes, tasks, and reminders share one chrome so you stop re-explaining state across tabs.',
      icon: 'Zap',
    },
    {
      title: 'Command palette & capture',
      description:
        '⌘K jumps anywhere; quick capture stops ideas from slipping away before they become linked notes.',
      icon: 'Command',
    },
    {
      title: 'Knowledge ingestion',
      description:
        'URLs, files, RSS, clipboard, and Obsidian vaults land in the same index your assistant searches.',
      icon: 'Database',
    },
    {
      title: 'Hybrid context engine',
      description:
        'BM25 plus semantics surface exact phrases and paraphrases so RAG favors evidence over generic chunks.',
      icon: 'Search',
    },
    {
      title: 'Terminal + CLI',
      description:
        'Run commands beside AI-reviewed output; script the workspace with the deepthink CLI and MCP.',
      icon: 'NotebookPen',
    },
    {
      title: 'Private by default',
      description:
        'Core data stays under ~/DeepThink. Cloud tools are optional, not the default.',
      icon: 'ShieldCheck',
    },
  ],
  platformContext: [
    {
      title: 'Native app',
      description:
        'macOS surface where context grows: notes, graph, tasks, and terminal in one local-first layout.',
      points: [
        'macOS 14+ SwiftUI UI',
        'Command palette + capture',
        'Terminal with AI-friendly output review',
      ],
    },
    {
      title: 'CLI workflow',
      description:
        'Query and automate the live workspace: cron, hooks, and terminal-heavy days without Markdown export dumps.',
      points: [
        'Search & mutate the same store',
        'Automation-friendly I/O',
        'No second “shadow” database',
      ],
    },
    {
      title: 'MCP integration',
      description:
        'Expose tools to editors so agents read specs and notes under permissions you set.',
      points: [
        'Tools + resources over MCP',
        'Agent-friendly',
        'Knowledge flows to the IDE on your terms',
      ],
    },
  ],
  productTour: {
    title: 'How context moves through DeepThink',
    subtitle:
      'Scroll the tour: each card is capture, structure, connect, and retrieve.',
    steps: [
      {
        title: 'Workspace',
        description:
          'One layout for projects, writing, and execution so status and story stay together.',
        image: '/images/workspace.png',
      },
      {
        title: 'Knowledge',
        description:
          'Keep reference material next to decisions and debugging notes from the same imports.',
        image: '/images/knowledge.png',
      },
      {
        title: 'Context graph',
        description:
          'Backlinks and semantic neighbors show how ideas relate across your notes.',
        image: '/images/context-graph.png',
      },
      {
        title: 'AI assistant',
        description:
          'Claude with hybrid RAG: answers from retrieved passages you stored, not generic filler.',
        image: '/images/ai-assistant.png',
      },
      {
        title: 'Integrations',
        description:
          'MCP, CLI, and imports share one index; agents inherit what you curated in the UI.',
        image: '/images/integrations.png',
      },
      {
        title: 'Terminal',
        description:
          'Keep shell output in view and tie runs to notes without tab-hopping.',
        image: '/images/terminal.png',
      },
    ],
  },
  workflow: [
    {
      step: '01',
      title: 'Capture with intent',
      description:
        'Notes, tasks, links, and imports land in one store, ready to index.',
    },
    {
      step: '02',
      title: 'Structure & link',
      description:
        'Folders, backlinks, and graph turn isolated facts into retriever-friendly context.',
    },
    {
      step: '03',
      title: 'Ask with full grounding',
      description:
        'Hybrid search feeds Claude and agents; answers trace back to files you own.',
    },
  ],
  faqs: [
    {
      question: 'What platform does DeepThink support?',
      answer:
        'macOS 14+ native SwiftUI, tuned for Apple silicon and desktop-scale context work.',
    },
    {
      question: 'Does DeepThink require cloud sync to work?',
      answer:
        'No. Data and indexes live under ~/DeepThink. Add your own sync or backup on top.',
    },
    {
      question: 'Can I use DeepThink from terminal tools too?',
      answer:
        'Yes. The CLI and MCP share the app’s SwiftData workspace with scripts and editors.',
    },
    {
      question: 'Which AI model is integrated?',
      answer:
        'Claude via the CLI with workspace retrieval: prompts include chunks from your index, not only the open buffer.',
    },
    {
      question: 'How do I bring in an Obsidian vault or files?',
      answer:
        'Import vaults, URLs, RSS, and files in-app; everything enters the same hybrid index.',
    },
    {
      question: 'Is there telemetry or a required cloud account?',
      answer:
        'No vendor account required for core use. Data stays local unless you connect services yourself.',
    },
  ],
  finalCta: {
    title: 'Keep knowledge that compounds. Skip chat threads that evaporate.',
    subtitle:
      'Grab the macOS build or open the docs to hook up CLI, MCP, and imports against the same workspace.',
    primaryLabel: 'Download latest release',
    secondaryLabel: 'Open documentation',
  },
}
