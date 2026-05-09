import type { ReactNode } from 'react'
import { GithubStatsContext } from '../hooks/useGithubStatsContext'
import { useGitHubRepoStats } from '../hooks/useGitHubRepoStats'

export function GithubStatsProvider({ children }: { children: ReactNode }) {
  const value = useGitHubRepoStats()
  return (
    <GithubStatsContext.Provider value={value}>
      {children}
    </GithubStatsContext.Provider>
  )
}
