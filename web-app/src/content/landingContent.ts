import { REPO_RELEASES_LATEST_URL } from '../constants/repo'

export const landingContent = {
  hero: {
    badge: 'macOS 14+ · Open source · Local-first · Works with any AI agent',
    titleLead: 'Persistent context for',
    titleAccent: 'AI-assisted work.',
    subtitle:
      'DeepThink is a native macOS workspace for notes, tasks, projects, and knowledge-backed by a 51-tool MCP server and CLI. Connect Cursor, Claude Code, or Windsurf once; each session can draw on an indexed corpus under ~/DeepThink. On-device indexing. No required cloud account.',
    primaryCta: { label: 'Download for macOS', href: REPO_RELEASES_LATEST_URL },
    secondaryCta: { label: 'Documentation', to: '/documentation' },
    stats: [
      { value: '51', label: 'MCP tools for structured workspace access' },
      { value: '100%', label: 'on-device hybrid search (BM25 + semantic)' },
      { value: '3 surfaces', label: 'app · CLI · MCP - one ~/DeepThink store' },
    ],
  },
  snapshot: {
    title: 'What DeepThink provides',
    intro:
      'DeepThink combines a native workspace for capture and organization with agent-ready retrieval: the same indexed corpus is available in the app, terminal, and any MCP-connected editor.',
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
        title: 'Persistent agent context',
        description:
          'Connect deepthink-mcp once. Supported hosts can call smart_query or knowledge_context to load project notes, tasks, and decisions-without manual context assembly each session.',
      },
      {
        title: 'Capture once, retrieve everywhere',
        description:
          'URLs, files, Obsidian vaults, RSS feeds, and clipboard entries are stored under ~/DeepThink and indexed for search. The same corpus powers the app, CLI, scheduled jobs, and MCP tools.',
      },
      {
        title: 'Integrated macOS workspace',
        description:
          'Projects, wiki-linked notes, Kanban tasks, reminders, daily brief, and a context graph-plus Claude-powered chat, configurable agents, and slash-command skills.',
      },
    ],
  },
  personas: {
    title: 'Designed for AI-assisted workflows',
    subtitle:
      'Whether you work primarily in an MCP-enabled editor, manage a product solo, or maintain a local knowledge base-DeepThink keeps context durable and queryable.',
    items: [
      {
        title: 'Developers using Cursor, Claude Code, or Windsurf',
        description:
          'Agents access project notes, open tasks, and recorded decisions through MCP-reducing repeated context setup at the start of each session.',
      },
      {
        title: 'Knowledge workers and researchers',
        description:
          'Import articles and vaults, explore semantic relationships in the context graph, and run hybrid search or Deep Search for complex questions.',
      },
      {
        title: 'Solo founders and product managers',
        description:
          'Kanban with story points, native reminders, daily brief (⌘D), and slash skills such as /standup-all available to terminal and agent workflows.',
      },
      {
        title: 'Automation and privacy-focused teams',
        description:
          'Run the CLI from cron, git hooks, or CI. Data remains under ~/DeepThink on disk, with audit logging and trash snapshots when agents change your data.',
      },
    ],
  },
  agentShowcase: {
    title: 'Connect in three steps',
    subtitle:
      'Install the app, register the MCP server with your editor, and query workspace context from the CLI or any connected agent.',
    steps: [
      {
        label: 'Install',
        code: 'brew tap getlost01/deepthink && brew install --cask deepthink',
      },
      {
        label: 'Connect MCP',
        code: 'claude mcp add deepthink -- ~/.local/bin/deepthink-mcp',
      },
      {
        label: 'Query from anywhere',
        code: 'deepthink ask "what is blocked on the API project?"',
      },
    ],
    tools: [
      'smart_query - token-budgeted context retrieval',
      'unified_search - hybrid BM25 + semantic across workspace',
      'workspace_task_* - create, list, and update tasks',
      'knowledge_capture - ingest URLs and files into the index',
      'agent_* / skill_* / rule_* - manage AI configuration as files',
    ],
  },
  whyLocalFirst: {
    title: 'Why local-first matters',
    subtitle:
      'Your knowledge base is a directory on disk-not a hosted dashboard. DeepThink is built to keep it that way.',
    points: [
      {
        title: 'You own the data',
        body: 'Open ~/DeepThink in Finder, version it, back it up, or sync it with your existing tools. Nothing leaves your machine unless you choose.',
      },
      {
        title: 'Consistent retrieval',
        body: 'BM25 and Apple NLEmbedding indexes live alongside your documents, so search stays responsive even when external APIs are slow or unavailable.',
      },
      {
        title: 'One store, every surface',
        body: 'The macOS app, MCP server, and CLI read and write the same ~/DeepThink workspace-no drift between GUI and terminal workflows.',
      },
    ],
  },
  sections: {
    capabilities: {
      title: 'Capabilities at a glance',
      subtitle:
        'Hybrid search, structured capture, task management, and agent governance-local, connected, and accessible from any MCP host.',
    },
    appCliMcp: {
      title: 'App, CLI, and MCP',
      subtitle:
        'Use the interface that fits the workflow. All three share the same on-disk workspace and hybrid index.',
    },
    workflow: {
      title: 'How context flows',
      subtitle:
        'Capture once, connect entries through the graph, and retrieve them from the app, terminal, or an agent.',
    },
  },
  features: [
    {
      title: 'Hybrid RAG - on-device',
      description:
        'BM25 keyword search and Apple NLEmbedding semantic vectors fused with Reciprocal Rank Fusion. Indexing and search run on your Mac-no cloud index required.',
      icon: 'Search',
    },
    {
      title: 'Knowledge base and capture',
      description:
        'Ingest URLs, files, RSS feeds, Obsidian vaults, and clipboard content in one flow. Collectors keep sources current; entries are deduplicated, tagged, and indexed for retrieval.',
      icon: 'Database',
    },
    {
      title: 'Context graph',
      description:
        'A force-directed view of semantic relationships and wiki-link connections across notes, projects, and knowledge-useful for discovery before you search or query.',
      icon: 'Zap',
    },
    {
      title: 'Workspace - projects, notes, tasks',
      description:
        'Kanban with priorities, story points, and due dates. TipTap markdown with wiki backlinks and version history. Items are queryable through MCP and the CLI.',
      icon: 'ListTodo',
    },
    {
      title: 'AI agents, skills, and rules',
      description:
        'Agent personas with scoped knowledge and assigned slash commands. Rules inject consistent instructions into Claude conversations without repeating prompts manually.',
      icon: 'NotebookPen',
    },
    {
      title: 'Reminders and daily brief',
      description:
        'Reminders with native macOS notifications and filters (Today, This Week, and more). Press ⌘D for an AI-generated summary of recent workspace activity.',
      icon: 'Calendar',
    },
    {
      title: '⌘K command palette and quick capture',
      description:
        'Navigate to any note, project, task, or skill from anywhere in the app. Quick capture records notes, knowledge entries, or tasks without leaving your current view.',
      icon: 'Command',
    },
    {
      title: 'Built-in terminal',
      description:
        'Multi-tab SwiftTerm sessions with AI-assisted output analysis. Run Claude, the deepthink CLI, and shell tools in one place, with shared workspace context.',
      icon: 'Terminal',
    },
    {
      title: 'Private by design',
      description:
        'Core data stays in ~/DeepThink. Cloud integrations are opt-in. MCP exposes only what configured tools request. CLI writes are logged and snapshotted.',
      icon: 'ShieldCheck',
    },
  ],
  platformContext: [
    {
      title: 'Native macOS app',
      description:
        'Projects, notes, tasks, reminders, AI chat, agents, context graph, and terminal-SwiftUI with live sync when the CLI or MCP updates the store.',
      points: [
        '⌘K command palette for fast navigation',
        'Claude-powered AI chat with workspace context',
        'Daily brief (⌘D) and Obsidian vault import',
      ],
    },
    {
      title: 'CLI - model-agnostic',
      description:
        'Writes are atomic: snapshot, trash, SQL mutation, and audit log in one transaction. Suitable for shell scripts, git hooks, cron, and CI-Claude is not required.',
      points: [
        'deepthink ask, run, react, research, schedule',
        'Shared SwiftData-backed workspace (WAL mode)',
        'Audit log on every create, update, and delete',
      ],
    },
    {
      title: 'MCP server - any compatible host',
      description:
        '51 tools across smart, workspace, knowledge, and config namespaces. Works with Claude Code, Cursor, Windsurf, VS Code Copilot, and other MCP-capable clients.',
      points: [
        'smart_query, unified_search, workspace_*, knowledge_*',
        'Some tools only search; others create or edit tasks, notes, and knowledge',
        'Writes audited and synced to the app when it is open',
      ],
    },
  ],
  productTour: {
    title: 'Product overview',
    subtitle:
      'Workspace, knowledge capture, agents, and terminal-how the main surfaces connect in a single local store.',
    steps: [
      {
        title: 'Workspace',
        description:
          'Projects group notes, tasks, and context. Kanban supports priorities, story points, and due dates. Items are available to MCP and CLI queries-not only in the UI.',
        image: '/images/workspace.png',
      },
      {
        title: 'Knowledge base',
        description:
          'Capture URLs, files, Obsidian vaults, and RSS feeds. Entries are structured and indexed with BM25 and semantic search for use in the app, CLI, or agents.',
        image: '/images/knowledge.png',
      },
      {
        title: 'Context graph',
        description:
          'Maps semantic relationships and wiki links across the corpus-useful for exploration and for agents that traverse related material.',
        image: '/images/context-graph.png',
      },
      {
        title: 'AI assistant',
        description:
          'Streaming Claude with workspace context, edit branching, and session compaction. Configure agents, skills, and rules for repeatable conversation patterns.',
        image: '/images/ai-assistant.png',
      },
      {
        title: 'Integrations',
        description:
          'Manage MCP servers, agents, skills, and rules in one panel. Add deepthink-mcp to your editor so sessions can use the indexed workspace.',
        image: '/images/integrations.png',
      },
      {
        title: 'Reminders',
        description:
          'Timed reminders with native notifications and calendar-style filters. Tasks remain in sync between the app and agent-facing tools.',
        image: '/images/reminders.png',
      },
      {
        title: 'Built-in terminal',
        description:
          'Multi-tab terminal with AI-assisted analysis of output. Run Claude, deepthink, and shell commands alongside the same workspace data.',
        image: '/images/terminal.png',
      },
    ],
  },
  workflow: [
    {
      step: '01',
      title: 'Capture deliberately',
      description:
        'Add URLs, files, vault imports, snippets, tasks, and reminders into ~/DeepThink through a single ingestion path. Everything is indexed in one store.',
    },
    {
      step: '02',
      title: 'Structure and connect',
      description:
        'Use wiki backlinks, the context graph, and project buckets so retrieval surfaces the right material-not only the closest keyword match.',
    },
    {
      step: '03',
      title: 'Retrieve from app, CLI, or agent',
      description:
        'Search in the app; script against the CLI; query through MCP from your editor. One corpus, multiple interfaces.',
    },
  ],
  faqs: [
    {
      question: 'Does the MCP server require Claude?',
      answer:
        'No. deepthink-mcp works with any MCP-capable client-Claude Code, Cursor, VS Code Copilot, Windsurf, Continue, or other stdio hosts. In-app AI chat, agents, skills, and rules use the Claude CLI because the app invokes Claude as a local subprocess.',
    },
    {
      question: 'Can the CLI or MCP server run without the app open?',
      answer:
        'Yes. Both deepthink and deepthink-mcp read and write ~/DeepThink over SQLite (WAL mode). When the app is running, disk changes sync via Darwin notification; persistence does not depend on the GUI being open.',
    },
    {
      question: 'What does "hybrid RAG" mean in practice?',
      answer:
        'Calls such as knowledge_context or unified_search run BM25 keyword search and Apple NLEmbedding semantic search in parallel, then fuse rankings with Reciprocal Rank Fusion-on-device, without a cloud index.',
    },
    {
      question: 'How do I import an Obsidian vault or files?',
      answer:
        'Use the Knowledge section importer for vault folders, Markdown, attachments, URLs, RSS, clipboard captures, and scripted collectors. Imported material shares the same index as MCP and CLI queries.',
    },
    {
      question: 'Does DeepThink require cloud sync?',
      answer:
        'No. Data and embeddings remain under ~/DeepThink unless you add your own sync. The default workflow does not require hosted infrastructure.',
    },
    {
      question: 'What are agents, skills, and rules?',
      answer:
        'Agents are Claude personas with scoped knowledge and assigned skills. Skills are slash commands (/standup, /summarize, custom templates) that inject context before a prompt. Rules are standing instructions-tone, format, or constraints-applied automatically per project or globally.',
    },
    {
      question: 'How do I connect Cursor or Windsurf to DeepThink?',
      answer:
        'Point your MCP host at ~/.local/bin/deepthink-mcp (installed on first app launch). In Cursor or VS Code, add a deepthink entry under mcpServers. For Claude Code: claude mcp add deepthink -- ~/.local/bin/deepthink-mcp.',
    },
    {
      question: 'Does DeepThink upload my notes or code?',
      answer:
        'No. Indexing uses content you store under ~/DeepThink on your machine. MCP exposes only what configured tools request. No account is required for offline use.',
    },
    {
      question: 'What platform does DeepThink support?',
      answer:
        'DeepThink is a native SwiftUI application for macOS 14+. The MCP server and CLI ship with the app and use the same local workspace. There is no web or mobile client.',
    },
    {
      question: 'Is there a CLI without the app?',
      answer:
        'The CLI and MCP binaries are installed to ~/.local/bin/ on first launch and operate independently of the GUI. You can use them from cron, git hooks, or CI without opening the app.',
    },
  ],
  finalCta: {
    title: 'Install DeepThink for macOS',
    subtitle:
      'Homebrew install includes the native app, 51-tool MCP server, and model-agnostic CLI-sharing one local knowledge base across interfaces.',
    primaryLabel: 'Download latest release',
    secondaryLabel: 'Read the docs',
  },
}
