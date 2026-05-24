import { motion } from 'framer-motion'
import { ArrowRight, Download } from 'lucide-react'
import { Link } from 'react-router-dom'
import { ReactFlowProvider } from '@xyflow/react'
import ArchitectureFlowGraph from '../components/ArchitectureFlowGraph'
import ExternalLink from '../components/ExternalLink'
import {
  AnimatedStatValue,
  GlowCard,
  HeroBackdrop,
  SectionLabel,
} from '../components/landing/landingMotion'
import {
  fadeUpItem,
  fadeUpStagger,
} from '../components/landing/landingMotionVariants'
import SiteLayout from '../components/SiteLayout'
import { architectureContent } from '../content/architectureContent'
import { REPO_RELEASES_LATEST_URL, REPO_URL } from '../constants/repo'

const pointerLink = 'cursor-pointer transition'

const accentShell: Record<string, string> = {
  violet:
    'border-violet-400/30 bg-violet-500/10 shadow-[0_0_40px_-20px_rgba(139,92,246,0.35)]',
  emerald:
    'border-emerald-400/30 bg-emerald-500/10 shadow-[0_0_40px_-20px_rgba(52,211,153,0.25)]',
  teal: 'border-teal-400/30 bg-teal-500/10 shadow-[0_0_40px_-20px_rgba(45,212,191,0.25)]',
}

const accentTitle: Record<string, string> = {
  violet: 'text-violet-200',
  emerald: 'text-emerald-200',
  teal: 'text-teal-200',
}

export default function ArchitecturePage() {
  const { hero, surfaces, dataLayer, governance, rag, diagram } =
    architectureContent

  return (
    <SiteLayout>
      <section
        data-testid="architecture-hero"
        className="relative overflow-hidden px-4 pb-10 pt-14 sm:px-6 md:pb-14 md:pt-20"
      >
        <HeroBackdrop />
        <div className="relative mx-auto max-w-6xl text-center">
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.55 }}
          >
            <SectionLabel>System design</SectionLabel>
            <h1 className="mt-4 text-3xl font-semibold leading-tight text-white md:text-5xl">
              {hero.title}
            </h1>
            <p className="mx-auto mt-4 max-w-2xl text-sm leading-relaxed text-zinc-400 md:text-base">
              {hero.subtitle}
            </p>
            <motion.div
              className="mt-6 flex flex-wrap justify-center gap-3"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.12, duration: 0.45 }}
            >
              <ExternalLink
                href={REPO_URL}
                className={`inline-flex items-center gap-1 rounded-full border border-white/10 bg-black/30 px-4 py-1.5 text-xs text-zinc-300 backdrop-blur-sm hover:border-white/20 hover:text-white ${pointerLink}`}
                iconSize={12}
              >
                Repo &amp; source
              </ExternalLink>
              <ExternalLink
                href={REPO_RELEASES_LATEST_URL}
                className={`inline-flex items-center gap-1 rounded-full border border-white/10 bg-black/30 px-4 py-1.5 text-xs text-zinc-300 backdrop-blur-sm hover:border-white/20 hover:text-white ${pointerLink}`}
                iconSize={12}
              >
                <Download size={12} aria-hidden />
                Download app
              </ExternalLink>
              <Link
                to="/documentation"
                className={`inline-flex items-center gap-1 rounded-full border border-purple-400/30 bg-purple-500/10 px-4 py-1.5 text-xs text-purple-200 hover:border-purple-400/50 ${pointerLink}`}
              >
                Full docs
                <ArrowRight size={12} aria-hidden />
              </Link>
            </motion.div>
          </motion.div>

          <motion.div
            className="mt-10 grid gap-4 sm:grid-cols-3"
            variants={fadeUpStagger}
            initial="hidden"
            whileInView="show"
            viewport={{ once: true, margin: '-40px' }}
          >
            {hero.stats.map((stat, i) => (
              <GlowCard
                key={stat.label}
                delay={i * 0.06}
                className="rounded-2xl"
              >
                <article className="rounded-2xl border border-white/10 bg-white/[0.04] p-5 backdrop-blur-sm">
                  <AnimatedStatValue value={stat.value} />
                  <p className="mt-1 text-sm text-zinc-400">{stat.label}</p>
                </article>
              </GlowCard>
            ))}
          </motion.div>
        </div>
      </section>

      <section className="border-y border-white/10 bg-white/[0.02] px-4 py-14 sm:px-6 md:py-16">
        <motion.div
          className="mx-auto max-w-6xl"
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
        >
          <SectionLabel>Three surfaces</SectionLabel>
          <h2 className="mt-4 text-2xl font-semibold text-white md:text-3xl">
            One store, three ways in
          </h2>
          <motion.div
            className="mt-8 grid gap-4 lg:grid-cols-3"
            variants={fadeUpStagger}
            initial="hidden"
            whileInView="show"
            viewport={{ once: true, margin: '-40px' }}
          >
            {surfaces.map((surface) => (
              <motion.div key={surface.title} variants={fadeUpItem}>
                <article
                  className={`flex h-full flex-col rounded-2xl border p-6 ${accentShell[surface.accent]}`}
                >
                  <h3
                    className={`text-lg font-semibold ${accentTitle[surface.accent]}`}
                  >
                    {surface.title}
                  </h3>
                  <p className="mt-3 flex-1 text-sm leading-relaxed text-zinc-400">
                    {surface.description}
                  </p>
                  <ul className="mt-4 flex flex-wrap gap-2">
                    {surface.points.map((point) => (
                      <li
                        key={point}
                        className="rounded-lg border border-white/10 bg-black/30 px-2.5 py-1 font-mono text-[10px] text-zinc-300"
                      >
                        {point}
                      </li>
                    ))}
                  </ul>
                </article>
              </motion.div>
            ))}
          </motion.div>
        </motion.div>
      </section>

      <section className="px-4 py-14 sm:px-6 md:py-16">
        <motion.div
          className="mx-auto max-w-6xl"
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
        >
          <SectionLabel>{diagram.title}</SectionLabel>
          <p className="mt-4 max-w-2xl text-sm text-zinc-400 md:text-base">
            {diagram.hint}
          </p>
        </motion.div>
        <motion.div
          className="mx-auto mt-8 w-full max-w-6xl px-0"
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-60px' }}
          transition={{ duration: 0.6 }}
        >
          <ReactFlowProvider>
            <ArchitectureFlowGraph />
          </ReactFlowProvider>
        </motion.div>
        <p className="mx-auto mt-4 max-w-lg text-center text-[11px] text-zinc-600">
          Ship path: Bun builds{' '}
          <span className="font-mono text-zinc-500">deepthink</span> &amp;{' '}
          <span className="font-mono text-zinc-500">deepthink-mcp</span> →
          bundled with the macOS app and installed to ~/.local/bin on first
          launch.
        </p>
      </section>

      <section className="border-t border-white/10 bg-white/[0.02] px-4 py-14 sm:px-6 md:py-16">
        <motion.div
          className="mx-auto grid max-w-6xl gap-10 lg:grid-cols-2"
          variants={fadeUpStagger}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: '-40px' }}
        >
          <motion.div variants={fadeUpItem}>
            <SectionLabel>{dataLayer.title}</SectionLabel>
            <p className="mt-4 text-sm text-zinc-400">{dataLayer.subtitle}</p>
            <ul className="mt-6 space-y-3">
              {dataLayer.items.map((item) => (
                <li
                  key={item.path}
                  className="rounded-xl border border-white/10 bg-black/30 p-4"
                >
                  <p className="font-mono text-xs text-cyan-200">{item.path}</p>
                  <p className="mt-1.5 text-sm leading-relaxed text-zinc-500">
                    {item.description}
                  </p>
                </li>
              ))}
            </ul>
          </motion.div>

          <motion.div variants={fadeUpItem} className="space-y-8">
            <motion.div>
              <SectionLabel>{governance.title}</SectionLabel>
              <ul className="mt-6 space-y-3">
                {governance.items.map((item) => (
                  <li
                    key={item.title}
                    className="rounded-xl border border-white/10 bg-black/30 p-4"
                  >
                    <h3 className="text-sm font-semibold text-white">
                      {item.title}
                    </h3>
                    <p className="mt-1.5 text-sm leading-relaxed text-zinc-500">
                      {item.body}
                    </p>
                  </li>
                ))}
              </ul>
            </motion.div>

            <motion.div>
              <SectionLabel>{rag.title}</SectionLabel>
              <p className="mt-4 text-sm text-zinc-400">{rag.subtitle}</p>
              <ol className="mt-6 grid gap-2 sm:grid-cols-2">
                {rag.steps.map((step, i) => (
                  <li
                    key={step.label}
                    className="rounded-xl border border-fuchsia-400/20 bg-fuchsia-500/5 p-4"
                  >
                    <p className="text-[10px] font-semibold tracking-widest text-fuchsia-300">
                      {String(i + 1).padStart(2, '0')} · {step.label}
                    </p>
                    <p className="mt-1 text-sm text-zinc-400">{step.detail}</p>
                  </li>
                ))}
              </ol>
            </motion.div>
          </motion.div>
        </motion.div>
      </section>
    </SiteLayout>
  )
}
