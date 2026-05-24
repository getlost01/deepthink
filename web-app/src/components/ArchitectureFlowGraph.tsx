import { useEffect, useMemo, useState } from 'react'
import {
  Background,
  BackgroundVariant,
  Controls,
  Handle,
  MarkerType,
  MiniMap,
  Panel,
  Position,
  ReactFlow,
  useEdgesState,
  useNodesState,
  useReactFlow,
  type Edge,
  type Node,
  type NodeProps,
  type NodeTypes,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'

// ─── Mobile static flow ──────────────────────────────────────────────────────

function MobileFlow() {
  const interfaceCards = [
    {
      label: 'App',
      color: 'border-violet-400/50 bg-violet-500/10',
      text: 'text-violet-200',
      lines: ['SwiftUI · 26 services', 'NLEmbedding on launch'],
    },
    {
      label: 'CLI',
      color: 'border-emerald-400/50 bg-emerald-500/10',
      text: 'text-emerald-200',
      lines: ['Bun/TS · 13 agents', 'atomic tx · audit log'],
    },
    {
      label: 'MCP',
      color: 'border-teal-400/50 bg-teal-500/10',
      text: 'text-teal-200',
      lines: ['51 tools · any agent', 'Cursor · Claude Code · Windsurf'],
    },
  ]

  const storageRows = [
    {
      file: 'deepthink.store',
      desc: 'SQLite WAL · entities · dt_audit_log · dt_trash',
    },
    {
      file: 'vectors.db',
      desc: 'Float32 embeddings · pending_reindex queue',
    },
    {
      file: 'knowledge/**/*.md',
      desc: 'projects · integrations · archive excluded · FSEvents',
    },
    {
      file: '.claude/',
      desc: 'agents · rules · skills · commands',
    },
  ]

  const ragSteps = [
    {
      label: 'Tokenize',
      desc: 'lowercase · 150+ stopwords · Porter-lite stemmer',
    },
    {
      label: 'BM25',
      desc: 'k1=1.5 · b=0.75 · threshold >0.1 · archive excluded',
    },
    {
      label: 'Semantic',
      desc: 'NLEmbedding · cosine >0.3 · 5-min cache · top-k 20',
    },
    {
      label: 'RRF K=60',
      desc: 'chunksForEntryIds · window 800 chars · 4 000-token budget',
    },
  ]

  return (
    <div
      data-testid="architecture-mobile-flow"
      className="overflow-hidden rounded-2xl border border-white/10 bg-zinc-950 shadow-[0_24px_80px_-32px_rgba(124,58,237,0.25)]"
    >
      <div className="flex flex-col gap-0 px-3 py-4 text-[11px]">
        {/* AI clients banner */}
        <div className="mb-1.5 rounded-lg border border-sky-400/25 bg-sky-500/8 px-3 py-1.5">
          <div className="text-[9px] font-semibold text-sky-200">
            AI Agents → MCP (no Claude required)
          </div>
          <div className="mt-0.5 text-[9px] text-zinc-400">
            Claude Code · Cursor · Windsurf · VS Code Copilot · any MCP host
          </div>
        </div>

        {/* Row 1 - interfaces */}
        <div className="flex gap-2">
          {interfaceCards.map((c) => (
            <div
              key={c.label}
              className={`flex-1 rounded-xl border px-2 py-2 ${c.color}`}
            >
              <div className={`font-mono font-semibold ${c.text}`}>
                {c.label}
              </div>
              {c.lines.map((l) => (
                <div
                  key={l}
                  className="mt-0.5 text-[9px] text-zinc-400 leading-tight"
                >
                  {l}
                </div>
              ))}
            </div>
          ))}
        </div>

        {/* Arrow down */}
        <div className="flex flex-col items-center py-2.5">
          <div className="h-5 w-px bg-zinc-600" />
          <div className="rounded-full border border-zinc-700 bg-zinc-900 px-2 py-0.5 text-[9px] text-zinc-400">
            writes (atomic tx)
          </div>
          <div className="h-1 w-px bg-zinc-600" />
          <svg width="10" height="6" className="text-zinc-500">
            <path d="M5 6 L0 0 L10 0Z" fill="currentColor" />
          </svg>
        </div>

        {/* ~/DeepThink storage */}
        <div className="rounded-xl border-2 border-cyan-400/40 bg-zinc-900/80 px-3 py-2.5">
          <div className="font-mono text-[11px] font-semibold text-cyan-200">
            ~/DeepThink/
          </div>
          <div className="mt-2 grid grid-cols-2 gap-1.5">
            {storageRows.map((r) => (
              <div
                key={r.file}
                className="rounded-lg border border-white/5 bg-black/30 px-2 py-1.5"
              >
                <div className="font-mono text-[9px] text-cyan-100">
                  {r.file}
                </div>
                <div className="mt-0.5 text-[9px] text-zinc-500 leading-tight">
                  {r.desc}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Darwin sync */}
        <div className="mt-1.5 flex items-center gap-2 rounded-lg border border-orange-400/30 bg-orange-500/8 px-3 py-1.5">
          <span className="text-orange-300 text-[9px]">⟳</span>
          <div>
            <div className="text-[9px] font-semibold text-orange-200">
              Darwin sync → App
            </div>
            <div className="text-[9px] text-zinc-500">
              notifyutil · CLISyncService · externalSyncToken → @Query refresh
            </div>
          </div>
        </div>

        {/* Arrow down - RAG */}
        <div className="flex flex-col items-center py-2.5">
          <div className="h-5 w-px bg-zinc-600" />
          <div className="rounded-full border border-zinc-700 bg-zinc-900 px-2 py-0.5 text-[9px] text-zinc-400">
            hydrate chunks + entries
          </div>
          <div className="h-1 w-px bg-zinc-600" />
          <svg width="10" height="6" className="text-zinc-500">
            <path d="M5 6 L0 0 L10 0Z" fill="currentColor" />
          </svg>
        </div>

        {/* RAG pipeline */}
        <div className="rounded-xl border border-fuchsia-400/35 bg-zinc-900/80 px-3 py-2.5">
          <div className="font-mono text-[9px] uppercase tracking-wider text-fuchsia-300/80 text-center">
            Hybrid RAG - shared App · CLI · MCP
          </div>
          <div className="mt-2 flex flex-col gap-1.5">
            {ragSteps.map((s) => (
              <div
                key={s.label}
                className="flex gap-2 rounded-lg border border-white/5 bg-black/30 px-2 py-1.5"
              >
                <div className="shrink-0 font-mono text-[9px] font-semibold text-fuchsia-200 w-16">
                  {s.label}
                </div>
                <div className="text-[9px] text-zinc-400 leading-tight">
                  {s.desc}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Arrow down - Claude */}
        <div className="flex flex-col items-center py-2.5">
          <div className="h-5 w-px bg-zinc-600" />
          <div className="rounded-full border border-zinc-700 bg-zinc-900 px-2 py-0.5 text-[9px] text-zinc-400">
            token-budgeted context packs
          </div>
          <div className="h-1 w-px bg-zinc-600" />
          <svg width="10" height="6" className="text-zinc-500">
            <path d="M5 6 L0 0 L10 0Z" fill="currentColor" />
          </svg>
        </div>

        {/* Claude */}
        <div className="rounded-xl border-2 border-amber-400/40 bg-zinc-900/80 px-3 py-2.5 text-center">
          <div className="font-mono text-[9px] uppercase tracking-wider text-amber-200/70">
            Anthropic · local subprocess
          </div>
          <div className="mt-0.5 text-[14px] font-semibold text-white">
            Claude Code CLI
          </div>
          <div className="mt-1 text-[9px] text-zinc-500">
            In-app AI chat + CLI agents only · MCP tools need no Claude ·
            nothing leaves your Mac except authorised API calls
          </div>
        </div>
      </div>
    </div>
  )
}

// ─── Desktop ReactFlow ────────────────────────────────────────────────────────

type TierTier = 'app' | 'cli' | 'mcp'

type TierNodeData = {
  zone: string
  title: string
  line?: string
  tier: TierTier
  sourceRight?: boolean
  targetTop?: boolean
  tags: string[]
  footer?: string
}

type TierFlowNode = Node<TierNodeData, 'tier'>

function TierNode({ data }: NodeProps<TierFlowNode>) {
  const shells: Record<TierTier, string> = {
    app: 'w-[240px] border-violet-400/40 bg-zinc-900/95 shadow-[0_0_22px_-8px_rgba(139,92,246,0.4)]',
    cli: 'w-[240px] border-emerald-400/40 bg-zinc-900/95 shadow-[0_0_22px_-8px_rgba(52,211,153,0.3)]',
    mcp: 'w-[240px] border-teal-400/40 bg-zinc-900/95 shadow-[0_0_22px_-8px_rgba(45,212,191,0.25)]',
  }
  const tagColor: Record<TierTier, string> = {
    app: 'bg-violet-500/15 text-violet-200 border-violet-500/20',
    cli: 'bg-emerald-500/15 text-emerald-200 border-emerald-500/20',
    mcp: 'bg-teal-500/15 text-teal-200 border-teal-500/20',
  }
  return (
    <div className={`rounded-2xl border px-3 py-2.5 ${shells[data.tier]}`}>
      {data.targetTop && (
        <Handle
          type="target"
          position={Position.Top}
          id="top-target"
          className="!h-2 !w-2 !border-0 !bg-orange-400/70"
        />
      )}
      <div className="font-mono text-[9px] font-medium uppercase tracking-wider text-zinc-500">
        {data.zone}
      </div>
      <div className="mt-0.5 text-[13px] font-semibold text-white leading-tight">
        {data.title}
      </div>
      {data.line && (
        <p className="mt-0.5 text-[10px] leading-snug text-zinc-400">
          {data.line}
        </p>
      )}
      <div className="mt-1.5 flex flex-wrap gap-1">
        {data.tags.map((t) => (
          <span
            key={t}
            className={`rounded border px-1.5 py-0.5 font-mono text-[8px] leading-none ${tagColor[data.tier]}`}
          >
            {t}
          </span>
        ))}
      </div>
      {data.footer && (
        <p className="mt-1.5 border-t border-white/10 pt-1.5 text-[9px] leading-snug text-zinc-500">
          {data.footer}
        </p>
      )}
      <Handle
        type="source"
        position={Position.Bottom}
        id="bottom"
        className="!h-2 !w-2 !border-0 !bg-zinc-400"
      />
      {data.sourceRight && (
        <Handle
          type="source"
          position={Position.Right}
          id="right"
          className="!h-2 !w-2 !border-0 !bg-amber-400/80"
        />
      )}
    </div>
  )
}

function ExternalClientsNode() {
  const clients = [
    { name: 'Claude Code', color: 'text-amber-300' },
    { name: 'Cursor', color: 'text-blue-300' },
    { name: 'Windsurf', color: 'text-teal-300' },
    { name: 'VS Code Copilot', color: 'text-sky-300' },
    { name: 'Continue · any MCP host', color: 'text-zinc-400' },
  ]
  return (
    <div className="w-[210px] rounded-2xl border border-sky-400/30 bg-zinc-900/95 px-3 py-2.5 shadow-[0_0_18px_-6px_rgba(56,189,248,0.2)]">
      <div className="font-mono text-[9px] font-medium uppercase tracking-wider text-zinc-500">
        AI Agents · MCP Clients
      </div>
      <div className="mt-1.5 space-y-0.5">
        {clients.map((c) => (
          <div key={c.name} className={`text-[10px] leading-tight ${c.color}`}>
            · {c.name}
          </div>
        ))}
      </div>
      <p className="mt-1.5 border-t border-white/5 pt-1.5 text-[9px] text-zinc-600">
        MCP stdio · no Claude required
      </p>
      <Handle
        type="source"
        position={Position.Bottom}
        id="bottom"
        className="!h-2 !w-2 !border-0 !bg-sky-400/60"
      />
    </div>
  )
}

function DataPlaneNode() {
  const rows = [
    {
      path: 'deepthink.store',
      hint: 'SQLite WAL · ZTASKITEM · ZNOTE · ZPROJECT · ZREMINDER · dt_audit_log · dt_trash',
    },
    {
      path: 'vectors.db',
      hint: 'Float32 embeddings · chunks table · pending_reindex queue · WAL · app + CLI shared',
    },
    {
      path: 'knowledge/**/*.md',
      hint: 'projects · integrations · archive/ excluded from RAG · FSEvents folder-watch · YAML frontmatter',
    },
    {
      path: '.claude/',
      hint: 'agents · rules · skills · slash commands · auto-installed on first launch',
    },
  ]
  return (
    <div className="w-[min(96vw,840px)] rounded-2xl border-2 border-cyan-400/35 bg-gradient-to-b from-zinc-900 to-zinc-950 px-3 py-2.5">
      <Handle
        type="target"
        position={Position.Top}
        className="!h-2 !w-2 !border-0 !bg-cyan-400/60"
      />
      <Handle
        type="source"
        position={Position.Left}
        id="left"
        className="!h-2 !w-2 !border-0 !bg-orange-400/60"
      />
      <div className="flex items-center justify-between gap-2 border-b border-cyan-500/20 pb-1.5">
        <span className="font-mono text-[12px] font-semibold text-cyan-200">
          ~/DeepThink/
        </span>
        <span className="text-[9px] text-zinc-500">
          local-first · WAL · 5 s busy timeout · no network
        </span>
      </div>
      <div className="mt-2 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
        {rows.map((r) => (
          <div
            key={r.path}
            className="rounded-lg border border-white/5 bg-black/25 px-2 py-1.5"
          >
            <div className="font-mono text-[9px] text-cyan-100/90">
              {r.path}
            </div>
            <p className="mt-0.5 text-[9px] leading-tight text-zinc-500">
              {r.hint}
            </p>
          </div>
        ))}
      </div>
      <Handle
        type="source"
        position={Position.Bottom}
        id="bottom"
        className="!h-2 !w-2 !border-0 !bg-fuchsia-400/60"
      />
    </div>
  )
}

function RAGNode() {
  const cols = [
    {
      title: 'Tokenize',
      body: 'lowercase · 150+ stopwords removed · Porter-lite suffix stemmer',
    },
    {
      title: 'BM25',
      body: 'k1=1.5 · b=0.75 · title ×1.5 · tag ×1.3 · recency e^(−d/90) · archive excluded',
    },
    {
      title: 'Semantic',
      body: 'NLEmbedding · cosine >0.3 · top-k 20 · 5-min query cache · NaN/Inf guard',
    },
    {
      title: 'RRF K=60',
      body: 'chunksForEntryIds() batched · window 800 chars · 4 000-token budget',
    },
  ]
  return (
    <div className="w-[min(96vw,760px)] rounded-2xl border border-fuchsia-400/35 bg-zinc-900/95 px-3 py-2.5">
      <Handle
        type="target"
        position={Position.Top}
        className="!h-2 !w-2 !border-0 !bg-fuchsia-400/50"
      />
      <div className="text-center font-mono text-[9px] uppercase tracking-wider text-fuchsia-300/80">
        Hybrid RAG - shared by App · CLI · MCP
      </div>
      <div className="mt-2 grid gap-2 sm:grid-cols-4">
        {cols.map((c) => (
          <div
            key={c.title}
            className="rounded-lg border border-white/10 bg-black/30 px-2 py-1.5"
          >
            <div className="text-[10px] font-semibold text-white">
              {c.title}
            </div>
            <p className="mt-0.5 text-[9px] leading-snug text-zinc-400">
              {c.body}
            </p>
          </div>
        ))}
      </div>
      <Handle
        type="source"
        position={Position.Bottom}
        id="bottom"
        className="!h-2 !w-2 !border-0 !bg-amber-400/70"
      />
    </div>
  )
}

function ClaudeNode() {
  const rows = [
    {
      label: 'In-app chat',
      desc: 'streaming · history · branch edits · session compaction',
    },
    {
      label: '13 CLI agents',
      desc: 'research · react · planner · writer · daily-brief · analyst · …',
    },
    {
      label: 'Not needed for',
      desc: 'MCP tools · CLI commands · knowledge CRUD · search',
    },
  ]
  return (
    <div className="w-[320px] rounded-2xl border-2 border-amber-400/40 bg-zinc-900/95 px-3 py-2.5 shadow-[0_0_24px_-8px_rgba(251,191,36,0.3)]">
      <Handle
        type="target"
        position={Position.Top}
        className="!h-2 !w-2 !border-0 !bg-amber-400/60"
      />
      <div className="text-center font-mono text-[9px] uppercase tracking-wider text-amber-200/70">
        Anthropic · local subprocess
      </div>
      <div className="mt-0.5 text-center text-[14px] font-semibold text-white">
        Claude Code CLI
      </div>
      <div className="mt-2 space-y-1">
        {rows.map((r) => (
          <div
            key={r.label}
            className="flex gap-2 rounded-lg border border-white/5 bg-black/20 px-2 py-1"
          >
            <div className="w-20 shrink-0 text-[9px] font-semibold text-amber-200/80">
              {r.label}
            </div>
            <div className="text-[9px] leading-tight text-zinc-500">
              {r.desc}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

const nodeTypes: NodeTypes = {
  tier: TierNode,
  externalClients: ExternalClientsNode,
  dataPlane: DataPlaneNode,
  ragBridge: RAGNode,
  claude: ClaudeNode,
}

const eb = {
  labelStyle: { fill: '#d4d4d8', fontSize: 9 },
  labelBgStyle: { fill: '#09090b', fillOpacity: 0.92 },
  labelBgPadding: [4, 2] as [number, number],
  labelBgBorderRadius: 4,
}

function FitViewOnMount() {
  const { fitView } = useReactFlow()

  useEffect(() => {
    const timer = window.setTimeout(() => {
      fitView({ padding: 0.22, maxZoom: 0.82, minZoom: 0.28, duration: 350 })
    }, 80)
    return () => window.clearTimeout(timer)
  }, [fitView])

  return null
}

function DesktopFlow() {
  const initialNodes = useMemo(
    (): Node[] => [
      {
        id: 'clients',
        type: 'externalClients',
        position: { x: 420, y: -220 },
        data: {},
      },
      {
        id: 'swift',
        type: 'tier',
        position: { x: 0, y: 20 },
        data: {
          zone: 'Native UI · 26 services',
          title: 'DeepThink.app',
          line: 'SwiftUI + AppKit · macOS 14+',
          tier: 'app',
          sourceRight: true,
          targetTop: true,
          tags: [
            'Projects',
            'Notes',
            'Tasks',
            'Reminders',
            '⌘K',
            'Terminal',
            'AI chat',
            'Backlinks',
            'Context Graph',
          ],
          footer:
            'SwiftData save() · EmbeddingService indexes on launch · FSEvents on knowledge/ · Darwin sync · Backup + Versioning',
        } satisfies TierNodeData,
      },
      {
        id: 'cli',
        type: 'tier',
        position: { x: 310, y: 20 },
        data: {
          zone: 'Terminal · 13 agents',
          title: 'deepthink CLI',
          line: 'Bun + TypeScript · atomic writes',
          tier: 'cli',
          sourceRight: true,
          tags: [
            'context',
            'task',
            'note',
            'project',
            'knowledge',
            'ask',
            'run',
            'react',
            'research',
            'plan',
          ],
          footer:
            'db.transaction(): snapshot → dt_trash → mutate → dt_audit_log → notifyutil · memory manager · compressor',
        } satisfies TierNodeData,
      },
      {
        id: 'mcp',
        type: 'tier',
        position: { x: 620, y: 20 },
        data: {
          zone: 'MCP - any agent',
          title: 'deepthink-mcp',
          line: '51 tools · stdio · search or edit',
          tier: 'mcp',
          targetTop: true,
          tags: [
            'smart_query',
            'unified_search',
            'workspace_*',
            'knowledge_*',
            'agent/rule/skill',
            'workspace_reindex',
          ],
          footer:
            'Cursor · Claude Code · Windsurf · VS Code Copilot · Continue · any MCP-capable host · no Claude required',
        } satisfies TierNodeData,
      },
      {
        id: 'data',
        type: 'dataPlane',
        position: { x: 80, y: 360 },
        data: {},
      },
      {
        id: 'rag',
        type: 'ragBridge',
        position: { x: 110, y: 640 },
        data: {},
      },
      {
        id: 'claude',
        type: 'claude',
        position: { x: 280, y: 880 },
        data: {},
      },
    ],
    [],
  )

  const initialEdges = useMemo(
    (): Edge[] => [
      {
        id: 'clients-mcp',
        source: 'clients',
        target: 'mcp',
        sourceHandle: 'bottom',
        targetHandle: 'top-target',
        label: 'MCP stdio',
        style: { stroke: '#38bdf8', strokeWidth: 1.5 },
        ...eb,
        labelStyle: { fill: '#7dd3fc', fontSize: 9 },
      },
      {
        id: 'swift-data',
        source: 'swift',
        target: 'data',
        sourceHandle: 'bottom',
        label: 'SwiftData save()',
        style: { stroke: '#8b5cf6', strokeWidth: 1.5 },
        ...eb,
      },
      {
        id: 'cli-data',
        source: 'cli',
        target: 'data',
        sourceHandle: 'bottom',
        label: 'atomic tx · WAL',
        style: { stroke: '#34d399', strokeWidth: 1.5 },
        ...eb,
      },
      {
        id: 'mcp-data',
        source: 'mcp',
        target: 'data',
        sourceHandle: 'bottom',
        label: 'audit + trash + sync',
        style: { stroke: '#2dd4bf', strokeWidth: 1.5 },
        ...eb,
      },
      {
        id: 'data-swift',
        source: 'data',
        sourceHandle: 'left',
        target: 'swift',
        targetHandle: 'top-target',
        label: 'Darwin sync → externalSyncToken',
        type: 'default',
        style: { stroke: '#fb923c', strokeWidth: 1.25, strokeDasharray: '5 4' },
        markerEnd: {
          type: MarkerType.ArrowClosed,
          width: 12,
          height: 12,
          color: '#fb923c',
        },
        labelStyle: { fill: '#fdba74', fontSize: 9 },
        labelBgStyle: { fill: '#09090b', fillOpacity: 0.92 },
        labelBgPadding: [4, 2],
        labelBgBorderRadius: 4,
      },
      {
        id: 'data-rag',
        source: 'data',
        target: 'rag',
        sourceHandle: 'bottom',
        label: 'chunks + entries',
        style: { stroke: '#22d3ee', strokeWidth: 1.5 },
        ...eb,
      },
      {
        id: 'rag-claude',
        source: 'rag',
        target: 'claude',
        sourceHandle: 'bottom',
        label: 'context packs',
        style: { stroke: '#e879f9', strokeWidth: 1.5 },
        ...eb,
      },
      {
        id: 'swift-claude',
        source: 'swift',
        target: 'claude',
        sourceHandle: 'right',
        label: 'chat subprocess',
        style: { stroke: '#a78bfa', strokeWidth: 1, strokeDasharray: '5 5' },
        markerEnd: {
          type: MarkerType.ArrowClosed,
          width: 12,
          height: 12,
          color: '#a78bfa',
        },
        labelStyle: { fill: '#c4b5fd', fontSize: 9 },
        labelBgStyle: { fill: '#09090b', fillOpacity: 0.92 },
        labelBgPadding: [4, 2],
        labelBgBorderRadius: 4,
      },
      {
        id: 'cli-claude',
        source: 'cli',
        target: 'claude',
        sourceHandle: 'right',
        label: 'agent chains',
        style: { stroke: '#a78bfa', strokeWidth: 1, strokeDasharray: '5 5' },
        markerEnd: {
          type: MarkerType.ArrowClosed,
          width: 12,
          height: 12,
          color: '#a78bfa',
        },
        labelStyle: { fill: '#c4b5fd', fontSize: 9 },
        labelBgStyle: { fill: '#09090b', fillOpacity: 0.92 },
        labelBgPadding: [4, 2],
        labelBgBorderRadius: 4,
      },
    ],
    [],
  )

  const [nodes, , onNodesChange] = useNodesState(initialNodes)
  const [edges, , onEdgesChange] = useEdgesState(initialEdges)

  return (
    <div
      data-testid="architecture-flow"
      className="h-[min(88dvh,980px)] w-full overflow-hidden rounded-2xl border border-white/10 bg-zinc-950 shadow-[0_24px_80px_-32px_rgba(124,58,237,0.25)] ring-1 ring-purple-500/10 [&_.react-flow\_\_attribution]:hidden"
    >
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        nodeTypes={nodeTypes}
        defaultEdgeOptions={{
          type: 'smoothstep',
          markerEnd: {
            type: MarkerType.ArrowClosed,
            width: 14,
            height: 14,
            color: '#52525b',
          },
        }}
        fitView
        fitViewOptions={{ padding: 0.22, maxZoom: 0.82, minZoom: 0.28 }}
        minZoom={0.1}
        maxZoom={1.4}
        nodesConnectable={false}
        elementsSelectable={false}
        proOptions={{ hideAttribution: true }}
        colorMode="dark"
        className="!bg-zinc-950"
      >
        <FitViewOnMount />
        <Background
          id="arch-bg"
          variant={BackgroundVariant.Dots}
          gap={22}
          size={1}
          color="#3f3f46"
        />
        <Controls
          className="!mb-3 !ml-3 !rounded-xl !border !border-white/10 !bg-zinc-900/95 !shadow-xl [&_button]:!border-white/10 [&_button]:!bg-zinc-800 [&_button]:!fill-zinc-200 [&_button:hover]:!bg-zinc-700"
          showInteractive={false}
        />
        <MiniMap
          aria-label="Overview"
          pannable
          zoomable
          style={{ width: 130, height: 80 }}
          className="!mb-12 !mr-3 !rounded-xl !border !border-white/10 !bg-zinc-900/95"
          maskColor="rgb(9,9,11,0.9)"
          nodeColor={(n) =>
            n.type === 'externalClients'
              ? '#38bdf8'
              : n.type === 'dataPlane'
                ? '#22d3ee'
                : n.type === 'ragBridge'
                  ? '#e879f9'
                  : n.type === 'claude'
                    ? '#fbbf24'
                    : n.type === 'tier'
                      ? (n.data as TierNodeData).tier === 'app'
                        ? '#8b5cf6'
                        : (n.data as TierNodeData).tier === 'cli'
                          ? '#34d399'
                          : '#2dd4bf'
                      : '#71717a'
          }
        />
        <Panel position="top-center" className="m-2">
          <div className="rounded-xl border border-white/10 bg-zinc-950/95 px-3 py-1.5 shadow-lg backdrop-blur-sm">
            <div className="flex flex-wrap items-center justify-center gap-x-4 gap-y-1 text-[9px] text-zinc-400">
              {[
                { color: 'bg-sky-400', label: 'clients → MCP' },
                { color: 'bg-violet-400', label: 'app → disk' },
                { color: 'bg-emerald-400', label: 'CLI → disk' },
                { color: 'bg-teal-400', label: 'MCP → disk' },
                { color: 'bg-cyan-400', label: 'disk → RAG' },
                { color: 'bg-fuchsia-400', label: 'RAG → in-app AI' },
              ].map((l) => (
                <span
                  key={l.label}
                  className="inline-flex items-center gap-1.5 whitespace-nowrap"
                >
                  <span className={`inline-block h-px w-3 ${l.color}`} />
                  {l.label}
                </span>
              ))}
              <span className="inline-flex items-center gap-1.5 whitespace-nowrap">
                <span className="inline-block w-3 border-t-2 border-dashed border-orange-400" />
                Darwin sync
              </span>
              <span className="inline-flex items-center gap-1.5 whitespace-nowrap">
                <span className="inline-block w-3 border-t border-dotted border-violet-300" />
                spawn
              </span>
            </div>
          </div>
        </Panel>
      </ReactFlow>
    </div>
  )
}

// ─── Root: mobile vs desktop ──────────────────────────────────────────────────

export default function ArchitectureFlowGraph() {
  const [isMobile, setIsMobile] = useState(
    () =>
      typeof window !== 'undefined' &&
      window.matchMedia('(max-width: 767px)').matches,
  )

  useEffect(() => {
    const mq = window.matchMedia('(max-width: 767px)')
    const handler = (e: MediaQueryListEvent) => setIsMobile(e.matches)
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }, [])

  return isMobile ? <MobileFlow /> : <DesktopFlow />
}
