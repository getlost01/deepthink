import { createContext, useContext } from 'react'

export type GithubRepoStatsContextValue = {
  stars: number | null
  forks: number | null
  starsLabel: string | null
  forksLabel: string | null
  loading: boolean
  failed: boolean
}

export const GithubStatsContext =
  createContext<GithubRepoStatsContextValue | null>(null)

export function useGithubStats(): GithubRepoStatsContextValue {
  const ctx = useContext(GithubStatsContext)
  if (!ctx)
    throw new Error('useGithubStats must be used within GithubStatsProvider')
  return ctx
}
