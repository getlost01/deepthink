import {
  ArrowRight,
  Command,
  Database,
  Download,
  NotebookPen,
  Search,
  ShieldCheck,
  Zap,
} from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import {
  AnimatePresence,
  motion,
  useMotionValueEvent,
  useReducedMotion,
  useScroll,
  type Variants,
} from 'framer-motion'
import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from 'react'
import { Link } from 'react-router-dom'
import { REPO_RELEASES_LATEST_URL } from '../constants/repo'
import { useTourHeaderOverlap } from '../hooks/useTourHeaderOverlap'
import { landingContent } from '../content/landingContent'
import ExternalLink from './ExternalLink'
import SiteLayout from './SiteLayout'

const pointerLink = 'cursor-pointer transition'

const iconMap: Record<string, LucideIcon> = {
  Zap,
  Command,
  Database,
  Search,
  NotebookPen,
  ShieldCheck,
}

const fadeUpStagger: Variants = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.07, delayChildren: 0.04 },
  },
}

const fadeUpItem: Variants = {
  hidden: { opacity: 0, y: 16 },
  show: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: [0.22, 1, 0.36, 1] },
  },
}

function HeroSection() {
  const { hero } = landingContent

  return (
    <section className="relative overflow-hidden px-4 pb-16 pt-20 sm:px-6 md:pb-20 md:pt-24">
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top,rgba(124,58,237,0.25),rgba(9,9,11,0.2)_30%,rgba(9,9,11,1)_70%)]" />
      <motion.div
        aria-hidden
        className="pointer-events-none absolute -right-24 top-16 h-80 w-80 rounded-full bg-purple-500/25 blur-3xl md:-right-32"
        animate={{ opacity: [0.35, 0.55, 0.35], scale: [1, 1.06, 1] }}
        transition={{ duration: 9, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        aria-hidden
        className="pointer-events-none absolute -left-20 bottom-0 h-64 w-64 rounded-full bg-cyan-500/15 blur-3xl"
        animate={{ opacity: [0.25, 0.45, 0.25], x: [0, 12, 0] }}
        transition={{ duration: 11, repeat: Infinity, ease: 'easeInOut' }}
      />
      <div className="mx-auto max-w-6xl">
        <motion.span
          initial={{ opacity: 0, y: 8 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="inline-flex rounded-full border border-purple-400/40 bg-purple-500/10 px-4 py-1 text-xs font-medium text-purple-200"
        >
          {hero.badge}
        </motion.span>
        <motion.h1
          initial={{ opacity: 0, y: 14 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="mt-6 max-w-4xl text-pretty text-3xl font-semibold leading-tight tracking-tight text-white md:text-4xl lg:text-5xl"
        >
          {hero.title}
        </motion.h1>
        <motion.p
          initial={{ opacity: 0, y: 18 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="mt-6 max-w-2xl text-sm text-zinc-300 md:text-base"
        >
          {hero.subtitle}
        </motion.p>

        <div className="mt-8 flex w-full max-w-md flex-col gap-3 sm:max-w-none sm:flex-row sm:flex-wrap sm:gap-4">
          <ExternalLink
            href={hero.primaryCta.href}
            className={`btn inline-flex min-h-11 w-full items-center justify-center gap-2 border-none bg-white text-black hover:bg-zinc-200 sm:w-auto ${pointerLink}`}
            withIcon={false}
          >
            <Download size={16} aria-hidden />
            {hero.primaryCta.label}
          </ExternalLink>
          <Link
            to={hero.secondaryCta.to}
            className={`btn inline-flex min-h-11 w-full items-center justify-center gap-2 border border-white/20 bg-white/5 text-white hover:bg-white/10 sm:w-auto ${pointerLink}`}
          >
            {hero.secondaryCta.label}
            <ArrowRight size={16} aria-hidden />
          </Link>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 18 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="mt-10 overflow-hidden rounded-2xl border border-white/10 bg-black/40 p-2"
        >
          <img
            src="/images/settings.png"
            alt="DeepThink workspace overview"
            className="h-auto w-full rounded-xl object-cover"
          />
        </motion.div>

        <motion.div
          className="mt-8 grid gap-4 sm:grid-cols-3"
          variants={fadeUpStagger}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: '-40px' }}
        >
          {hero.stats.map((stat) => (
            <motion.div
              key={stat.label}
              variants={fadeUpItem}
              whileHover={{ y: -3, transition: { duration: 0.2 } }}
              className="rounded-2xl border border-white/10 bg-white/5 p-5 transition-shadow duration-300 hover:border-white/15 hover:shadow-lg hover:shadow-purple-500/10"
            >
              <p className="text-2xl font-semibold text-white">{stat.value}</p>
              <p className="mt-1 text-sm text-zinc-300">{stat.label}</p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}

function WhyLocalFirstSection() {
  const { whyLocalFirst } = landingContent

  return (
    <section id="why-local-first" className="px-4 py-14 sm:px-6 md:py-20">
      <div className="mx-auto max-w-6xl">
        <motion.div
          className="mb-10 max-w-3xl space-y-4"
          initial={{ opacity: 0, y: 18 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
        >
          <p className="text-xs font-semibold uppercase tracking-widest text-purple-300">
            Design principles
          </p>
          <h2 className="text-2xl font-semibold text-white md:text-4xl">
            {whyLocalFirst.title}
          </h2>
          <p className="text-base leading-relaxed text-zinc-400 md:text-lg">
            {whyLocalFirst.subtitle}
          </p>
        </motion.div>
        <motion.ul
          className="grid list-none gap-4 p-0 md:grid-cols-3"
          variants={fadeUpStagger}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true }}
        >
          {whyLocalFirst.points.map((point) => (
            <motion.li key={point.title} variants={fadeUpItem}>
              <article className="group flex h-full flex-col rounded-2xl border border-white/10 bg-gradient-to-b from-white/[0.05] to-white/[0.02] p-6 transition-colors duration-300 hover:border-purple-400/30">
                <div className="h-1 w-10 rounded-full bg-gradient-to-r from-purple-300 to-cyan-300 opacity-80 transition-opacity group-hover:opacity-100" />
                <h3 className="mt-5 text-lg font-semibold text-white">
                  {point.title}
                </h3>
                <p className="mt-3 flex-1 text-sm leading-relaxed text-zinc-400">
                  {point.body}
                </p>
              </article>
            </motion.li>
          ))}
        </motion.ul>
      </div>
    </section>
  )
}

function SnapshotSection() {
  const { snapshot } = landingContent

  return (
    <section className="border-y border-white/10 bg-white/[0.02] px-4 py-14 sm:px-6 md:py-20">
      <div className="mx-auto max-w-6xl space-y-10">
        <motion.header
          className="text-left"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
        >
          <p className="text-xs font-semibold uppercase tracking-widest text-purple-300">
            {snapshot.title}
          </p>
          <p className="mt-4 max-w-3xl text-lg leading-relaxed text-zinc-300 md:text-xl">
            {snapshot.intro}
          </p>
          <motion.ul
            className="mt-6 flex list-none flex-wrap gap-2 p-0"
            variants={fadeUpStagger}
            initial="hidden"
            whileInView="show"
            viewport={{ once: true }}
          >
            {snapshot.badges.map((badge) => (
              <motion.li key={badge} variants={fadeUpItem}>
                <span className="inline-flex rounded-full border border-white/15 bg-black/40 px-3 py-1 text-xs font-medium text-zinc-200">
                  {badge}
                </span>
              </motion.li>
            ))}
          </motion.ul>
        </motion.header>
        <motion.ul
          className="m-0 grid list-none gap-4 p-0 sm:grid-cols-2 lg:grid-cols-3 lg:gap-6"
          variants={fadeUpStagger}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: '-60px' }}
        >
          {snapshot.pillars.map((pillar) => (
            <motion.li
              key={pillar.title}
              className="min-w-0"
              variants={fadeUpItem}
            >
              <article className="flex h-full min-h-[10.5rem] flex-col rounded-2xl border border-white/10 bg-zinc-900/40 p-6 transition-colors duration-300 hover:border-white/18">
                <h2 className="text-lg font-semibold leading-snug text-white">
                  {pillar.title}
                </h2>
                <p className="mt-3 flex-1 text-sm leading-relaxed text-zinc-400">
                  {pillar.description}
                </p>
              </article>
            </motion.li>
          ))}
        </motion.ul>
      </div>
    </section>
  )
}

function FeaturesSection() {
  const { features } = landingContent

  return (
    <section id="capabilities" className="px-4 py-14 sm:px-6 md:py-20">
      <div className="mx-auto max-w-6xl">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
        >
          <h2 className="text-2xl font-semibold text-white md:text-4xl">
            {landingContent.sections.capabilities.title}
          </h2>
          <p className="mt-4 max-w-2xl text-zinc-400">
            {landingContent.sections.capabilities.subtitle}
          </p>
        </motion.div>
        <motion.div
          className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3"
          variants={fadeUpStagger}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: '-40px' }}
        >
          {features.map((feature) => {
            const Icon = iconMap[feature.icon] ?? Zap

            return (
              <motion.article
                key={feature.title}
                variants={fadeUpItem}
                whileHover={{ y: -4, transition: { duration: 0.2 } }}
                className="rounded-2xl border border-white/10 bg-white/[0.03] p-6 transition-shadow duration-300 hover:border-white/15 hover:shadow-lg hover:shadow-black/40"
              >
                <motion.span
                  className="inline-flex rounded-lg border border-white/10 bg-black/30 p-2 text-purple-300"
                  whileHover={{ scale: 1.08 }}
                  transition={{ type: 'spring', stiffness: 420, damping: 20 }}
                >
                  <Icon size={18} aria-hidden />
                </motion.span>
                <h3 className="mt-4 text-lg font-medium text-white">
                  {feature.title}
                </h3>
                <p className="mt-2 text-sm text-zinc-400">
                  {feature.description}
                </p>
              </motion.article>
            )
          })}
        </motion.div>
      </div>
    </section>
  )
}

function PlatformContextSection() {
  return (
    <section className="px-4 py-14 sm:px-6 md:py-20">
      <div className="mx-auto max-w-6xl">
        <motion.div
          className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between"
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
        >
          <div>
            <h2 className="text-2xl font-semibold text-white md:text-4xl">
              {landingContent.sections.appCliMcp.title}
            </h2>
            <p className="mt-4 max-w-2xl text-zinc-400">
              {landingContent.sections.appCliMcp.subtitle} Architecture diagram
              shows how they connect.
            </p>
          </div>
          <motion.div
            whileHover={{ x: 3 }}
            transition={{ type: 'spring', stiffness: 380, damping: 22 }}
          >
            <Link
              to="/architecture"
              className={`inline-flex shrink-0 text-sm font-medium text-purple-300 transition hover:text-purple-200 ${pointerLink}`}
            >
              View architecture diagram →
            </Link>
          </motion.div>
        </motion.div>
        <motion.div
          className="mt-8 grid gap-4 md:grid-cols-3"
          variants={fadeUpStagger}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: '-50px' }}
        >
          {landingContent.platformContext.map((item) => (
            <motion.article
              key={item.title}
              variants={fadeUpItem}
              className="rounded-2xl border border-white/10 bg-white/[0.03] p-6 transition-colors duration-300 hover:border-purple-400/25"
            >
              <h3 className="text-lg font-semibold text-white">{item.title}</h3>
              <p className="mt-3 text-sm text-zinc-400">{item.description}</p>
              <ul className="mt-4 space-y-2">
                {item.points.map((point) => (
                  <li
                    key={point}
                    className="rounded-lg border border-white/10 bg-black/30 px-3 py-2 text-xs text-zinc-300"
                  >
                    {point}
                  </li>
                ))}
              </ul>
            </motion.article>
          ))}
        </motion.div>
      </div>
    </section>
  )
}

function ProductTourSection() {
  const { productTour } = landingContent
  const { steps, title: tourTitle, subtitle: tourSubtitle } = productTour
  const { tourHeaderCollapsed, tourChromeInset, setTourChromeInset } =
    useTourHeaderOverlap()
  const prefersReducedMotion = useReducedMotion()

  const sectionRef = useRef<HTMLElement | null>(null)
  const tourChromeRef = useRef<HTMLDivElement | null>(null)
  const prevIndexRef = useRef(0)
  const [activeIndex, setActiveIndex] = useState(0)
  const [direction, setDirection] = useState(1)
  const [tourInView, setTourInView] = useState(false)
  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ['start start', 'end end'],
  })

  useEffect(() => {
    const el = sectionRef.current
    if (!el) return undefined
    const io = new IntersectionObserver(
      ([entry]) => {
        setTourInView(entry.isIntersecting && entry.intersectionRatio > 0.08)
      },
      { threshold: [0, 0.08, 0.2, 0.5] },
    )
    io.observe(el)
    return () => io.disconnect()
  }, [])

  useMotionValueEvent(scrollYProgress, 'change', (progress) => {
    const total = steps.length
    if (total <= 1) return
    const p = Math.min(1, Math.max(0, progress))
    const next = Math.round(p * (total - 1))
    const prev = prevIndexRef.current
    if (next === prev) return
    setDirection(next > prev ? 1 : -1)
    prevIndexRef.current = next
    setActiveIndex(next)
  })

  const activeItem = steps[activeIndex]
  const tourLength = steps.length

  const scrollToStepIndex = useCallback(
    (i: number) => {
      const el = sectionRef.current
      if (!el) return
      const docTop = window.scrollY + el.getBoundingClientRect().top
      const scrollRange = Math.max(0, el.offsetHeight - window.innerHeight)
      const denom = Math.max(1, tourLength - 1)
      const y = docTop + (i / denom) * scrollRange
      window.scrollTo({ top: y, behavior: 'smooth' })
    },
    [tourLength],
  )

  useEffect(() => {
    if (!tourInView) return undefined
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.defaultPrevented) return
      const t = e.target as Node | null
      if (
        t &&
        (t as HTMLElement).closest?.(
          'input, textarea, [contenteditable="true"]',
        )
      )
        return
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
        e.preventDefault()
        if (activeIndex < tourLength - 1) scrollToStepIndex(activeIndex + 1)
      } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
        e.preventDefault()
        if (activeIndex > 0) scrollToStepIndex(activeIndex - 1)
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [tourInView, activeIndex, tourLength, scrollToStepIndex])

  useLayoutEffect(() => {
    if (!tourHeaderCollapsed || !tourChromeRef.current) return undefined
    const el = tourChromeRef.current
    const publish = () =>
      setTourChromeInset(Math.ceil(el.getBoundingClientRect().height))
    publish()
    const ro = new ResizeObserver(publish)
    ro.observe(el)
    return () => ro.disconnect()
  }, [tourHeaderCollapsed, setTourChromeInset, activeIndex, tourLength])

  const tourChrome = tourHeaderCollapsed ? (
    <div
      ref={tourChromeRef}
      className="fixed left-0 right-0 top-0 z-[45] bg-zinc-950 px-4 pb-3 pt-[calc(0.75rem+env(safe-area-inset-top,0px))] sm:px-6"
    >
      <div className="mx-auto flex max-w-6xl flex-col gap-3">
        <div className="flex items-center justify-between gap-4">
          <div className="h-1.5 min-w-0 flex-1 overflow-hidden rounded-full bg-white/10">
            <motion.div
              className="h-full rounded-full bg-gradient-to-r from-purple-300 to-cyan-300"
              animate={{ width: `${((activeIndex + 1) / tourLength) * 100}%` }}
              transition={{ duration: 0.35, ease: 'easeOut' }}
            />
          </div>
          <p className="shrink-0 text-xs font-medium tabular-nums tracking-wider text-zinc-300">
            Step {activeIndex + 1} / {tourLength}
          </p>
        </div>
        <div
          className="flex max-h-[38dvh] flex-wrap gap-2 overflow-y-auto overscroll-contain sm:max-h-none sm:overflow-visible"
          role="tablist"
          aria-label="Product tour steps"
        >
          {steps.map((step, i) => (
            <button
              key={step.title}
              type="button"
              role="tab"
              aria-selected={i === activeIndex}
              className={`cursor-pointer rounded-full border px-3 py-1.5 text-left text-xs font-medium transition ${
                i === activeIndex
                  ? 'border-purple-400/50 bg-purple-500/20 text-white'
                  : 'border-white/10 bg-white/[0.04] text-zinc-400 hover:border-white/20 hover:text-zinc-200'
              }`}
              onClick={() => scrollToStepIndex(i)}
            >
              {i + 1}. {step.title}
            </button>
          ))}
        </div>
      </div>
    </div>
  ) : null

  return (
    <section
      id="tour"
      ref={sectionRef}
      className="relative scroll-mt-24 px-4 py-12 sm:scroll-mt-28 sm:px-6 md:py-20"
      style={{ height: `${tourLength * 100}vh` }}
    >
      {tourChrome}
      <div className="mx-auto max-w-6xl">
        <h2 className="text-2xl font-semibold text-white md:text-4xl">
          {tourTitle}
        </h2>
        <p className="mt-4 max-w-2xl text-zinc-400">{tourSubtitle}</p>
      </div>

      <div
        className={`sticky mt-14 pb-10 transition-[top] duration-300 ease-out md:mt-20 ${
          tourHeaderCollapsed ? '' : 'top-20 md:top-24'
        }`}
        style={tourHeaderCollapsed ? { top: tourChromeInset } : undefined}
      >
        <div className="mx-auto w-full max-w-6xl">
          <AnimatePresence mode="wait" initial={false} custom={direction}>
            <motion.article
              key={activeItem.title}
              custom={direction}
              initial={
                prefersReducedMotion
                  ? { opacity: 0 }
                  : { opacity: 0, y: direction > 0 ? 18 : -18, scale: 0.995 }
              }
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={
                prefersReducedMotion
                  ? { opacity: 0 }
                  : { opacity: 0, y: direction > 0 ? -14 : 14, scale: 0.995 }
              }
              transition={
                prefersReducedMotion
                  ? { duration: 0.18 }
                  : { duration: 0.42, ease: [0.22, 1, 0.36, 1] }
              }
              className="flex flex-col gap-5 rounded-3xl border border-white/[0.09] bg-gradient-to-b from-white/[0.045] to-white/[0.015] p-4 shadow-[0_28px_90px_-36px_rgba(0,0,0,0.75),0_0_0_1px_rgba(255,255,255,0.04)_inset] md:gap-6 md:p-6"
            >
              <p className="max-w-2xl text-xs leading-relaxed text-zinc-300 md:text-sm">
                {activeItem.description}
              </p>
              <figure className="m-0 w-full">
                <div className="relative rounded-[1.125rem] border border-white/[0.08] bg-zinc-950/45 p-1.5 shadow-[inset_0_1px_0_0_rgba(255,255,255,0.07)] md:p-2">
                  <motion.div
                    layout
                    className="relative flex min-h-[min(48dvh,520px)] items-center justify-center overflow-hidden rounded-xl bg-gradient-to-b from-zinc-900/98 to-zinc-950 ring-1 ring-white/[0.06]"
                    initial={{ opacity: prefersReducedMotion ? 1 : 0.94 }}
                    animate={{ opacity: 1 }}
                    transition={{ duration: prefersReducedMotion ? 0 : 0.35 }}
                  >
                    <span
                      aria-hidden
                      className="pointer-events-none absolute inset-x-0 top-0 z-10 h-px bg-gradient-to-r from-transparent via-white/20 to-transparent"
                    />
                    <span
                      aria-hidden
                      className="pointer-events-none absolute inset-x-8 -top-24 h-40 rounded-full bg-purple-500/12 blur-3xl"
                    />
                    <motion.img
                      src={activeItem.image}
                      alt={`${activeItem.title}, app screenshot`}
                      className="relative z-[1] mx-auto block h-auto w-full max-h-[min(76dvh,920px)] max-w-full object-contain object-center"
                      loading={activeIndex === 0 ? 'eager' : 'lazy'}
                      decoding="async"
                      fetchPriority={activeIndex === 0 ? 'high' : 'low'}
                      initial={
                        prefersReducedMotion
                          ? false
                          : { opacity: 0.88, scale: 1.008 }
                      }
                      animate={{ opacity: 1, scale: 1 }}
                      transition={{
                        duration: prefersReducedMotion ? 0 : 0.38,
                        ease: [0.22, 1, 0.36, 1],
                      }}
                    />
                  </motion.div>
                </div>
              </figure>
            </motion.article>
          </AnimatePresence>

          <div className="mt-6 flex justify-center">
            <nav
              className="flex flex-wrap justify-center gap-2"
              aria-label="Tour steps"
            >
              {steps.map((step, i) => (
                <button
                  key={step.title}
                  type="button"
                  aria-label={`Go to step ${i + 1}`}
                  aria-current={i === activeIndex ? 'true' : undefined}
                  onClick={() => scrollToStepIndex(i)}
                  className={`h-2.5 rounded-full transition-[width,background] duration-300 ${
                    i === activeIndex
                      ? 'w-8 bg-gradient-to-r from-purple-300 to-cyan-300'
                      : 'w-2.5 bg-white/20 hover:bg-white/35'
                  }`}
                />
              ))}
            </nav>
          </div>
        </div>
      </div>
    </section>
  )
}

function WorkflowSection() {
  return (
    <section className="px-4 py-14 sm:px-6 md:py-20">
      <motion.div
        className="mx-auto max-w-6xl rounded-3xl border border-white/10 bg-white/[0.03] p-6 sm:p-8 md:p-12"
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.55, ease: [0.22, 1, 0.36, 1] }}
      >
        <h2 className="text-2xl font-semibold text-white md:text-3xl">
          {landingContent.sections.workflow.title}
        </h2>
        <p className="mt-3 max-w-xl text-zinc-400">
          {landingContent.sections.workflow.subtitle}
        </p>
        <motion.div
          className="mt-8 grid gap-4 md:grid-cols-3"
          variants={fadeUpStagger}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true }}
        >
          {landingContent.workflow.map((item) => (
            <motion.article
              key={item.step}
              variants={fadeUpItem}
              className="rounded-xl border border-white/10 bg-black/30 p-5"
            >
              <p className="text-xs font-semibold tracking-widest text-purple-300">
                {item.step}
              </p>
              <h3 className="mt-3 text-lg font-semibold text-white">
                {item.title}
              </h3>
              <p className="mt-2 text-sm text-zinc-400">{item.description}</p>
            </motion.article>
          ))}
        </motion.div>
      </motion.div>
    </section>
  )
}

function FAQSection() {
  return (
    <section
      id="faq"
      className="scroll-mt-24 px-4 py-14 sm:scroll-mt-28 sm:px-6 md:py-20"
    >
      <div className="mx-auto max-w-6xl">
        <motion.h2
          className="mb-8 text-center text-2xl font-semibold text-white md:text-left md:text-3xl"
          initial={{ opacity: 0, y: 10 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.45 }}
        >
          FAQ
        </motion.h2>
        <motion.div
          className="grid gap-4 md:grid-cols-2"
          variants={fadeUpStagger}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: '-30px' }}
        >
          {landingContent.faqs.map((faq) => (
            <motion.details
              key={faq.question}
              variants={fadeUpItem}
              className="group rounded-xl border border-white/10 bg-white/[0.03] p-5 transition-colors open:border-purple-400/25"
            >
              <summary className="flex cursor-pointer list-none items-center justify-between gap-3 text-base font-medium text-white [&::-webkit-details-marker]:hidden">
                <span>{faq.question}</span>
                <span
                  className="text-zinc-500 transition-transform duration-300 group-open:rotate-180"
                  aria-hidden
                >
                  ▼
                </span>
              </summary>
              <p className="mt-3 text-sm leading-relaxed text-zinc-400">
                {faq.answer}
              </p>
            </motion.details>
          ))}
        </motion.div>
      </div>
    </section>
  )
}

function FinalCtaSection() {
  const { finalCta } = landingContent

  return (
    <section className="px-4 pb-[max(5rem,calc(5rem+env(safe-area-inset-bottom,0px)))] pt-4 sm:px-6">
      <motion.div
        className="relative mx-auto max-w-4xl overflow-hidden rounded-3xl border border-purple-300/25 bg-purple-500/10 p-6 text-center shadow-[0_0_80px_-20px_rgba(147,112,246,0.45)] sm:p-8 md:p-12"
        initial={{ opacity: 0, y: 24, scale: 0.985 }}
        whileInView={{ opacity: 1, y: 0, scale: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 0.55, ease: [0.22, 1, 0.36, 1] }}
      >
        <motion.div
          aria-hidden
          className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_30%_-20%,rgba(192,166,255,0.35),transparent_55%)]"
          animate={{ opacity: [0.45, 0.75, 0.45] }}
          transition={{ duration: 6, repeat: Infinity, ease: 'easeInOut' }}
        />
        <div className="relative space-y-4">
          <h2 className="text-2xl font-semibold text-white md:text-4xl">
            {finalCta.title}
          </h2>
          <p className="mx-auto max-w-xl text-zinc-300">{finalCta.subtitle}</p>
        </div>
        <div className="relative mt-8 flex w-full flex-col flex-wrap justify-center gap-3 sm:flex-row sm:gap-4">
          <motion.div whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.98 }}>
            <ExternalLink
              href={REPO_RELEASES_LATEST_URL}
              className={`btn inline-flex min-h-11 w-full items-center justify-center gap-2 border-none bg-white text-black hover:bg-zinc-200 sm:w-auto ${pointerLink}`}
              withIcon={false}
            >
              {finalCta.primaryLabel}
              <Download size={16} aria-hidden />
            </ExternalLink>
          </motion.div>
          <motion.div whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.98 }}>
            <Link
              to="/documentation"
              className={`btn inline-flex min-h-11 w-full items-center justify-center gap-2 border border-white/25 bg-transparent text-white hover:bg-white/10 sm:w-auto ${pointerLink}`}
            >
              {finalCta.secondaryLabel}
              <ArrowRight size={16} aria-hidden />
            </Link>
          </motion.div>
        </div>
      </motion.div>
    </section>
  )
}

export default function LandingPage() {
  return (
    <SiteLayout>
      <HeroSection />
      <SnapshotSection />
      <WhyLocalFirstSection />
      <FeaturesSection />
      <PlatformContextSection />
      <ProductTourSection />
      <WorkflowSection />
      <FAQSection />
      <FinalCtaSection />
    </SiteLayout>
  )
}
