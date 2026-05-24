import { motion, type Variants } from 'framer-motion'
import { ReactFlowProvider } from '@xyflow/react'
import ArchitectureFlowGraph from '../components/ArchitectureFlowGraph'
import ExternalLink from '../components/ExternalLink'
import SiteLayout from '../components/SiteLayout'
import { REPO_RELEASES_LATEST_URL, REPO_URL } from '../constants/repo'

const archEase = [0.22, 1, 0.36, 1] as const

const staggerHeader: Variants = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.1, delayChildren: 0.06 },
  },
}

const fadeUpBlock: Variants = {
  hidden: { opacity: 0, y: 18 },
  show: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.52, ease: archEase },
  },
}

export default function ArchitecturePage() {
  return (
    <SiteLayout>
      <section className="relative overflow-hidden px-4 pb-4 pt-14 sm:px-6 md:pt-20">
        <motion.div
          aria-hidden
          className="pointer-events-none absolute left-1/2 top-0 h-56 w-[min(90vw,42rem)] -translate-x-1/2 rounded-full bg-purple-500/15 blur-3xl"
          initial={{ opacity: 0, scale: 0.92 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 1.1, ease: 'easeOut' }}
        />
        <motion.div
          className="relative mx-auto max-w-6xl text-center"
          variants={staggerHeader}
          initial="hidden"
          animate="show"
        >
          <motion.h1
            variants={fadeUpBlock}
            className="text-3xl font-semibold leading-tight text-white md:text-5xl"
          >
            How DeepThink fits together
          </motion.h1>
          <motion.p
            variants={fadeUpBlock}
            className="mx-auto mt-3 max-w-2xl text-sm text-zinc-400 md:text-base md:leading-relaxed"
          >
            One diagram: three surfaces, one disk, hybrid RAG. MCP and CLI are
            agent-agnostic - Claude is only needed for in-app AI chat. Zoom and
            drag; the labels are the documentation.
          </motion.p>
          <motion.div
            variants={fadeUpBlock}
            className="mt-6 flex flex-wrap justify-center gap-3 text-[11px] text-zinc-500"
          >
            <motion.span
              whileHover={{ scale: 1.03 }}
              whileTap={{ scale: 0.98 }}
              transition={{ type: 'spring', stiffness: 440, damping: 24 }}
            >
              <ExternalLink
                href={REPO_URL}
                className="inline-flex items-center gap-1 rounded-full border border-white/10 px-3 py-1 transition-colors hover:border-white/20 hover:text-zinc-300"
                iconSize={12}
              >
                Repo &amp; source
              </ExternalLink>
            </motion.span>
            <motion.span
              whileHover={{ scale: 1.03 }}
              whileTap={{ scale: 0.98 }}
              transition={{ type: 'spring', stiffness: 440, damping: 24 }}
            >
              <ExternalLink
                href={REPO_RELEASES_LATEST_URL}
                className="inline-flex items-center gap-1 rounded-full border border-white/10 px-3 py-1 transition-colors hover:border-white/20 hover:text-zinc-300"
                iconSize={12}
              >
                Download app
              </ExternalLink>
            </motion.span>
          </motion.div>
        </motion.div>
      </section>

      <section className="w-full pb-16">
        <motion.div
          className="mx-auto w-full max-w-5xl px-4 lg:max-w-6xl"
          initial={{ opacity: 0, y: 28 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-60px' }}
          transition={{ duration: 0.6, ease: archEase }}
        >
          <ReactFlowProvider>
            <ArchitectureFlowGraph />
          </ReactFlowProvider>
        </motion.div>
        <motion.p
          className="mx-auto mt-4 max-w-lg px-4 text-center text-[11px] text-zinc-600 sm:px-6"
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ delay: 0.18, duration: 0.45 }}
        >
          Ship path: Bun builds{' '}
          <span className="font-mono text-zinc-500">deepthink</span> &amp;{' '}
          <span className="font-mono text-zinc-500">deepthink-mcp</span> →
          bundled beside the macOS app and optionally ~/.local/bin.
        </motion.p>
      </section>
    </SiteLayout>
  )
}
