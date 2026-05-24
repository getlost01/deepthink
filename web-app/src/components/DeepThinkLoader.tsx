import { AnimatePresence, motion, useReducedMotion } from 'framer-motion'
import { useEffect, useState } from 'react'

const THINKING_MESSAGES = [
  'Retrieving context…',
  'Connecting surfaces…',
  'Indexing memory…',
  'Thinking deeper…',
] as const

const BOOT_MESSAGES = [
  'Warming up local workspace…',
  'Loading context graph…',
  'Connecting app, CLI, and MCP…',
  'Indexing memory on disk…',
  'Almost ready…',
] as const

const GRAPH_NODES = [
  { id: 'core', cx: 100, cy: 100, r: 9, delay: 0 },
  { id: 'n1', cx: 100, cy: 28, r: 5.5, delay: 0.15 },
  { id: 'n2', cx: 168, cy: 72, r: 5, delay: 0.3 },
  { id: 'n3', cx: 148, cy: 152, r: 5, delay: 0.45 },
  { id: 'n4', cx: 52, cy: 152, r: 5, delay: 0.6 },
  { id: 'n5', cx: 32, cy: 72, r: 5.5, delay: 0.75 },
] as const

const GRAPH_EDGES: Array<[string, string]> = [
  ['core', 'n1'],
  ['core', 'n2'],
  ['core', 'n3'],
  ['core', 'n4'],
  ['core', 'n5'],
  ['n1', 'n2'],
  ['n2', 'n3'],
  ['n3', 'n4'],
  ['n4', 'n5'],
  ['n5', 'n1'],
]

const FLOATING_PARTICLES = [
  { x: '12%', y: '18%', size: 4, delay: 0 },
  { x: '78%', y: '22%', size: 3, delay: 0.4 },
  { x: '86%', y: '62%', size: 5, delay: 0.8 },
  { x: '18%', y: '72%', size: 3, delay: 1.1 },
  { x: '52%', y: '8%', size: 2, delay: 1.5 },
  { x: '64%', y: '88%', size: 4, delay: 0.6 },
] as const

function nodeById(id: string) {
  return GRAPH_NODES.find((n) => n.id === id)!
}

function ContextGraph({
  compact = false,
  animated = true,
}: {
  compact?: boolean
  animated?: boolean
}) {
  const prefersReducedMotion = useReducedMotion()
  const size = compact ? 88 : 200
  const motionEnabled = animated && !prefersReducedMotion

  return (
    <div className="relative" style={{ width: size, height: size }}>
      {!compact && motionEnabled && (
        <>
          <motion.div
            aria-hidden
            className="pointer-events-none absolute inset-0 rounded-full border border-purple-400/20"
            animate={{ rotate: 360, scale: [1, 1.04, 1] }}
            transition={{
              rotate: { duration: 18, repeat: Infinity, ease: 'linear' },
              scale: { duration: 4, repeat: Infinity, ease: 'easeInOut' },
            }}
          />
          <motion.div
            aria-hidden
            className="pointer-events-none absolute inset-3 rounded-full border border-dashed border-cyan-400/25"
            animate={{ rotate: -360 }}
            transition={{ duration: 24, repeat: Infinity, ease: 'linear' }}
          />
          <motion.div
            aria-hidden
            className="pointer-events-none absolute inset-[-10px] rounded-full bg-purple-500/10 blur-xl"
            animate={{ opacity: [0.35, 0.7, 0.35], scale: [0.95, 1.08, 0.95] }}
            transition={{ duration: 3.5, repeat: Infinity, ease: 'easeInOut' }}
          />
        </>
      )}

      <motion.div
        className="relative h-full w-full"
        animate={motionEnabled ? { rotate: [0, 4, 0, -4, 0] } : undefined}
        transition={{ duration: 8, repeat: Infinity, ease: 'easeInOut' }}
      >
        <svg
          viewBox="0 0 200 200"
          width={size}
          height={size}
          aria-hidden
          className="overflow-visible"
        >
          <defs>
            <radialGradient id="dt-loader-core" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#c4b5fd" />
              <stop offset="100%" stopColor="#7c3aed" />
            </radialGradient>
            <linearGradient
              id="dt-loader-line"
              x1="0%"
              y1="0%"
              x2="100%"
              y2="100%"
            >
              <stop offset="0%" stopColor="#8b5cf6" stopOpacity="0.2" />
              <stop offset="50%" stopColor="#22d3ee" stopOpacity="0.85" />
              <stop offset="100%" stopColor="#8b5cf6" stopOpacity="0.2" />
            </linearGradient>
            <filter
              id="dt-loader-glow"
              x="-50%"
              y="-50%"
              width="200%"
              height="200%"
            >
              <feGaussianBlur stdDeviation="3" result="blur" />
              <feMerge>
                <feMergeNode in="blur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          </defs>

          {GRAPH_EDGES.map(([from, to], i) => {
            const a = nodeById(from)
            const b = nodeById(to)
            return (
              <g key={`${from}-${to}`}>
                <motion.line
                  x1={a.cx}
                  y1={a.cy}
                  x2={b.cx}
                  y2={b.cy}
                  stroke="url(#dt-loader-line)"
                  strokeWidth={1.25}
                  strokeLinecap="round"
                  initial={{ pathLength: 0, opacity: 0.2 }}
                  animate={
                    prefersReducedMotion || !animated
                      ? { pathLength: 1, opacity: 0.45 }
                      : {
                          pathLength: [0.1, 1, 0.1],
                          opacity: [0.2, 0.85, 0.2],
                        }
                  }
                  transition={{
                    duration: 2.2,
                    repeat: motionEnabled ? Infinity : 0,
                    delay: i * 0.07,
                    ease: 'easeInOut',
                  }}
                />
                {motionEnabled && i % 2 === 0 && (
                  <motion.circle
                    r={2.5}
                    fill="#67e8f9"
                    initial={{ cx: a.cx, cy: a.cy, opacity: 0 }}
                    animate={{
                      cx: [a.cx, b.cx, a.cx],
                      cy: [a.cy, b.cy, a.cy],
                      opacity: [0, 1, 0],
                    }}
                    transition={{
                      duration: 2.8,
                      repeat: Infinity,
                      delay: i * 0.35,
                      ease: 'easeInOut',
                    }}
                  />
                )}
              </g>
            )
          })}

          {GRAPH_NODES.map((node) => (
            <motion.g
              key={node.id}
              filter={node.id === 'core' ? 'url(#dt-loader-glow)' : undefined}
            >
              {node.id === 'core' && (
                <>
                  <motion.circle
                    cx={node.cx}
                    cy={node.cy}
                    r={node.r + 18}
                    fill="none"
                    stroke="#a78bfa"
                    strokeWidth={0.75}
                    strokeDasharray="4 6"
                    initial={{ opacity: 0.1, rotate: 0 }}
                    animate={
                      motionEnabled
                        ? { opacity: [0.1, 0.35, 0.1], rotate: 360 }
                        : { opacity: 0.2, rotate: 0 }
                    }
                    transition={{
                      opacity: {
                        duration: 2.8,
                        repeat: motionEnabled ? Infinity : 0,
                        ease: 'easeInOut',
                      },
                      rotate: {
                        duration: 14,
                        repeat: motionEnabled ? Infinity : 0,
                        ease: 'linear',
                      },
                    }}
                    style={{ transformOrigin: `${node.cx}px ${node.cy}px` }}
                  />
                  <motion.circle
                    cx={node.cx}
                    cy={node.cy}
                    r={node.r + 10}
                    fill="none"
                    stroke="#a78bfa"
                    strokeWidth={1}
                    initial={{ opacity: 0.15, scale: 0.9 }}
                    animate={
                      motionEnabled
                        ? {
                            opacity: [0.15, 0.55, 0.15],
                            scale: [0.9, 1.12, 0.9],
                          }
                        : { opacity: 0.25, scale: 1 }
                    }
                    transition={{
                      duration: 2.4,
                      repeat: motionEnabled ? Infinity : 0,
                      ease: 'easeInOut',
                    }}
                    style={{ transformOrigin: `${node.cx}px ${node.cy}px` }}
                  />
                </>
              )}
              <motion.circle
                cx={node.cx}
                cy={node.cy}
                r={node.r}
                fill={node.id === 'core' ? 'url(#dt-loader-core)' : '#312e81'}
                stroke={node.id === 'core' ? '#ddd6fe' : '#818cf8'}
                strokeWidth={1.25}
                initial={{ opacity: 0.6, scale: 0.85 }}
                animate={
                  motionEnabled
                    ? { opacity: [0.5, 1, 0.5], scale: [0.86, 1.08, 0.86] }
                    : { opacity: 1, scale: 1 }
                }
                transition={{
                  duration: 2,
                  repeat: motionEnabled ? Infinity : 0,
                  delay: node.delay,
                  ease: 'easeInOut',
                }}
                style={{ transformOrigin: `${node.cx}px ${node.cy}px` }}
              />
            </motion.g>
          ))}
        </svg>
      </motion.div>
    </div>
  )
}

function ThinkingMessage({
  messages = THINKING_MESSAGES,
  compact = false,
}: {
  messages?: readonly string[]
  compact?: boolean
}) {
  const prefersReducedMotion = useReducedMotion()
  const [index, setIndex] = useState(0)

  useEffect(() => {
    if (prefersReducedMotion || messages.length <= 1) return undefined
    const id = window.setInterval(
      () => {
        setIndex((i) => (i + 1) % messages.length)
      },
      compact ? 2200 : 1800,
    )
    return () => window.clearInterval(id)
  }, [messages, prefersReducedMotion, compact])

  const textClass = compact
    ? 'text-xs text-zinc-500'
    : 'text-sm font-medium text-zinc-400'

  if (prefersReducedMotion) {
    return <p className={textClass}>{messages[0]}</p>
  }

  return (
    <motion.div
      className={`relative ${compact ? 'h-4' : 'h-5'} overflow-hidden`}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
    >
      <AnimatePresence mode="wait">
        <motion.p
          key={messages[index]}
          className={`absolute inset-x-0 ${textClass}`}
          initial={{ opacity: 0, y: 10, filter: 'blur(4px)' }}
          animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
          exit={{ opacity: 0, y: -10, filter: 'blur(4px)' }}
          transition={{ duration: 0.4, ease: 'easeOut' }}
        >
          {messages[index]}
        </motion.p>
      </AnimatePresence>
    </motion.div>
  )
}

function BootingTitle() {
  const prefersReducedMotion = useReducedMotion()

  return (
    <motion.div
      className="flex flex-col items-center gap-1 text-center"
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.55, ease: 'easeOut' }}
    >
      <p className="text-xs font-semibold uppercase tracking-[0.22em] text-purple-300/80">
        Local-first MCP workspace
      </p>
      <h1 className="landing-shimmer-text text-2xl font-semibold tracking-tight md:text-3xl">
        Booting DeepThink
        {!prefersReducedMotion && (
          <motion.span
            aria-hidden
            className="inline-flex w-[1.35em] justify-start text-purple-200"
            initial={{ opacity: 0.4 }}
            animate={{ opacity: [0.35, 1, 0.35] }}
            transition={{ duration: 1.2, repeat: Infinity, ease: 'easeInOut' }}
          >
            …
          </motion.span>
        )}
        {prefersReducedMotion && '…'}
      </h1>
    </motion.div>
  )
}

function BootProgressBar({ durationMs }: { durationMs: number }) {
  const prefersReducedMotion = useReducedMotion()

  return (
    <motion.div
      className="mt-2 w-full max-w-xs"
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.35, duration: 0.45 }}
    >
      <motion.div
        className="h-1 overflow-hidden rounded-full bg-white/10"
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label="Boot progress"
      >
        <motion.div
          className="h-full rounded-full bg-gradient-to-r from-violet-500 via-cyan-400 to-violet-400"
          initial={{ width: '0%' }}
          animate={{ width: '100%' }}
          transition={{
            duration: prefersReducedMotion ? 0.3 : durationMs / 1000,
            ease: [0.22, 1, 0.36, 1],
          }}
        />
      </motion.div>
      <motion.p
        className="mt-2 text-center text-[11px] uppercase tracking-widest text-zinc-500"
        animate={
          prefersReducedMotion ? undefined : { opacity: [0.45, 0.85, 0.45] }
        }
        transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
      >
        Preparing your workspace
      </motion.p>
    </motion.div>
  )
}

function FloatingParticles() {
  const prefersReducedMotion = useReducedMotion()
  if (prefersReducedMotion) return null

  return (
    <motion.div
      aria-hidden
      className="pointer-events-none absolute inset-0 overflow-hidden"
    >
      {FLOATING_PARTICLES.map((p, i) => (
        <motion.span
          key={i}
          className="absolute rounded-full bg-purple-300/40 blur-[1px]"
          style={{
            left: p.x,
            top: p.y,
            width: p.size,
            height: p.size,
          }}
          animate={{
            y: [0, -28, 0],
            x: [0, i % 2 === 0 ? 10 : -10, 0],
            opacity: [0.2, 0.75, 0.2],
            scale: [0.8, 1.2, 0.8],
          }}
          transition={{
            duration: 4 + i * 0.4,
            repeat: Infinity,
            delay: p.delay,
            ease: 'easeInOut',
          }}
        />
      ))}
    </motion.div>
  )
}

type DeepThinkLoaderProps = {
  variant?: 'fullscreen' | 'inline'
  mode?: 'default' | 'boot'
  message?: string
  label?: string
  bootDurationMs?: number
}

export default function DeepThinkLoader({
  variant = 'fullscreen',
  mode = 'default',
  message,
  label = 'Loading DeepThink',
  bootDurationMs = 5000,
}: DeepThinkLoaderProps) {
  const prefersReducedMotion = useReducedMotion()
  const isBoot = mode === 'boot'
  const messages = message
    ? [message]
    : isBoot
      ? BOOT_MESSAGES
      : THINKING_MESSAGES
  const compact = variant === 'inline'

  if (compact) {
    return (
      <div
        role="status"
        aria-live="polite"
        aria-label={label}
        className="flex flex-col items-center justify-center gap-4 py-16"
      >
        <ContextGraph compact animated={!prefersReducedMotion} />
        <ThinkingMessage messages={messages} compact />
      </div>
    )
  }

  return (
    <div
      role="status"
      aria-live="polite"
      aria-label={isBoot ? 'Booting DeepThink' : label}
      className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-zinc-950 px-6"
    >
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_50%_20%,rgba(124,58,237,0.28),rgba(9,9,11,0.4)_45%,rgba(9,9,11,1)_75%)]"
      />
      <motion.div
        aria-hidden
        className="pointer-events-none absolute -right-24 top-16 h-72 w-72 rounded-full bg-purple-500/30 blur-3xl"
        animate={
          prefersReducedMotion
            ? undefined
            : { opacity: [0.2, 0.55, 0.2], scale: [1, 1.1, 1], x: [0, -20, 0] }
        }
        transition={{ duration: 7, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        aria-hidden
        className="pointer-events-none absolute -left-20 bottom-20 h-56 w-56 rounded-full bg-cyan-500/20 blur-3xl"
        animate={
          prefersReducedMotion
            ? undefined
            : { opacity: [0.12, 0.4, 0.12], y: [0, -24, 0] }
        }
        transition={{ duration: 8, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-1/3 h-64 w-64 -translate-x-1/2 rounded-full bg-violet-400/10 blur-3xl"
        animate={
          prefersReducedMotion
            ? undefined
            : { scale: [1, 1.2, 1], opacity: [0.1, 0.35, 0.1] }
        }
        transition={{ duration: 9, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-35 [background-image:linear-gradient(rgba(255,255,255,0.035)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.035)_1px,transparent_1px)] [background-size:48px_48px] [mask-image:radial-gradient(ellipse_at_center,black_15%,transparent_70%)]"
        animate={
          prefersReducedMotion ? undefined : { opacity: [0.25, 0.45, 0.25] }
        }
        transition={{ duration: 5, repeat: Infinity, ease: 'easeInOut' }}
      />
      <FloatingParticles />

      <motion.div
        className="relative flex flex-col items-center gap-7 md:gap-8"
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.55, ease: 'easeOut' }}
      >
        {isBoot ? <BootingTitle /> : null}

        <motion.div
          animate={
            prefersReducedMotion || !isBoot ? undefined : { y: [0, -6, 0] }
          }
          transition={{ duration: 4.5, repeat: Infinity, ease: 'easeInOut' }}
        >
          <ContextGraph animated={!prefersReducedMotion} />
        </motion.div>

        <motion.div
          className="flex w-full max-w-sm flex-col items-center gap-3 text-center"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.25, duration: 0.45 }}
        >
          {!isBoot && (
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-purple-300/90">
              DeepThink
            </p>
          )}
          <ThinkingMessage messages={messages} />
          {isBoot && <BootProgressBar durationMs={bootDurationMs} />}
        </motion.div>
      </motion.div>
    </div>
  )
}

export { BOOT_MESSAGES, THINKING_MESSAGES }
