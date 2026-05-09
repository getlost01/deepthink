import {
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { Link, useLocation } from 'react-router-dom'
import { REPO_RELEASES_LATEST_URL, REPO_URL } from '../constants/repo'
import { GithubStatsProvider } from '../contexts/GithubStatsProvider'
import { TourHeaderOverlapProvider } from '../contexts/TourHeaderOverlapProvider'
import ExternalLink from './ExternalLink'
import SiteHeader from './SiteHeader'

const linkBase = 'cursor-pointer transition'

function SiteFooter() {
  const year = new Date().getFullYear()

  return (
    <footer className="mt-auto border-t border-white/10 bg-zinc-950/90 px-4 pb-[calc(3rem+env(safe-area-inset-bottom,0px))] pt-12 text-sm text-zinc-400 backdrop-blur-md sm:px-6">
      <div className="mx-auto grid max-w-6xl gap-10 md:grid-cols-[minmax(0,1.1fr)_auto] md:items-start md:justify-between md:gap-12">
        <div className="flex flex-col items-center gap-4 text-center md:items-start md:text-left">
          <Link
            to="/"
            className={`inline-flex items-center gap-2 font-medium text-zinc-200 transition hover:text-white ${linkBase}`}
          >
            <img
              src="/app-icon.png"
              alt=""
              className="h-7 w-7 rounded-lg"
              aria-hidden
            />
            DeepThink
          </Link>
          <p className="text-[11px] text-zinc-600">
            MIT License · © {year} DeepThink contributors
          </p>
        </div>
        <nav
          className="flex flex-wrap items-center justify-center gap-x-5 gap-y-2 md:max-w-xl md:justify-end"
          aria-label="Footer links"
        >
          <Link
            to="/documentation"
            className={`rounded-md px-1 py-0.5 transition hover:text-zinc-200 ${linkBase}`}
          >
            Documentation
          </Link>
          <Link
            to="/architecture"
            className={`rounded-md px-1 py-0.5 transition hover:text-zinc-200 ${linkBase}`}
          >
            Architecture
          </Link>
          <Link
            to="/#faq"
            className={`rounded-md px-1 py-0.5 transition hover:text-zinc-200 ${linkBase}`}
          >
            FAQ
          </Link>
          <Link
            to="/#tour"
            className={`rounded-md px-1 py-0.5 transition hover:text-zinc-200 ${linkBase}`}
          >
            Tour
          </Link>
          <ExternalLink
            href={REPO_URL}
            className={`whitespace-nowrap rounded-md px-1 py-0.5 hover:text-zinc-200 ${linkBase}`}
          >
            Repository
          </ExternalLink>
          <ExternalLink
            href={REPO_RELEASES_LATEST_URL}
            className={`whitespace-nowrap rounded-md px-1 py-0.5 hover:text-zinc-200 ${linkBase}`}
          >
            Releases
          </ExternalLink>
        </nav>
      </div>
    </footer>
  )
}

function useLandingTourOverlapViewport(): boolean {
  const location = useLocation()
  const [inOverlap, setInOverlap] = useState(false)

  useEffect(() => {
    if (location.pathname !== '/') {
      return undefined
    }
    let raf = 0
    const tick = () => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        const tour = document.getElementById('tour')
        if (!tour) {
          setInOverlap(false)
          return
        }
        const r = tour.getBoundingClientRect()
        setInOverlap(r.top < 24 && r.bottom > 96)
      })
    }

    tick()
    window.addEventListener('scroll', tick, { passive: true })
    window.addEventListener('resize', tick, { passive: true })
    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener('scroll', tick)
      window.removeEventListener('resize', tick)
    }
  }, [location.pathname])

  return location.pathname === '/' && inOverlap
}

export default function SiteLayout({ children }: { children: ReactNode }) {
  const location = useLocation()
  const headerRef = useRef<HTMLElement | null>(null)
  const [headerH, setHeaderH] = useState(72)
  const [tourChromeInset, setTourChromeInset] = useState(0)
  const tourHeaderCollapsed = useLandingTourOverlapViewport()

  useLayoutEffect(() => {
    const el = headerRef.current
    if (!el) return undefined
    const measure = () =>
      setHeaderH(Math.ceil(el.getBoundingClientRect().height))
    measure()
    const ro = new ResizeObserver(measure)
    ro.observe(el)
    return () => ro.disconnect()
  }, [location.pathname])

  const spacerHeight = tourHeaderCollapsed
    ? Math.max(tourChromeInset, 64)
    : headerH

  return (
    <GithubStatsProvider>
      <TourHeaderOverlapProvider
        tourHeaderCollapsed={tourHeaderCollapsed}
        tourChromeInset={tourChromeInset}
        setTourChromeInset={setTourChromeInset}
      >
        <main className="flex min-h-[100dvh] flex-col overflow-x-clip bg-zinc-950 text-zinc-100">
          <div
            aria-hidden
            style={{ height: spacerHeight }}
            className="shrink-0 transition-[height] duration-300 ease-out"
          />
          <SiteHeader
            ref={headerRef}
            tourHeaderCollapsed={tourHeaderCollapsed}
          />
          <div className="flex flex-1 flex-col">{children}</div>
          <SiteFooter />
        </main>
      </TourHeaderOverlapProvider>
    </GithubStatsProvider>
  )
}
