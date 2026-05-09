import type { ReactNode } from 'react'
import { TourHeaderOverlapContext } from './tourHeaderOverlapContext'

export function TourHeaderOverlapProvider({
  tourHeaderCollapsed,
  tourChromeInset,
  setTourChromeInset,
  children,
}: {
  tourHeaderCollapsed: boolean
  tourChromeInset: number
  setTourChromeInset: (insetPx: number) => void
  children: ReactNode
}) {
  return (
    <TourHeaderOverlapContext.Provider
      value={{ tourHeaderCollapsed, tourChromeInset, setTourChromeInset }}
    >
      {children}
    </TourHeaderOverlapContext.Provider>
  )
}
