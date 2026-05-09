import { AnimatePresence, motion, type Variants } from 'framer-motion'
import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import ReactMarkdown from 'react-markdown'
import type { Components } from 'react-markdown'
import remarkGfm from 'remark-gfm'
import SiteLayout from '../components/SiteLayout'
import {
  REPO_DEFAULT_BRANCH,
  REPO_FULL_NAME,
  REPO_NAME,
  REPO_OWNER,
} from '../constants/repo'
import {
  getBuildTimeDocPaths,
  getBuildTimeMarkdownByPath,
  hasBuildTimeDocs,
} from '../docs/buildTimeDocs'

const rawBase = `https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_DEFAULT_BRANCH}`
const repoBlobBase = `https://github.com/${REPO_OWNER}/${REPO_NAME}/blob/${REPO_DEFAULT_BRANCH}`
const README_FILE = 'readme.md'
const DOCS_CACHE_KEY = `deepthink-docs-cache:${REPO_FULL_NAME}:${REPO_DEFAULT_BRANCH}`
const DOCS_CACHE_TTL_MS = 24 * 60 * 60 * 1000

const docLayoutEase = [0.22, 1, 0.36, 1] as const

const fadeUpVariants: Variants = {
  hidden: { opacity: 0, y: 14 },
  show: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.45, ease: docLayoutEase },
  },
}

const staggerContainerVariants: Variants = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.1, delayChildren: 0.06 },
  },
}

function normalizeRepoPath(path: string): string {
  const segments: string[] = []
  path.split('/').forEach((segment) => {
    if (!segment || segment === '.') return
    if (segment === '..') {
      segments.pop()
      return
    }
    segments.push(segment)
  })
  return segments.join('/')
}

function resolveRepoPath(currentDocPath: string, targetPath: string): string {
  if (targetPath.startsWith('/')) return normalizeRepoPath(targetPath.slice(1))
  const currentDir = currentDocPath.includes('/')
    ? currentDocPath.slice(0, currentDocPath.lastIndexOf('/'))
    : ''
  return normalizeRepoPath(`${currentDir}/${targetPath}`)
}

function formatDocLabel(path: string): string {
  const leaf = path.split('/').pop() || path
  const withoutExt = leaf.replace(/\.md$/i, '')
  return withoutExt
    .replace(/[-_]/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())
}

function formatFolderLabel(name: string): string {
  return name
    .replace(/[-_]/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())
}

type DocTreeNode = {
  folders: Map<string, DocTreeNode>
  files: { label: string; path: string }[]
  indexPath: string
}

function createDocTree(paths: string[]): DocTreeNode {
  const root: DocTreeNode = { folders: new Map(), files: [], indexPath: '' }

  paths.forEach((path) => {
    const segments = path
      .replace(/^docs\/?/, '')
      .split('/')
      .filter(Boolean)
    let node = root

    segments.forEach((segment, index) => {
      const isFile = index === segments.length - 1
      if (isFile) {
        if (segments.length > 1 && segment.toLowerCase() === README_FILE) {
          node.indexPath = path
          return
        }
        node.files.push({ label: formatDocLabel(segment), path })
        return
      }

      if (!node.folders.has(segment)) {
        node.folders.set(segment, {
          folders: new Map(),
          files: [],
          indexPath: '',
        })
      }
      node = node.folders.get(segment)!
    })
  })

  return root
}

function getDefaultDocPath(paths: string[]): string | undefined {
  return (
    paths.find((path) => path.toLowerCase() === 'docs/app/readme.md') ??
    paths[0]
  )
}

interface DocsCachePayload {
  cachedAt: number
  docPaths: string[]
  markdownByPath: Record<string, string>
}

function readDocsCache(): DocsCachePayload | null {
  try {
    const cached = window.localStorage.getItem(DOCS_CACHE_KEY)
    if (!cached) return null

    const payload = JSON.parse(cached) as DocsCachePayload
    const isFresh = Date.now() - payload.cachedAt < DOCS_CACHE_TTL_MS
    if (
      !isFresh ||
      !Array.isArray(payload.docPaths) ||
      !payload.markdownByPath
    ) {
      window.localStorage.removeItem(DOCS_CACHE_KEY)
      return null
    }

    return payload
  } catch {
    return null
  }
}

function DocTreeList({
  node,
  activeDocPath,
  onSelectDoc,
  depth = 0,
}: {
  node: DocTreeNode
  activeDocPath: string
  onSelectDoc: (path: string) => void
  depth?: number
}) {
  const folders = Array.from(node.folders.entries())
  const files = node.files

  return (
    <ul
      className={
        depth ? 'mt-1 space-y-1 border-l border-white/10 pl-3' : 'space-y-1'
      }
    >
      {folders.map(([folderName, folderNode]) => {
        const isActiveFolder = folderNode.indexPath === activeDocPath
        return (
          <li key={folderName}>
            <button
              type="button"
              onClick={() => {
                if (folderNode.indexPath) onSelectDoc(folderNode.indexPath)
              }}
              disabled={!folderNode.indexPath || isActiveFolder}
              className={`w-full cursor-pointer rounded-lg px-2 py-1.5 text-left text-xs font-semibold uppercase tracking-wider transition ${
                isActiveFolder
                  ? 'cursor-default border border-purple-300/40 bg-purple-500/20 text-white'
                  : folderNode.indexPath
                    ? 'cursor-pointer text-zinc-300 hover:bg-white/5 hover:text-white'
                    : 'cursor-default text-zinc-400'
              }`}
            >
              {formatFolderLabel(folderName)}
            </button>
            <DocTreeList
              node={folderNode}
              activeDocPath={activeDocPath}
              onSelectDoc={onSelectDoc}
              depth={depth + 1}
            />
          </li>
        )
      })}
      {files.map((file) => (
        <li key={file.path}>
          <button
            type="button"
            onClick={() => onSelectDoc(file.path)}
            disabled={activeDocPath === file.path}
            className={`w-full rounded-lg px-3 py-2 text-left text-sm transition ${
              activeDocPath === file.path
                ? 'cursor-default border border-purple-300/40 bg-purple-500/20 text-white'
                : 'cursor-pointer text-zinc-300 hover:bg-white/5 hover:text-white'
            }`}
          >
            {file.label}
          </button>
        </li>
      ))}
    </ul>
  )
}

export default function DocumentationPage() {
  const [docPaths, setDocPaths] = useState<string[]>([])
  const [activeDocPath, setActiveDocPath] = useState('')
  const [markdownByPath, setMarkdownByPath] = useState<Record<string, string>>(
    {},
  )
  const [markdown, setMarkdown] = useState('')
  const [listLoading, setListLoading] = useState(true)
  const [docLoading, setDocLoading] = useState(false)
  const [error, setError] = useState('')
  const [query, setQuery] = useState('')

  useEffect(() => {
    let isMounted = true
    async function loadDocsList() {
      setListLoading(true)
      setError('')
      try {
        if (hasBuildTimeDocs()) {
          const files = getBuildTimeDocPaths()
          const nextMarkdownByPath = getBuildTimeMarkdownByPath()
          const defaultDoc = getDefaultDocPath(files)
          if (!defaultDoc) throw new Error('No default doc path.')
          if (!isMounted) return
          setDocPaths(files)
          setActiveDocPath(defaultDoc)
          setMarkdownByPath(nextMarkdownByPath)
          setMarkdown(nextMarkdownByPath[defaultDoc] || '')
          setListLoading(false)
          setDocLoading(false)
          return
        }

        const cachedDocs = readDocsCache()
        if (cachedDocs) {
          const defaultDoc = getDefaultDocPath(cachedDocs.docPaths)
          if (!isMounted) return
          setListLoading(false)
          if (!defaultDoc) {
            setError('No documentation paths in cache.')
            return
          }
          setDocPaths(cachedDocs.docPaths)
          setMarkdownByPath(cachedDocs.markdownByPath)
          setActiveDocPath(defaultDoc)
          setMarkdown(cachedDocs.markdownByPath[defaultDoc] || '')
          return
        }

        throw new Error(
          'Documentation is not bundled (run npm run ingest-docs before build). On Vercel, set GitHub Actions or project env GITHUB_TOKEN with repo read access.',
        )
      } catch (loadError: unknown) {
        const message =
          loadError instanceof Error
            ? loadError.message
            : 'Failed to load documentation.'
        if (isMounted) setError(message)
      } finally {
        if (isMounted) {
          setListLoading(false)
          setDocLoading(false)
        }
      }
    }

    loadDocsList()
    return () => {
      isMounted = false
    }
  }, [])

  const handleSelectDoc = useCallback(
    (path: string) => {
      if (path === activeDocPath) return
      setActiveDocPath(path)
      if (markdownByPath[path]) {
        setMarkdown(markdownByPath[path])
      }
    },
    [activeDocPath, markdownByPath],
  )

  const markdownComponents = useMemo(
    (): Components => ({
      a: ({ href = '', children }) => {
        const isExternal =
          href.startsWith('http://') || href.startsWith('https://')
        if (isExternal) {
          return (
            <a
              href={href}
              target="_blank"
              rel="noopener noreferrer"
              className="cursor-pointer text-cyan-300 hover:text-cyan-200"
            >
              {children}
            </a>
          )
        }

        if (href.startsWith('#')) {
          return (
            <a
              href={href}
              className="cursor-pointer text-cyan-300 hover:text-cyan-200"
            >
              {children}
            </a>
          )
        }

        const resolvedPath = resolveRepoPath(activeDocPath, href)
        if (resolvedPath.endsWith('.md') && docPaths.includes(resolvedPath)) {
          return (
            <button
              type="button"
              onClick={() => handleSelectDoc(resolvedPath)}
              className="cursor-pointer text-left text-cyan-300 hover:text-cyan-200"
            >
              {children}
            </button>
          )
        }

        return (
          <a
            href={`${repoBlobBase}/${resolvedPath}`}
            target="_blank"
            rel="noopener noreferrer"
            className="cursor-pointer text-cyan-300 hover:text-cyan-200"
          >
            {children}
          </a>
        )
      },
      img: ({ src = '', alt = '' }) => {
        const resolvedSrc =
          src.startsWith('http://') || src.startsWith('https://')
            ? src
            : `${rawBase}/${resolveRepoPath(activeDocPath, src)}`
        return (
          <img
            src={resolvedSrc}
            alt={alt}
            className="my-8 w-full rounded-2xl border border-white/10 shadow-xl shadow-black/30"
          />
        )
      },
      code: ({
        inline,
        children,
      }: {
        inline?: boolean
        children?: ReactNode
      }) =>
        inline ? (
          <code className="rounded-md border border-white/10 bg-zinc-800 px-1.5 py-0.5 text-[0.85em] text-zinc-100">
            {children}
          </code>
        ) : (
          <code className="text-sm leading-relaxed text-zinc-100">
            {children}
          </code>
        ),
      pre: ({ children }) => (
        <pre className="my-6 overflow-x-auto rounded-xl border border-white/10 bg-zinc-950 p-4 text-sm leading-relaxed text-zinc-100">
          {children}
        </pre>
      ),
      blockquote: ({ children }) => (
        <blockquote className="my-6 rounded-r-lg border-l-4 border-purple-300/70 bg-purple-500/10 px-4 py-3 text-zinc-200">
          {children}
        </blockquote>
      ),
      table: ({ children }) => (
        <div className="my-6 overflow-x-auto rounded-xl border border-white/10">
          <table className="w-full border-collapse text-left text-sm">
            {children}
          </table>
        </div>
      ),
      th: ({ children }) => (
        <th className="border-b border-white/10 bg-zinc-900 px-3 py-2 text-zinc-100">
          {children}
        </th>
      ),
      td: ({ children }) => (
        <td className="border-b border-white/5 px-3 py-2 text-zinc-300">
          {children}
        </td>
      ),
      h1: ({ children }) => (
        <h1 className="mb-6 mt-2 text-[1.75rem] font-semibold leading-tight tracking-tight text-white sm:text-4xl md:text-5xl">
          {children}
        </h1>
      ),
      h2: ({ children }) => (
        <h2 className="mt-10 border-t border-white/10 pt-8 text-2xl font-semibold text-white md:text-3xl">
          {children}
        </h2>
      ),
      h3: ({ children }) => (
        <h3 className="mt-8 text-xl font-semibold text-zinc-100">{children}</h3>
      ),
      hr: () => <hr className="my-8 border-white/10" />,
    }),
    [activeDocPath, docPaths, handleSelectDoc],
  )

  const filteredDocPaths = useMemo(() => {
    const normalized = query.trim().toLowerCase()
    if (!normalized) return docPaths
    return docPaths.filter((path) => path.toLowerCase().includes(normalized))
  }, [docPaths, query])

  const docTree = useMemo(
    () => createDocTree(filteredDocPaths),
    [filteredDocPaths],
  )
  const isInitialDocLoading = docLoading && !markdown

  return (
    <SiteLayout>
      <section className="relative px-4 py-10 sm:px-6 md:py-12">
        <div
          className="pointer-events-none absolute inset-0 overflow-hidden"
          aria-hidden
        >
          <motion.div
            className="absolute -right-20 top-0 h-72 w-72 rounded-full bg-purple-500/12 blur-3xl"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 1 }}
          />
        </div>
        <motion.div
          className="relative mx-auto grid max-w-6xl grid-cols-1 gap-4 md:grid-cols-[minmax(0,_13rem)_minmax(0,_1fr)] md:gap-6 xl:grid-cols-[minmax(0,_15rem)_minmax(0,_1fr)]"
          variants={staggerContainerVariants}
          initial="hidden"
          animate="show"
        >
          <aside className="relative z-10 h-fit w-full min-w-0 shrink-0 self-start md:w-auto md:sticky md:top-[calc(5.75rem+env(safe-area-inset-top,0px))] xl:top-28">
            <motion.div
              variants={fadeUpVariants}
              className="w-full max-w-full rounded-2xl border border-white/10 bg-zinc-900/90 p-3 shadow-2xl shadow-black/20 backdrop-blur-sm md:p-4"
            >
              <p className="px-2 text-xs font-semibold uppercase tracking-widest text-purple-200">
                Documentation
              </p>
              <div className="mt-3">
                <input
                  type="text"
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  placeholder="Search docs..."
                  className="w-full rounded-lg border border-white/10 bg-zinc-950 px-3 py-2 text-sm text-zinc-100 placeholder:text-zinc-500 focus:border-purple-300/50 focus:outline-none"
                />
              </div>
              {listLoading ? (
                <p className="px-2 py-4 text-sm text-zinc-400">
                  Loading docs...
                </p>
              ) : (
                <div className="mt-3 max-h-72 overflow-auto pr-1 lg:max-h-[68vh]">
                  <DocTreeList
                    node={docTree}
                    activeDocPath={activeDocPath}
                    onSelectDoc={handleSelectDoc}
                  />
                  {!filteredDocPaths.length && (
                    <p className="px-2 py-3 text-sm text-zinc-500">
                      No docs match your search.
                    </p>
                  )}
                </div>
              )}
            </motion.div>
          </aside>

          <motion.article
            variants={fadeUpVariants}
            className="relative min-h-[70vh] min-w-0 max-w-none rounded-2xl border border-white/10 bg-zinc-900/50 p-5 shadow-2xl shadow-black/20 backdrop-blur-sm md:min-h-[calc(100vh-9rem)] md:p-7 xl:p-8"
          >
            {docLoading && markdown && (
              <p className="absolute right-5 top-5 rounded-full border border-purple-300/30 bg-purple-500/10 px-3 py-1 text-xs font-medium text-purple-100 md:right-8 md:top-8">
                Loading docs...
              </p>
            )}

            {error && (
              <p className="mb-6 rounded-xl border border-red-400/30 bg-red-500/10 p-4 text-sm text-red-200">
                {error}
              </p>
            )}

            <AnimatePresence mode="wait">
              {isInitialDocLoading ? (
                <motion.p
                  key="doc-loading"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.2 }}
                  className="text-sm text-zinc-400"
                >
                  Rendering markdown...
                </motion.p>
              ) : (
                <motion.div
                  key={activeDocPath}
                  role="presentation"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -8 }}
                  transition={{ duration: 0.28, ease: docLayoutEase }}
                  className="prose prose-sm prose-invert prose-zinc max-w-none prose-p:leading-7 prose-p:text-zinc-300 prose-li:text-zinc-300 prose-strong:text-zinc-100 prose-a:no-underline sm:prose-base sm:prose-p:leading-8"
                >
                  <ReactMarkdown
                    remarkPlugins={[remarkGfm]}
                    components={markdownComponents}
                  >
                    {markdown}
                  </ReactMarkdown>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.article>
        </motion.div>
      </section>
    </SiteLayout>
  )
}
