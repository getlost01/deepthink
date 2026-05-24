export const architectureContent = {
  hero: {
    title: 'How DeepThink fits together',
    subtitle:
      'Three surfaces share one local store under ~/DeepThink/. MCP and CLI are agent-agnostic; in-app AI chat uses the Claude CLI as a local subprocess.',
    stats: [
      { value: '3', label: 'surfaces - app, CLI, MCP' },
      { value: '51', label: 'MCP tools - search or edit' },
      { value: '1', label: 'shared ~/DeepThink store' },
    ],
  },
  surfaces: [
    {
      title: 'macOS app',
      accent: 'violet',
      description:
        'SwiftUI workspace for projects, notes, tasks, knowledge, AI chat, and terminal. Indexes embeddings on launch and syncs when the CLI or MCP changes data on disk.',
      points: ['26 services', 'Context graph', 'Darwin sync listener'],
    },
    {
      title: 'deepthink CLI',
      accent: 'emerald',
      description:
        'Model-agnostic terminal access to the same SQLite store. Atomic writes with audit log and trash snapshots. Works from cron, git hooks, or CI.',
      points: ['13 agents', 'WAL SQLite', 'No Claude required'],
    },
    {
      title: 'deepthink-mcp',
      accent: 'teal',
      description:
        '51 stdio tools for Cursor, Claude Code, Windsurf, VS Code Copilot, or any MCP host. Some only search your workspace; others create or edit tasks, notes, and knowledge. Every change is audited and synced to the app.',
      points: ['smart_query', 'workspace_*', 'knowledge_*'],
    },
  ],
  dataLayer: {
    title: 'What lives on disk',
    subtitle:
      'Everything under ~/DeepThink/ - local-first, no cloud backend required.',
    items: [
      {
        path: 'data/deepthink.store',
        description:
          'SwiftData SQLite (WAL). Tasks, notes, projects, reminders, dt_audit_log, dt_trash.',
      },
      {
        path: 'data/vectors.db',
        description:
          'Float32 embeddings, chunks table, pending_reindex queue. Shared by app and CLI.',
      },
      {
        path: 'knowledge/**/*.md',
        description:
          'Markdown with YAML frontmatter. Projects, integrations, archive excluded from RAG.',
      },
      {
        path: '.claude/',
        description:
          'Agents, rules, skills, and slash commands as files. Installed on first launch.',
      },
    ],
  },
  governance: {
    title: 'Safe agent writes',
    items: [
      {
        title: 'Audit log',
        body: 'Every CLI and MCP change is recorded in dt_audit_log with operation, entity, and timestamp.',
      },
      {
        title: 'Trash snapshots',
        body: 'Hard deletes snapshot the full row to dt_trash before removal so agents can recover mistakes.',
      },
      {
        title: 'Search-only tools',
        body: 'Tools that list or search never change your data. Tools that create, update, or delete do - and every change is logged.',
      },
    ],
  },
  rag: {
    title: 'Hybrid retrieval pipeline',
    subtitle:
      'BM25 keyword search and Apple NLEmbedding semantic vectors fused with Reciprocal Rank Fusion - fully on-device.',
    steps: [
      { label: 'Tokenize', detail: 'Stopwords, stemming, archive excluded' },
      { label: 'BM25', detail: 'Keyword scoring with title and tag boosts' },
      { label: 'Semantic', detail: 'NLEmbedding cosine similarity, top-k 20' },
      { label: 'RRF', detail: 'Fused ranks, ~4k token budget for agents' },
    ],
  },
  diagram: {
    title: 'Interactive system diagram',
    hint: 'Pan and zoom to explore. Color legend is at the top of the canvas. Orange dashed lines show Darwin sync back to the app.',
  },
}
