#!/usr/bin/env node
/**
 * Build apps/web/public/plugins/catalog.json from official pack manifests.
 * Run from repo root: node scripts/generate-plugin-catalog.mjs
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const repoRoot = join(__dirname, '..')
const pluginsRoot = join(repoRoot, 'plugins')
const outPath = join(repoRoot, 'apps/web/public/plugins/catalog.json')

const DEFAULT_BASE_URL =
  'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins'

/** Official pack manifests — mirrors plugins/ layout (Arabic hub excluded). */
const OFFICIAL_MANIFEST_PATHS = [
  'providers/manifest.json',
  'catalog/manifest.json',
  'live/manifest.json',
  'torrent/manifest.json',
  'hubs/home/manifest.json',
  'hubs/anime/manifest.json',
  'hubs/asian_drama/manifest.json',
  'hubs/my_list/manifest.json',
  'iptv/vod/manifest.json',
]

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

function readManifest(relativePath) {
  const abs = join(pluginsRoot, relativePath)
  const raw = readFileSync(abs, 'utf8')
  return JSON.parse(raw)
}

function buildCatalog() {
  const packs = OFFICIAL_MANIFEST_PATHS.map((manifestPath, index) => {
    const manifest = readManifest(manifestPath)
    const name = manifest.name?.trim()
    if (!name) {
      throw new Error(`${manifestPath}: manifest missing name`)
    }
    const author = manifest.author?.trim()
    return {
      id: inferId(manifestPath),
      kind: inferKind(manifestPath),
      manifestPath,
      name,
      description: packDescription(manifest),
      accent: index % 2 === 0 ? 'brand' : 'flame',
      official: true,
      ...(author ? { author } : {}),
    }
  })

  return {
    schema: 1,
    baseUrl: DEFAULT_BASE_URL,
    packs,
  }
}

const catalog = buildCatalog()
writeFileSync(outPath, `${JSON.stringify(catalog, null, 2)}\n`)
console.log(`Wrote ${outPath} (${catalog.packs.length} packs)`)
