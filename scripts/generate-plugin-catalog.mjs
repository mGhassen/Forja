#!/usr/bin/env node
/**
 * Build web Community Packs catalog from every pack manifest under plugins/.
 * Run from repo root: node scripts/generate-plugin-catalog.mjs
 *
 * Public catalog.json has metadata only (no base URL / paths).
 * Install URLs go to apps/web/src/lib/generated/plugin-pack-sources.ts
 * (used only by install helpers — never render or copy).
 */
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const repoRoot = join(__dirname, '..')
const pluginsRoot = join(repoRoot, 'plugins')
const outCatalog = join(repoRoot, 'apps/web/public/plugins/catalog.json')
const outSourcesDir = join(repoRoot, 'apps/web/src/lib/generated')
const outSources = join(outSourcesDir, 'plugin-pack-sources.ts')

/** Load KEY=VALUE from repo-root .env into process.env (does not override existing). */
function loadRootEnv() {
  try {
    const raw = readFileSync(join(repoRoot, '.env'), 'utf8')
    for (const line of raw.split('\n')) {
      const trimmed = line.trim()
      if (!trimmed || trimmed.startsWith('#')) continue
      const eq = trimmed.indexOf('=')
      if (eq <= 0) continue
      const key = trimmed.slice(0, eq).trim()
      if (!key || process.env[key] != null) continue
      let value = trimmed.slice(eq + 1).trim()
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1)
      }
      process.env[key] = value
    }
  } catch {
    // optional
  }
}

loadRootEnv()

const DEFAULT_BASE_URL =
  'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins'

/** Override with FORJA_PLUGIN_PACKS_BASE in repo-root .env (no trailing slash). */
const packsBase = (
  process.env.FORJA_PLUGIN_PACKS_BASE?.trim() || DEFAULT_BASE_URL
).replace(/\/$/, '')

/** Directories under plugins/ that are not installable packs. */
const SKIP_DIR_NAMES = new Set(['archived', 'node_modules', 'sdk'])

function collectManifestPaths(dir, relativePrefix = '') {
  const found = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue
    const rel = relativePrefix
      ? `${relativePrefix}/${entry.name}`
      : entry.name
    if (entry.isDirectory()) {
      if (SKIP_DIR_NAMES.has(entry.name)) continue
      found.push(...collectManifestPaths(join(dir, entry.name), rel))
      continue
    }
    if (entry.isFile() && entry.name === 'manifest.json') {
      found.push(rel)
    }
  }
  return found
}

function inferKind(manifestPath) {
  const top = manifestPath.split('/')[0]
  if (top === 'providers') return 'providers'
  if (top === 'catalog') return 'catalog'
  if (top === 'live') return 'live'
  if (top === 'torrent') return 'torrent'
  if (top === 'hubs') return 'hubs'
  if (top === 'iptv') return 'iptv'
  return top
}

function inferId(manifestPath) {
  const stem = manifestPath.replace(/\/manifest\.json$/, '')
  const parts = stem.split('/')
  if (parts.length === 1) return parts[0]
  if (parts[0] === 'hubs') return parts[1].replace(/_/g, '-')
  if (parts[0] === 'iptv') return `iptv-${parts[1]}`
  return parts.join('-')
}

function packDescription(manifest) {
  const root = manifest.description?.trim()
  if (root) return root
  const plugins = Array.isArray(manifest.plugins) ? manifest.plugins : []
  for (const plugin of plugins) {
    const desc = plugin?.description?.trim()
    if (desc) return desc
  }
  const count = plugins.length
  return count > 0 ? `${count} plugins` : ''
}

/** Topic tags for web catalog filters (anime, arabic, kids, …). */
const TOPIC_TYPES = new Set(['anime', 'arabic', 'drama'])

function normalizeTag(raw) {
  return String(raw)
    .trim()
    .toLowerCase()
    .replace(/_/g, '-')
    .replace(/\s+/g, '-')
}

/**
 * Prefer explicit `manifest.tags`. Else derive from nav.tabId + topic `types`.
 * @param {Record<string, unknown>} manifest
 * @returns {string[]}
 */
function packTags(manifest) {
  const explicit = Array.isArray(manifest.tags) ? manifest.tags : null
  if (explicit && explicit.length > 0) {
    return [
      ...new Set(
        explicit
          .map((t) => (typeof t === 'string' ? normalizeTag(t) : ''))
          .filter(Boolean),
      ),
    ].sort((a, b) => a.localeCompare(b))
  }

  const tags = new Set()
  const plugins = Array.isArray(manifest.plugins) ? manifest.plugins : []
  for (const plugin of plugins) {
    if (!plugin || typeof plugin !== 'object') continue
    const tabId = plugin.nav?.tabId
    if (typeof tabId === 'string' && tabId.trim()) {
      tags.add(normalizeTag(tabId))
    }
    const types = Array.isArray(plugin.types) ? plugin.types : []
    for (const type of types) {
      if (typeof type !== 'string') continue
      const key = type.trim().toLowerCase()
      if (TOPIC_TYPES.has(key)) tags.add(normalizeTag(key))
    }
  }
  return [...tags].sort((a, b) => a.localeCompare(b))
}

function readManifest(relativePath) {
  const abs = join(pluginsRoot, relativePath)
  const raw = readFileSync(abs, 'utf8')
  return JSON.parse(raw)
}

/** Soft CTA pack ids — Recommended badge on Community Packs + Official picker. */
const RECOMMENDED_PACK_IDS = new Set([
  'home',
  'anime',
  'asian-drama',
  'providers',
  'live',
  'catalog',
  'torrent',
  'arabic',
])

function build() {
  const manifestPaths = collectManifestPaths(pluginsRoot).sort((a, b) =>
    a.localeCompare(b),
  )
  if (manifestPaths.length === 0) {
    throw new Error(`No manifest.json found under ${pluginsRoot}`)
  }

  /** @type {Record<string, string>} */
  const sources = {}
  const packs = manifestPaths.map((manifestPath, index) => {
    const manifest = readManifest(manifestPath)
    const name = manifest.name?.trim()
    if (!name) {
      throw new Error(`${manifestPath}: manifest missing name`)
    }
    const id = inferId(manifestPath)
    if (sources[id]) {
      throw new Error(`Duplicate pack id "${id}" (${manifestPath})`)
    }
    sources[id] = `${packsBase}/${manifestPath}`

    const author = manifest.author?.trim()
    const version = manifest.version?.trim()
    const pluginCount = Array.isArray(manifest.plugins)
      ? manifest.plugins.length
      : undefined
    const tags = packTags(manifest)
    const recommended = RECOMMENDED_PACK_IDS.has(id)

    return {
      id,
      kind: inferKind(manifestPath),
      name,
      description: packDescription(manifest),
      accent: index % 2 === 0 ? 'brand' : 'flame',
      official: true,
      ...(recommended ? { recommended: true } : {}),
      ...(author ? { author } : {}),
      ...(version ? { version } : {}),
      ...(pluginCount != null ? { pluginCount } : {}),
      ...(tags.length > 0 ? { tags } : {}),
    }
  })

  packs.sort((a, b) => {
    const byRec = (b.recommended ? 1 : 0) - (a.recommended ? 1 : 0)
    if (byRec !== 0) return byRec
    return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
  })

  return {
    catalog: { schema: 1, packs },
    sources,
  }
}

const { catalog, sources } = build()
writeFileSync(outCatalog, `${JSON.stringify(catalog, null, 2)}\n`)

mkdirSync(outSourcesDir, { recursive: true })
const sourceEntries = Object.entries(sources)
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([id, url]) => `  ${JSON.stringify(id)}: ${JSON.stringify(url)},`)
  .join('\n')

writeFileSync(
  outSources,
  `/* Generated by scripts/generate-plugin-catalog.mjs — do not edit. */
/** Install URLs by catalog pack id. Never show or copy in UI. */
export const PLUGIN_PACK_SOURCES: Readonly<Record<string, string>> = {
${sourceEntries}
}
`,
)

console.log(
  `Wrote ${outCatalog} (${catalog.packs.length} packs) + ${outSources}\n  packs base: ${packsBase}`,
)
