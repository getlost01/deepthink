import { useEffect, useState } from 'react'
import { REPO_API_URL, REPO_FULL_NAME } from '../constants/repo'
import type { GithubRepoStatsContextValue } from './useGithubStatsContext'

const GITHUB_STATS_CACHE_KEY = `deepthink-github-repo-stats:${REPO_FULL_NAME}`
const GITHUB_STATS_CACHE_TTL_MS = 24 * 60 * 60 * 1000

type CachedStatsPayload = {
  cachedAt: number
  stars?: unknown
  forks?: unknown
}

interface GitHubRepoApiJson {
  stargazers_count?: unknown
  forks_count?: unknown
}

function readGithubStatsCache(): Pick<
  GithubRepoStatsContextValue,
  'stars' | 'forks'
> | null {
  try {
    if (typeof window === 'undefined') return null
    const raw = window.localStorage.getItem(GITHUB_STATS_CACHE_KEY)
    if (!raw) return null
    const payload = JSON.parse(raw) as CachedStatsPayload
    const isFresh = Date.now() - payload.cachedAt < GITHUB_STATS_CACHE_TTL_MS
    if (!isFresh) {
      window.localStorage.removeItem(GITHUB_STATS_CACHE_KEY)
      return null
    }
    const { stars, forks } = payload
    if (typeof stars !== 'number' && stars !== null) return null
    if (typeof forks !== 'number' && forks !== null) return null
    return { stars, forks }
  } catch {
    return null
  }
}

function writeGithubStatsCache(
  stars: number | null,
  forks: number | null,
): void {
  try {
    window.localStorage.setItem(
      GITHUB_STATS_CACHE_KEY,
      JSON.stringify({ cachedAt: Date.now(), stars, forks }),
    )
  } catch {
    /* private mode / quota */
  }
}

function formatCompact(n: number | null): string | null {
  if (n == null || Number.isNaN(n)) return null
  if (n >= 10000) return `${Math.round(n / 1000)}k`
  if (n >= 1000) return `${(n / 1000).toFixed(1).replace(/\.0$/, '')}k`
  return String(n)
}

type RepoStatsState = Pick<
  GithubRepoStatsContextValue,
  'stars' | 'forks' | 'loading' | 'failed'
>

export function useGitHubRepoStats(): GithubRepoStatsContextValue {
  const [state, setState] = useState<RepoStatsState>(() => {
    const cached = readGithubStatsCache()
    if (cached) {
      return {
        stars: cached.stars,
        forks: cached.forks,
        loading: false,
        failed: false,
      }
    }
    return { stars: null, forks: null, loading: true, failed: false }
  })

  useEffect(() => {
    if (readGithubStatsCache()) return

    const ac = new AbortController()
    async function load() {
      try {
        const res = await fetch(REPO_API_URL, {
          signal: ac.signal,
          headers: { Accept: 'application/vnd.github+json' },
        })
        if (!res.ok) throw new Error(String(res.status))
        const json = (await res.json()) as GitHubRepoApiJson
        if (ac.signal.aborted) return
        const stars =
          typeof json.stargazers_count === 'number'
            ? json.stargazers_count
            : null
        const forks =
          typeof json.forks_count === 'number' ? json.forks_count : null
        writeGithubStatsCache(stars, forks)
        setState({
          stars,
          forks,
          loading: false,
          failed: false,
        })
      } catch {
        if (ac.signal.aborted) return
        setState((s) => ({ ...s, loading: false, failed: true }))
      }
    }
    load()
    return () => ac.abort()
  }, [])

  return {
    stars: state.stars,
    forks: state.forks,
    starsLabel: formatCompact(state.stars),
    forksLabel: formatCompact(state.forks),
    loading: state.loading,
    failed: state.failed,
  }
}
