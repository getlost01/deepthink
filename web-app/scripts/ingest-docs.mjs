import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const webAppRoot = path.join(__dirname, '..')

const owner = process.env.DOCS_REPO_OWNER ?? 'getlost01'
const repo = process.env.DOCS_REPO_NAME ?? 'deepthink'
const branch = process.env.DOCS_REPO_BRANCH ?? 'main'

const repoDocsRoot = path.resolve(webAppRoot, '..', 'docs')
const destRoot = path.join(webAppRoot, 'src', 'docs', 'repo-docs')

const GH_API = 'https://api.github.com'
const TOKEN = process.env.GITHUB_TOKEN

function jsonHeaders() {
  /** @type {Record<string, string>} */
  const h = {
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  }
  if (TOKEN) h.Authorization = `Bearer ${TOKEN}`
  return h
}

function rawBlobHeaders() {
  /** @type {Record<string, string>} */
  const h = {
    Accept: 'application/vnd.github.raw',
    'X-GitHub-Api-Version': '2022-11-28',
  }
  if (TOKEN) h.Authorization = `Bearer ${TOKEN}`
  return h
}

function copyRepoDocsSymlinkAware() {
  fs.rmSync(destRoot, { recursive: true, force: true })
  fs.mkdirSync(destRoot, { recursive: true })
  fs.cpSync(repoDocsRoot, destRoot, { recursive: true })
  console.log('[ingest-docs] Copied', repoDocsRoot, '→', destRoot)
}

async function fetchTree() {
  const url = `${GH_API}/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/git/trees/${encodeURIComponent(branch)}?recursive=1`
  const res = await fetch(url, { headers: jsonHeaders() })
  if (!res.ok) {
    const errBody = await res.text()
    throw new Error(`${res.status} ${url}\n${errBody.slice(0, 800)}`)
  }
  /** @type {{ tree?: { type?: string; path?: string; sha?: string }[] }} */
  const data = await res.json()
  return data.tree ?? []
}

async function fetchBlobText(sha) {
  const url = `${GH_API}/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/git/blobs/${sha}`
  const res = await fetch(url, { headers: rawBlobHeaders() })
  if (!res.ok) {
    const errBody = await res.text()
    throw new Error(
      `${res.status} blob ${sha.slice(0, 7)}\n${errBody.slice(0, 400)}`,
    )
  }
  return res.text()
}

async function ingestFromGitHub() {
  const tree = await fetchTree()
  const mdDocs = tree
    .filter(
      (e) =>
        e.type === 'blob' &&
        typeof e.path === 'string' &&
        e.sha &&
        e.path.startsWith('docs/') &&
        e.path.endsWith('.md'),
    )
    .sort((a, b) => a.path.localeCompare(b.path))

  if (!mdDocs.length)
    throw new Error('GitHub tree contains no docs/**/*.md blobs.')

  fs.rmSync(destRoot, { recursive: true, force: true })
  fs.mkdirSync(destRoot, { recursive: true })

  for (const item of mdDocs) {
    const text = await fetchBlobText(/** @type {string} */ (item.sha))
    const tail = /** @type {string} */ (item.path).slice('docs/'.length)
    const outPath = path.join(destRoot, tail)
    fs.mkdirSync(path.dirname(outPath), { recursive: true })
    fs.writeFileSync(outPath, text, 'utf8')
  }

  console.log(
    `[ingest-docs] Fetched ${mdDocs.length} markdown files from GitHub (${owner}/${repo}@${branch})`,
  )
}

async function main() {
  if (process.env.DOCS_INGEST === 'local') {
    if (!fs.existsSync(repoDocsRoot)) {
      console.error(
        '[ingest-docs] DOCS_INGEST=local but ../docs missing:',
        repoDocsRoot,
      )
      process.exit(1)
    }
    copyRepoDocsSymlinkAware()
    return
  }

  if (TOKEN) {
    await ingestFromGitHub()
    return
  }

  if (fs.existsSync(repoDocsRoot)) {
    copyRepoDocsSymlinkAware()
    console.warn(
      '[ingest-docs] Using local ../docs (set GITHUB_TOKEN on Vercel to ingest from GitHub).',
    )
    return
  }

  await ingestFromGitHub()
}

main().catch((err) => {
  console.error('[ingest-docs]', err)
  process.exit(1)
})
