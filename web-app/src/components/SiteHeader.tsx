import { forwardRef, useEffect, useState } from 'react'
import { Link, NavLink } from 'react-router-dom'
import { Download, Menu, Star, X } from 'lucide-react'
import { REPO_RELEASES_LATEST_URL, REPO_URL } from '../constants/repo'
import { useGithubStats } from '../hooks/useGithubStatsContext'
import ExternalLink from './ExternalLink'
import GithubMark from './GithubMark'

const routeNavItems = [
  { to: '/documentation', label: 'Documentation' },
  { to: '/architecture', label: 'Architecture' },
] as const

const linkBase = 'cursor-pointer transition'

type SiteHeaderProps = { tourHeaderCollapsed: boolean }

const SiteHeader = forwardRef<HTMLElement, SiteHeaderProps>(function SiteHeader(
  { tourHeaderCollapsed },
  ref,
) {
  const [menuOpen, setMenuOpen] = useState(false)
  const { starsLabel, loading } = useGithubStats()

  useEffect(() => {
    if (!menuOpen) return undefined
    const prevOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = prevOverflow
    }
  }, [menuOpen])

  useEffect(() => {
    if (!menuOpen) return undefined
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setMenuOpen(false)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [menuOpen])

  return (
    <header
      ref={ref}
      className={`fixed left-0 right-0 top-0 z-50 border-b border-white/10 bg-black/40 pt-[env(safe-area-inset-top,0px)] backdrop-blur-xl transition-[transform] duration-300 ease-out will-change-transform ${
        tourHeaderCollapsed
          ? '-translate-y-full pointer-events-none'
          : 'translate-y-0'
      }`}
    >
      <nav className="mx-auto flex w-full max-w-6xl items-center justify-between gap-3 px-4 py-4 sm:gap-4 sm:px-6">
        <Link
          to="/"
          className={`flex min-w-0 shrink items-center gap-2 text-base font-semibold text-white sm:text-lg ${linkBase}`}
          aria-label="DeepThink — Home"
          onClick={() => setMenuOpen(false)}
        >
          <img
            src="/app-icon.png"
            alt=""
            className="h-8 w-8 shrink-0 rounded-lg"
            aria-hidden
          />
          <span className="truncate">DeepThink</span>
        </Link>

        <div className="flex flex-1 items-center justify-end gap-3 sm:gap-4 lg:gap-6">
          <div className="hidden items-center gap-6 text-sm text-zinc-300 lg:flex">
            {routeNavItems.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) =>
                  `whitespace-nowrap ${linkBase} hover:text-white ${isActive ? 'text-white' : 'text-zinc-300'}`
                }
              >
                {item.label}
              </NavLink>
            ))}
          </div>

          <div className="flex items-center gap-2">
            <ExternalLink
              href={REPO_URL}
              className={`!hidden shrink-0 items-center gap-2 rounded-lg border border-[#30363d] bg-[#161b22] px-3 py-2 text-[13px] font-semibold tracking-tight text-zinc-100 shadow-[inset_0_1px_0_0_rgba(255,255,255,0.06)] transition hover:border-[#8b949e] hover:bg-[#21262d] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500/50 lg:!inline-flex ${linkBase}`}
              aria-label={`DeepThink on GitHub${starsLabel ? `, ${starsLabel} stars` : ''}`}
              withIcon={false}
            >
              <GithubMark className="h-[17px] w-[17px] shrink-0 text-white" />
              <span aria-hidden className="h-5 w-px shrink-0 bg-[#30363d]" />
              <span className="inline-flex items-center gap-1.5 text-white">
                <Star
                  size={15}
                  strokeWidth={0}
                  className="fill-[#e3b341] text-[#e3b341]"
                />
                <span className="tabular-nums leading-none">
                  {loading ? '…' : (starsLabel ?? '—')}
                </span>
              </span>
              <span className="hidden text-[11px] font-semibold uppercase leading-none text-[#8b949e] lg:inline">
                Star
              </span>
            </ExternalLink>

            <ExternalLink
              href={REPO_RELEASES_LATEST_URL}
              className={`btn btn-sm !hidden lg:!inline-flex items-center gap-2 border-none bg-white text-black hover:bg-zinc-200 ${linkBase}`}
              withIcon={false}
            >
              <Download size={16} aria-hidden />
              Download
            </ExternalLink>

            <button
              type="button"
              aria-expanded={menuOpen}
              aria-label={menuOpen ? 'Close menu' : 'Open menu'}
              className={`btn btn-ghost min-h-11 min-w-11 border-0 text-zinc-200 lg:hidden ${linkBase}`}
              onClick={() => setMenuOpen((o) => !o)}
            >
              {menuOpen ? <X size={22} /> : <Menu size={22} />}
            </button>
          </div>
        </div>
      </nav>

      {menuOpen ? (
        <div className="max-h-[min(70dvh,calc(100dvh-5rem))] overflow-y-auto overscroll-contain border-t border-white/10 bg-zinc-950/95 px-4 py-4 pb-[max(1rem,env(safe-area-inset-bottom,0px))] sm:px-6 lg:hidden">
          <div className="flex flex-col gap-1 text-sm">
            {routeNavItems.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                onClick={() => setMenuOpen(false)}
                className={({ isActive }) =>
                  `min-h-11 rounded-lg px-3 py-2.5 ${linkBase} hover:bg-white/5 ${isActive ? 'bg-white/10 text-white' : 'text-zinc-300'}`
                }
              >
                {item.label}
              </NavLink>
            ))}
            <div className="mt-3 flex flex-col gap-2 border-t border-white/10 pt-3 sm:flex-row sm:flex-wrap">
              <ExternalLink
                href={REPO_RELEASES_LATEST_URL}
                className={`btn btn-sm flex min-h-11 flex-1 items-center gap-2 border-none bg-white text-black hover:bg-zinc-200 sm:flex-none ${linkBase}`}
                withIcon={false}
                onClick={() => setMenuOpen(false)}
              >
                <Download size={16} aria-hidden />
                Download
              </ExternalLink>
            </div>
          </div>
        </div>
      ) : null}
    </header>
  )
})

export default SiteHeader
