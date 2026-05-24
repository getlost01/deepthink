import { motion, useReducedMotion } from 'framer-motion'
import type { ReactNode } from 'react'
import { easeOut } from './landingMotionVariants'

export function HeroBackdrop() {
  const prefersReducedMotion = useReducedMotion()

  return (
    <motion.div
      aria-hidden
      className="pointer-events-none absolute inset-0 -z-10 overflow-hidden"
      initial={false}
    >
      <motion.div
        className="absolute inset-0 bg-[radial-gradient(circle_at_50%_-10%,rgba(124,58,237,0.28),rgba(9,9,11,0.15)_42%,rgba(9,9,11,1)_72%)]"
        animate={
          prefersReducedMotion ? undefined : { opacity: [0.85, 1, 0.85] }
        }
        transition={{ duration: 8, repeat: Infinity, ease: 'easeInOut' }}
      />
      <div className="absolute inset-0 opacity-[0.35] [background-image:linear-gradient(rgba(255,255,255,0.04)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.04)_1px,transparent_1px)] [background-size:48px_48px] [mask-image:radial-gradient(ellipse_at_center,black_20%,transparent_75%)]" />
      <motion.div
        className="absolute -right-28 top-10 h-96 w-96 rounded-full bg-purple-500/30 blur-3xl"
        animate={
          prefersReducedMotion
            ? undefined
            : { opacity: [0.3, 0.55, 0.3], scale: [1, 1.08, 1], x: [0, -16, 0] }
        }
        transition={{ duration: 10, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="absolute -left-24 bottom-8 h-72 w-72 rounded-full bg-cyan-500/20 blur-3xl"
        animate={
          prefersReducedMotion
            ? undefined
            : { opacity: [0.2, 0.45, 0.2], y: [0, -20, 0] }
        }
        transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="absolute left-1/2 top-1/3 h-56 w-56 -translate-x-1/2 rounded-full bg-violet-400/10 blur-3xl"
        animate={
          prefersReducedMotion
            ? undefined
            : { scale: [1, 1.15, 1], opacity: [0.15, 0.35, 0.15] }
        }
        transition={{ duration: 14, repeat: Infinity, ease: 'easeInOut' }}
      />
    </motion.div>
  )
}

export function SectionLabel({
  children,
  className = '',
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <motion.p
      className={`text-xs font-semibold uppercase tracking-widest text-purple-300 ${className}`.trim()}
      initial={{ opacity: 0, x: -8 }}
      whileInView={{ opacity: 1, x: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.45, ease: easeOut }}
    >
      <span className="relative inline-block">
        {children}
        <motion.span
          aria-hidden
          className="absolute -bottom-1.5 left-0 h-px bg-gradient-to-r from-purple-400/80 to-transparent"
          initial={{ width: 0 }}
          whileInView={{ width: '100%' }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.15, ease: easeOut }}
        />
      </span>
    </motion.p>
  )
}

export function GlowCard({
  children,
  className = '',
  delay = 0,
}: {
  children: ReactNode
  className?: string
  delay?: number
}) {
  const prefersReducedMotion = useReducedMotion()

  return (
    <motion.div
      className={`group relative ${className}`.trim()}
      initial={{ opacity: 0, y: 18 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.5, delay, ease: easeOut }}
      whileHover={
        prefersReducedMotion
          ? undefined
          : { y: -5, transition: { duration: 0.22 } }
      }
    >
      <div
        aria-hidden
        className="pointer-events-none absolute -inset-px rounded-[inherit] bg-gradient-to-br from-purple-500/0 via-purple-500/0 to-cyan-400/0 opacity-0 blur-sm transition-opacity duration-500 group-hover:from-purple-500/25 group-hover:via-purple-500/10 group-hover:to-cyan-400/20 group-hover:opacity-100"
      />
      {children}
    </motion.div>
  )
}

export function AnimatedStatValue({ value }: { value: string }) {
  const prefersReducedMotion = useReducedMotion()

  return (
    <motion.p
      className="bg-gradient-to-br from-white via-purple-100 to-cyan-200 bg-clip-text text-2xl font-semibold text-transparent"
      initial={prefersReducedMotion ? false : { opacity: 0, scale: 0.92 }}
      whileInView={{ opacity: 1, scale: 1 }}
      viewport={{ once: true }}
      transition={{ type: 'spring', stiffness: 260, damping: 22 }}
    >
      {value}
    </motion.p>
  )
}
