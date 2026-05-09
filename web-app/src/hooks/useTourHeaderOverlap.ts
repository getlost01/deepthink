import { useContext } from 'react'
import { TourHeaderOverlapContext } from '../contexts/tourHeaderOverlapContext'

export function useTourHeaderOverlap() {
  return useContext(TourHeaderOverlapContext)
}

export function useTourHeaderCollapsed(): boolean {
  return useContext(TourHeaderOverlapContext).tourHeaderCollapsed
}
