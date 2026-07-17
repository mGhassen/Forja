/**
 * Frozen release notes from docs/changelog/done/*-[released].md.
 * Bundled at build time so the web changelog never depends on GitHub note bodies.
 *
 * Note: do not put `[released]` in the glob itself — micromatch treats `[]` as a
 * character class and would match nothing.
 */
const DOC_MODULES = import.meta.glob('../../../../docs/changelog/done/*.md', {
  query: '?raw',
  import: 'default',
  eager: true,
}) as Record<string, string>

const VERSION_FROM_PATH = /(\d+\.\d+\.\d+)-\[released\]\.md$/

function versionFromPath(path: string): string | null {
  const m = path.replace(/\\/g, '/').match(VERSION_FROM_PATH)
  return m?.[1] ?? null
}

/** version → raw markdown from docs/changelog/done */
export const DOC_CHANGELOGS: Record<string, string> = (() => {
  const out: Record<string, string> = {}
  for (const [path, markdown] of Object.entries(DOC_MODULES)) {
    const version = versionFromPath(path)
    if (!version || typeof markdown !== 'string') continue
    out[version] = markdown
  }
  return out
})()

export function compareSemverDesc(a: string, b: string): number {
  const pa = a.split('.').map((n) => Number.parseInt(n, 10) || 0)
  const pb = b.split('.').map((n) => Number.parseInt(n, 10) || 0)
  for (let i = 0; i < 3; i++) {
    const av = pa[i] ?? 0
    const bv = pb[i] ?? 0
    if (av !== bv) return bv - av
  }
  return 0
}
