import { AnimatePresence, motion, useReducedMotion } from 'framer-motion'
import { type ReactNode, useEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import DeepThinkLoader from './DeepThinkLoader'

const BOOT_DURATION_MS = 5000
const BOOT_SESSION_KEY = 'deepthink:boot-complete'

function shouldShowBootSplash() {
  try {
    return !sessionStorage.getItem(BOOT_SESSION_KEY)
  } catch {
    return true
  }
}

function markBootComplete() {
  try {
    sessionStorage.setItem(BOOT_SESSION_KEY, '1')
  } catch {
    /* ignore private browsing / storage blocks */
  }
}

export default function BootGate({ children }: { children: ReactNode }) {
  const prefersReducedMotion = useReducedMotion()
  const needsBoot = shouldShowBootSplash()
  const [showLoader, setShowLoader] = useState(needsBoot)
  const bootHost = document.getElementById('dt-boot-loader')

  useEffect(() => {
    if (!showLoader) return undefined

    const duration = prefersReducedMotion ? 600 : BOOT_DURATION_MS
    const timer = window.setTimeout(() => {
      markBootComplete()
      setShowLoader(false)
    }, duration)

    return () => window.clearTimeout(timer)
  }, [showLoader, prefersReducedMotion])

  const bootOverlay =
    bootHost &&
    createPortal(
      <AnimatePresence>
        {showLoader ? (
          <motion.div
            key="boot-loader"
            data-testid="boot-loader"
            className="fixed inset-0 z-[9999]"
            initial={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{
              duration: prefersReducedMotion ? 0.15 : 0.45,
              ease: 'easeOut',
            }}
          >
            <DeepThinkLoader mode="boot" bootDurationMs={BOOT_DURATION_MS} />
          </motion.div>
        ) : null}
      </AnimatePresence>,
      bootHost,
    )

  return (
    <>
      <div
        className={
          showLoader
            ? 'pointer-events-none opacity-0'
            : 'opacity-100 transition-opacity duration-300'
        }
      >
        {children}
      </div>
      {bootOverlay}
    </>
  )
}
