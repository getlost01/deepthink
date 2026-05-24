import { lazy, Suspense, useEffect } from 'react'
import { Navigate, Route, Routes, useLocation } from 'react-router-dom'
import DeepThinkLoader from './components/DeepThinkLoader'
import LandingPage from './components/LandingPage'

const DocumentationPage = lazy(() => import('./pages/DocumentationPage'))
const ArchitecturePage = lazy(() => import('./pages/ArchitecturePage'))

function ScrollToHash() {
  const { pathname, hash } = useLocation()

  useEffect(() => {
    if (!hash) return
    const id = hash.slice(1)
    requestAnimationFrame(() => {
      document
        .getElementById(id)
        ?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    })
  }, [pathname, hash])

  return null
}

function RouteFallback() {
  return <DeepThinkLoader />
}

export default function App() {
  return (
    <>
      <ScrollToHash />
      <Suspense fallback={<RouteFallback />}>
        <Routes>
          <Route path="/" element={<LandingPage />} />
          <Route path="/documentation" element={<DocumentationPage />} />
          <Route path="/architecture" element={<ArchitecturePage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </>
  )
}
