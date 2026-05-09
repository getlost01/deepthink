import { createContext } from 'react'

export type TourHeaderOverlapValue = {
  tourHeaderCollapsed: boolean
  tourChromeInset: number
  setTourChromeInset: (insetPx: number) => void
}

export const TourHeaderOverlapContext = createContext<TourHeaderOverlapValue>({
  tourHeaderCollapsed: false,
  tourChromeInset: 0,
  setTourChromeInset: () => {},
})
