import { useMemo } from 'react'
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
  type Edge,
  type Node,
  type NodeProps,
  type NodeTypes,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'

type TagTone = 'violet' | 'emerald' | 'cyan'

function TagChips({ items, tone }: { items: string[]; tone: TagTone }) {
  const tones: Record<TagTone, string> = {
    violet: 'bg-violet-500/15 text-violet-200 border-violet-500/20',
    emerald: 'bg-emerald-500/15 text-emerald-200 border-emerald-500/20',
    cyan: 'bg-cyan-500/15 text-cyan-200 border-cyan-500/20',
  }
  const cls = tones[tone] ?? tones.violet
  return (
    <div className="mt-2 flex flex-wrap gap-1">
      {items.map((t) => (
        <span
          key={t}
          className={`rounded-md border px-1.5 py-0.5 font-mono text-[9px] leading-none sm:text-[10px] ${cls}`}
        >
          {t}
        </span>
      ))}
    </div>
  )
}

type TierTier = 'app' | 'cli' | 'mcp'

type TierNodeData = {
  zone: string
  title: string
  line?: string
  tier: TierTier
  sourceRight?: boolean
  tags: string[]
  footer?: string
}

type TierFlowNode = Node<TierNodeData, 'tier'>

function TierNode({ data }: NodeProps<TierFlowNode>) {
  const shells: Record<TierTier, string> = {
    app: 'w-[280px] shrink-0 border-violet-400/40 bg-zinc-900/95 shadow-[0_0_28px_-10px_rgba(139,92,246,0.45)]',
    cli: 'w-[280px] shrink-0 border-emerald-400/40 bg-zinc-900/95 shadow-[0_0_28px_-10px_rgba(52,211,153,0.35)]',
    mcp: 'w-[280px] shrink-0 border-teal-400/40 bg-zinc-900/95 shadow-[0_0_28px_-10px_rgba(45,212,191,0.3)]',
  }
  return (
    <div className={`rounded-2xl border px-3 py-2.5 ${shells[data.tier]}`}>
      <div className="font-mono text-[10px] font-medium uppercase tracking-wider text-zinc-500">
        {data.zone}
      </div>
      <div className="mt-0.5 text-[14px] font-semibold leading-tight text-white">
        {data.title}
      </div>
      {data.line && (
        <p className="mt-1 text-[11px] leading-snug text-zinc-400">
          {data.line}
        </p>
      )}
      <TagChips
        items={data.tags}
        tone={
          data.tier === 'app'
            ? 'violet'
            : data.tier === 'mcp'
              ? 'cyan'
              : 'emerald'
        }
      />
      {data.footer && (
        <p className="mt-2 border-t border-white/10 pt-2 text-[10px] leading-snug text-zinc-500">
          {data.footer}
        </p>
      )}
      <Handle
        type="source"
        position={Position.Bottom}
        id="bottom"
        className="!h-2.5 !w-2.5 !border-0 !bg-zinc-400"
      />
      {data.sourceRight && (
        <Handle
          type="source"
          position={Position.Right}
          id="right"
          className="!h-2.5 !w-2.5 !border-0 !bg-amber-400/90"
        />
      )}
    </div>
  )
}

function DataPlaneNode() {
  const rows = [
    {
      path: 'data/deepthink.store',
      hint: 'SwiftData SQLite (WAL) — projects, notes, tasks, reminders, chat, MCP catalog…',
    },
    {
      path: 'data/vectors.db',
      hint: 'Chunk embeddings · hybrid semantic leg · shared by app indexing + CLI retrieval',
    },
    {
      path: 'knowledge/**/*.md',
      hint: 'Capture + imports · integrations + archive · scanned into ContextEngine',
    },
    {
      path: 'sandbox/, memory/, logs/',
      hint: 'Agent outputs · long-running CLI memory · diagnostics',
    },
  ]
  return (
    <div className="w-[min(96vw,760px)] rounded-2xl border-2 border-cyan-400/35 bg-gradient-to-b from-zinc-900 to-zinc-950 px-4 py-3 shadow-[0_0_40px_-12px_rgba(34,211,238,0.35)]">
      <Handle
        type="target"
        position={Position.Top}
        className="!h-2.5 !w-2.5 !border-0 !bg-cyan-400/60"
      />
      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-cyan-500/20 pb-2">
        <span className="font-mono text-sm font-semibold text-cyan-200">
          ~/DeepThink
        </span>
        <span className="rounded-full border border-white/10 bg-black/40 px-2 py-0.5 text-[10px] font-medium tracking-wide text-zinc-400">
          local-first · single home directory
        </span>
      </div>
      <div className="mt-3 grid gap-3 sm:grid-cols-2">
        {rows.map((r) => (
          <div
            key={r.path}
            className="rounded-lg border border-white/5 bg-black/25 px-2.5 py-2"
          >
            <div className="font-mono text-[11px] text-cyan-100/95">
              {r.path}
            </div>
            <p className="mt-1 text-[10px] leading-snug text-zinc-500">
              {r.hint}
            </p>
          </div>
        ))}
      </div>
      <Handle
        type="source"
        position={Position.Bottom}
        id="bottom"
        className="!h-2.5 !w-2.5 !border-0 !bg-fuchsia-400/70"
      />
    </div>
  )
}

function RAGNode() {
  return (
    <div className="w-[min(96vw,600px)] rounded-2xl border border-fuchsia-400/35 bg-zinc-900/95 px-3 py-2.5">
      <Handle
        type="target"
        position={Position.Top}
        className="!h-2.5 !w-2.5 !border-0 !bg-fuchsia-400/50"
      />
      <div className="text-center font-mono text-[10px] uppercase tracking-wider text-fuchsia-300/80">
        Hybrid RAG
      </div>
      <div className="mt-2 grid gap-2 sm:grid-cols-2 sm:gap-3">
        <div className="rounded-lg border border-white/10 bg-black/30 px-2 py-1.5">
          <div className="text-[11px] font-semibold text-white">
            In the macOS app
          </div>
          <p className="mt-1 text-[10px] leading-snug text-zinc-400">
            Swift <span className="text-zinc-300">ContextEngine</span> +{' '}
            <span className="text-zinc-300">NLEmbedding</span> · BM25-style
            scoring on vector chunks → assistant context
          </p>
        </div>
        <div className="rounded-lg border border-white/10 bg-black/30 px-2 py-1.5">
          <div className="text-[11px] font-semibold text-white">
            CLI &amp; MCP
          </div>
          <p className="mt-1 text-[10px] leading-snug text-zinc-400">
            <span className="text-zinc-300">retrieveContextHybrid</span> ·{' '}
            <span className="text-zinc-300">embedding-service</span> · same
            store + markdown → tools &amp; scripts
          </p>
        </div>
      </div>
      <p className="mt-2 text-center text-[10px] text-zinc-500">
        Token-capped packs · BM25 + semantic · optional project scope
      </p>
      <Handle
        type="source"
        position={Position.Bottom}
        id="bottom"
        className="!h-2.5 !w-2.5 !border-0 !bg-amber-400/80"
      />
    </div>
  )
}

function ClaudeNode() {
  return (
    <div className="w-[300px] shrink-0 rounded-2xl border-2 border-amber-400/40 bg-zinc-900/95 px-3 py-2.5 shadow-[0_0_32px_-8px_rgba(251,191,36,0.35)]">
      <Handle
        type="target"
        position={Position.Top}
        className="!h-2.5 !w-2.5 !border-0 !bg-amber-400/60"
      />
      <div className="text-center font-mono text-[10px] uppercase tracking-wider text-amber-200/70">
        Anthropic · local subprocess
      </div>
      <div className="mt-1 text-center text-[15px] font-semibold text-white">
        Claude Code CLI
      </div>
      <TagChips
        items={[
          'claude login',
          'stream JSON',
          'chat UI',
          'ask · analyze · pipelines',
        ]}
        tone="cyan"
      />
      <p className="mt-2 border-t border-white/10 pt-2 text-[10px] leading-snug text-zinc-500">
        Spawned by the app + CLI agents (Planner · Writer · Executor · Research
        · … ) — nothing leaves your Mac except API calls you authorize.
      </p>
    </div>
  )
}

const nodeTypes: NodeTypes = {
  tier: TierNode,
  dataPlane: DataPlaneNode,
  ragBridge: RAGNode,
  claude: ClaudeNode,
}

const defaultEdgeOptions = {
  type: 'default' as const,
  markerEnd: {
    type: MarkerType.ArrowClosed,
    width: 16,
    height: 16,
    color: '#52525b',
  },
}

const eb = {
  labelStyle: { fill: '#d4d4d8', fontSize: 9 },
  labelBgStyle: { fill: '#09090b', fillOpacity: 0.94 },
  labelBgPadding: [4, 2] as [number, number],
  labelBgBorderRadius: 4,
}

export default function ArchitectureFlowGraph() {
  const initialNodes = useMemo(
    (): Node[] => [
      {
        id: 'swift',
        type: 'tier',
        position: { x: 60, y: 50 },
        data: {
          zone: 'Native UI',
          title: 'DeepThink.app',
          line: 'SwiftUI + AppKit · primary workspace',
          tier: 'app',
          sourceRight: true,
          tags: [
            'Projects',
            'Notes',
            'Tasks',
            'Reminders',
            'Knowledge',
            '⌘K',
            'Terminal',
            'AI chat',
            'Sparkle',
          ],
          footer:
            'SwiftData writes here · ContextEngine + VectorStore index knowledge',
        },
      },
      {
        id: 'cli',
        type: 'tier',
        position: { x: 500, y: 50 },
        data: {
          zone: 'Terminal',
          title: 'deepthink CLI',
          line: 'Bun + TypeScript · same SQLite + files',
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
            'workspace',
            'research',
            'insight',
            'schedule',
            'agents',
          ],
          footer:
            'Entry: cli/src/index.ts → core/db · context-engine · tools · agents/',
        },
      },
      {
        id: 'mcp',
        type: 'tier',
        position: { x: 940, y: 50 },
        data: {
          zone: 'MCP bridge',
          title: 'deepthink-mcp',
          line: 'stdio MCP server · editors & Claude Code hosts',
          tier: 'mcp',
          tags: [
            'smart_query',
            'workspace_*',
            'knowledge_*',
            'rules · skills · agents',
          ],
          footer:
            'Merges SMART + WORKSPACE + KNOWLEDGE + CONFIG tools · Resources: tasks, notes, overview…',
        },
      },
      {
        id: 'data',
        type: 'dataPlane',
        position: { x: 320, y: 360 },
        data: {},
      },
      {
        id: 'rag',
        type: 'ragBridge',
        position: { x: 400, y: 720 },
        data: {},
      },
      {
        id: 'claude',
        type: 'claude',
        position: { x: 550, y: 1020 },
        data: {},
      },
    ],
    [],
  )

  const initialEdges = useMemo(
    (): Edge[] => [
      {
        id: 'swift-data',
        source: 'swift',
        target: 'data',
        sourceHandle: 'bottom',
        label: 'SwiftData + files',
        style: { stroke: '#8b5cf6', strokeWidth: 2 },
        ...eb,
      },
      {
        id: 'cli-data',
        source: 'cli',
        target: 'data',
        sourceHandle: 'bottom',
        label: 'WAL read/write · busy_timeout',
        style: { stroke: '#34d399', strokeWidth: 2 },
        ...eb,
      },
      {
        id: 'mcp-data',
        source: 'mcp',
        target: 'data',
        sourceHandle: 'bottom',
        label: 'tools → DB + markdown',
        style: { stroke: '#2dd4bf', strokeWidth: 2 },
        ...eb,
      },
      {
        id: 'data-rag',
        source: 'data',
        target: 'rag',
        sourceHandle: 'bottom',
        label: 'index + hydrate chunks',
        style: { stroke: '#22d3ee', strokeWidth: 2 },
        ...eb,
      },
      {
        id: 'rag-claude',
        source: 'rag',
        target: 'claude',
        sourceHandle: 'bottom',
        label: 'context packs in prompts',
        style: { stroke: '#e879f9', strokeWidth: 2 },
        ...eb,
      },
      {
        id: 'swift-claude',
        source: 'swift',
        target: 'claude',
        sourceHandle: 'right',
        label: 'chat subprocess',
        style: { stroke: '#a78bfa', strokeWidth: 1.25, strokeDasharray: '5 5' },
        labelStyle: { fill: '#c4b5fd', fontSize: 9 },
        labelBgStyle: { fill: '#09090b', fillOpacity: 0.94 },
        labelBgPadding: [4, 2],
        labelBgBorderRadius: 4,
      },
      {
        id: 'cli-claude',
        source: 'cli',
        target: 'claude',
        sourceHandle: 'right',
        label: 'llm.ts · agent chains',
        style: { stroke: '#a78bfa', strokeWidth: 1.25, strokeDasharray: '5 5' },
        labelStyle: { fill: '#c4b5fd', fontSize: 9 },
        labelBgStyle: { fill: '#09090b', fillOpacity: 0.94 },
        labelBgPadding: [4, 2],
        labelBgBorderRadius: 4,
      },
    ],
    [],
  )

  const [nodes, , onNodesChange] = useNodesState(initialNodes)
  const [edges, , onEdgesChange] = useEdgesState(initialEdges)

  return (
    <div className="h-[min(88dvh,920px)] w-full min-h-[min(440px,65dvh)] sm:min-h-[520px] md:min-h-[560px] overflow-hidden rounded-2xl border border-white/10 bg-zinc-950 touch-manipulation [&_.react-flow\_\_attribution]:hidden">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        nodeTypes={nodeTypes}
        defaultEdgeOptions={defaultEdgeOptions}
        fitView
        fitViewOptions={{
          padding: 0.38,
          maxZoom: 0.88,
          minZoom: 0.22,
          includeHiddenNodes: false,
        }}
        minZoom={0.2}
        maxZoom={1.35}
        nodesConnectable={false}
        elementsSelectable={false}
        proOptions={{ hideAttribution: true }}
        colorMode="dark"
        className="!bg-zinc-950"
      >
        <Background
          id="arch-bg"
          variant={BackgroundVariant.Dots}
          gap={22}
          size={1.1}
          color="#3f3f46"
        />
        <Controls
          className="!mb-3 !ml-3 !overflow-hidden !rounded-xl !border !border-white/10 !bg-zinc-900/95 !shadow-xl [&_button]:!border-white/10 [&_button]:!bg-zinc-800 [&_button]:!fill-zinc-200 [&_button:hover]:!bg-zinc-700"
          showInteractive={false}
        />
        <MiniMap
          aria-label="Diagram overview map"
          pannable
          zoomable
          style={{ width: 152, height: 96 }}
          className="!mb-12 !mr-3 !overflow-hidden !rounded-xl !border !border-white/10 !bg-zinc-900/95 !shadow-lg"
          maskColor="rgb(9,9,11,0.9)"
          nodeColor={(n) => {
            if (n.type === 'dataPlane') return '#22d3ee'
            if (n.type === 'tier') {
              const d = n.data as TierNodeData
              return d.tier === 'app'
                ? '#8b5cf6'
                : d.tier === 'cli'
                  ? '#34d399'
                  : '#2dd4bf'
            }
            if (n.type === 'ragBridge') return '#e879f9'
            if (n.type === 'claude') return '#fbbf24'
            return '#71717a'
          }}
        />
        <Panel
          position="top-center"
          className="m-2 max-w-[min(100%,calc(100vw-2.25rem))] sm:max-w-[calc(100%-10rem)] md:max-w-xl"
        >
          <div className="flex flex-col gap-0 rounded-xl border border-white/10 bg-zinc-950/95 px-3 py-2 shadow-lg backdrop-blur-sm sm:gap-2">
            <p className="hidden font-mono text-[9px] uppercase tracking-[0.18em] text-zinc-500 sm:block">
              Drag nodes · scroll to zoom · use +/− controls
            </p>
            <div className="flex flex-wrap items-center justify-center gap-x-3 gap-y-1.5 text-[9px] text-zinc-400">
              <span className="inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap">
                <span className="inline-block h-px w-3 bg-violet-400" />
                app → disk
              </span>
              <span className="inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap">
                <span className="inline-block h-px w-3 bg-emerald-400" />
                CLI/MCP → disk
              </span>
              <span className="inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap">
                <span className="inline-block h-px w-3 bg-cyan-400" />
                disk → RAG
              </span>
              <span className="inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap">
                <span className="inline-block h-px w-3 bg-fuchsia-400" />
                RAG → Claude
              </span>
              <span className="inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap">
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
