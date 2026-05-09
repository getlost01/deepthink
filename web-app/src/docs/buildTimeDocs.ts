const rawModules = import.meta.glob<string>('./repo-docs/**/*.md', {
  eager: true,
  query: '?raw',
  import: 'default',
})

function globKeyToRepoRelative(key: string): string {
  const parts = key.replace(/\\/g, '/').split('/')
  const idx = parts.indexOf('repo-docs')
  const relativeParts = idx === -1 ? [] : parts.slice(idx + 1)
  return relativeParts.join('/')
}

const sortedPaths: string[] = []
const markdownByPath: Record<string, string> = {}

for (const [key, text] of Object.entries(rawModules)) {
  const rel = globKeyToRepoRelative(key)
  if (!rel || !rel.endsWith('.md')) continue
  const path = `docs/${rel}`
  sortedPaths.push(path)
  markdownByPath[path] = text
}

sortedPaths.sort((a, b) => a.localeCompare(b))

export function hasBuildTimeDocs(): boolean {
  return sortedPaths.length > 0
}

export function getBuildTimeDocPaths(): string[] {
  return sortedPaths
}

export function getBuildTimeMarkdownByPath(): Record<string, string> {
  return markdownByPath
}
