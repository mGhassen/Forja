import type { Database, Json } from '@/lib/database.types'
import { adminDb } from '@/lib/admin-db'
import { normalizePluginPackUrl } from '@/lib/plugin-pack-url'
import { supabase } from '@/lib/supabase'

export type PluginPack = Database['public']['Tables']['plugin_packs']['Row']
export type PluginPackInsert =
  Database['public']['Tables']['plugin_packs']['Insert']
export type PluginPackUpdate =
  Database['public']['Tables']['plugin_packs']['Update']
export type PluginBundle = Database['public']['Tables']['plugin_bundles']['Row']
export type PluginBundleInsert =
  Database['public']['Tables']['plugin_bundles']['Insert']
export type PluginBundleItem =
  Database['public']['Tables']['plugin_bundle_items']['Row']

export type PluginBundleWithItems = PluginBundle & {
  items: PluginBundleItem[]
}

export type PackValidationResult = {
  ok: boolean
  version?: string
  pluginCount?: number
  name?: string
  packId?: string
  errors: string[]
  warnings: string[]
  checkedFiles: string[]
  missingFiles: string[]
  /** Normalized install URL used for the check (raw GitHub when applicable). */
  manifestUrl?: string
}

const SUPPORTED_KINDS = new Set(['http', 'hop', 'catalog', 'host', 'torrent'])

export function errMessage(err: unknown): string {
  if (err instanceof Error) return err.message
  if (typeof err === 'object' && err && 'message' in err) {
    const m = (err as { message?: unknown }).message
    if (typeof m === 'string' && m.trim()) return m
  }
  return String(err)
}

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v)
}

function nonEmptyString(v: unknown): v is string {
  return typeof v === 'string' && v.trim().length > 0
}

function joinUrl(base: string, rel: string): string {
  const cleanBase = base.replace(/\/manifest\.json$/i, '/').replace(/\/?$/, '/')
  const cleanRel = rel.replace(/^\.\//, '').replace(/^\/+/, '')
  return new URL(cleanRel, cleanBase).toString()
}

/** Schema-ish checks mirroring Flutter PluginContract + manifest.schema.json. */
export function validateManifestJson(
  raw: unknown,
): Omit<PackValidationResult, 'checkedFiles' | 'missingFiles'> & {
  files: string[]
} {
  const errors: string[] = []
  const warnings: string[] = []
  const files: string[] = []

  if (!isRecord(raw)) {
    return {
      ok: false,
      errors: ['manifest is not a JSON object'],
      warnings,
      files,
    }
  }

  if (raw.schema != null && raw.schema !== 1) {
    errors.push(`unsupported schema: ${String(raw.schema)}`)
  }
  if (!nonEmptyString(raw.name)) errors.push('missing name')
  if (!nonEmptyString(raw.version)) errors.push('missing version')
  if (raw.enabled != null) {
    errors.push('manifest must not declare enabled')
  }
  if (raw.prelude != null && !nonEmptyString(raw.prelude)) {
    errors.push('prelude must be a non-empty string')
  }

  const plugins = raw.plugins
  if (!Array.isArray(plugins) || plugins.length === 0) {
    errors.push('plugins[] required and non-empty')
  } else {
    const ids = new Set<string>()
    for (let i = 0; i < plugins.length; i++) {
      const p = plugins[i]
      if (!isRecord(p)) {
        errors.push(`plugins[${i}] not an object`)
        continue
      }
      if (!nonEmptyString(p.id)) errors.push(`plugins[${i}].id required`)
      else if (ids.has(p.id)) errors.push(`duplicate plugin id: ${p.id}`)
      else ids.add(p.id)
      if (!nonEmptyString(p.name)) errors.push(`plugins[${i}].name required`)
      const entry =
        (nonEmptyString(p.entry) && p.entry) ||
        (nonEmptyString(p.filename) && p.filename) ||
        ''
      if (!entry) errors.push(`plugins[${i}].entry required`)
      else files.push(entry)
      if (p.kind != null && !SUPPORTED_KINDS.has(String(p.kind))) {
        warnings.push(`plugins[${i}].kind unknown: ${String(p.kind)}`)
      }
    }
  }

  if (nonEmptyString(raw.prelude)) files.push(raw.prelude)
  if (Array.isArray(raw.bundle)) {
    for (const f of raw.bundle) {
      if (nonEmptyString(f)) files.push(f)
      else errors.push('bundle[] entries must be non-empty strings')
    }
  }

  return {
    ok: errors.length === 0,
    version: nonEmptyString(raw.version) ? raw.version.trim() : undefined,
    pluginCount: Array.isArray(plugins) ? plugins.length : undefined,
    name: nonEmptyString(raw.name) ? raw.name.trim() : undefined,
    packId: nonEmptyString(raw.id) ? raw.id.trim() : undefined,
    errors,
    warnings,
    files: [...new Set(files)],
  }
}

export async function resolveAndFetchManifest(
  url: string,
): Promise<{ url: string; data: unknown }> {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Not signed in')

  const res = await fetch('/api/plugin-pack-fetch', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${session.access_token}`,
    },
    body: JSON.stringify({ url: url.trim(), mode: 'json' }),
  })
  const json = (await res.json().catch(() => ({}))) as {
    error?: string
    url?: string
    data?: unknown
  }
  if (!res.ok || json.data === undefined) {
    throw new Error(json.error || `manifest fetch failed (${res.status})`)
  }
  return {
    url: json.url?.trim() || normalizePluginPackUrl(url),
    data: json.data,
  }
}

export async function fetchManifest(url: string): Promise<unknown> {
  const { data } = await resolveAndFetchManifest(url)
  return data
}

async function fileExists(url: string): Promise<boolean> {
  try {
    const {
      data: { session },
    } = await supabase.auth.getSession()
    if (!session?.access_token) return false
    const res = await fetch('/api/plugin-pack-fetch', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${session.access_token}`,
      },
      body: JSON.stringify({ url, mode: 'exists' }),
    })
    const json = (await res.json().catch(() => ({}))) as { exists?: boolean }
    return res.ok && json.exists === true
  } catch {
    return false
  }
}

export async function validatePackAtUrl(
  manifestUrl: string,
): Promise<PackValidationResult> {
  const resolved = await resolveAndFetchManifest(manifestUrl)
  const parsed = validateManifestJson(resolved.data)
  const checkedFiles: string[] = []
  const missingFiles: string[] = []

  for (const rel of parsed.files) {
    const fileUrl = joinUrl(resolved.url, rel)
    checkedFiles.push(rel)
    const ok = await fileExists(fileUrl)
    if (!ok) missingFiles.push(rel)
  }

  const errors = [...parsed.errors]
  if (missingFiles.length > 0) {
    errors.push(`missing files: ${missingFiles.join(', ')}`)
  }

  return {
    ok: errors.length === 0,
    version: parsed.version,
    pluginCount: parsed.pluginCount,
    name: parsed.name,
    packId: parsed.packId,
    errors,
    warnings: parsed.warnings,
    checkedFiles,
    missingFiles,
    manifestUrl: resolved.url,
  }
}

export { normalizePluginPackUrl } from '@/lib/plugin-pack-url'

export async function listPluginPacks(): Promise<PluginPack[]> {
  const { data, error } = await adminDb
    .from('plugin_packs')
    .select('*')
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true })
  if (error) throw error
  return data ?? []
}

export async function upsertPluginPack(
  row: PluginPackInsert,
): Promise<PluginPack> {
  const { data, error } = await adminDb
    .from('plugin_packs')
    .upsert(row, { onConflict: 'id' })
    .select('*')
    .single()
  if (error) throw error
  return data
}

export async function updatePluginPack(
  id: string,
  patch: PluginPackUpdate,
): Promise<PluginPack> {
  const { data, error } = await adminDb
    .from('plugin_packs')
    .update(patch)
    .eq('id', id)
    .select('*')
    .single()
  if (error) throw error
  return data
}

export async function deletePluginPack(id: string): Promise<void> {
  const { error } = await adminDb.from('plugin_packs').delete().eq('id', id)
  if (error) throw error
}

export async function persistValidation(
  id: string,
  result: PackValidationResult,
): Promise<PluginPack> {
  return updatePluginPack(id, {
    cached_version: result.version ?? null,
    plugin_count: result.pluginCount ?? null,
    last_validated_at: new Date().toISOString(),
    last_validation: result as unknown as Json,
    ...(result.name ? { name: result.name } : {}),
    ...(result.manifestUrl ? { manifest_url: result.manifestUrl } : {}),
  })
}

export async function listPluginBundles(): Promise<PluginBundleWithItems[]> {
  const [{ data: bundles, error: bErr }, { data: items, error: iErr }] =
    await Promise.all([
      adminDb
        .from('plugin_bundles')
        .select('*')
        .order('sort_order', { ascending: true })
        .order('id', { ascending: true }),
      adminDb
        .from('plugin_bundle_items')
        .select('*')
        .order('sort_order', { ascending: true }),
    ])
  if (bErr) throw bErr
  if (iErr) throw iErr
  const byBundle = new Map<string, PluginBundleItem[]>()
  for (const item of items ?? []) {
    const list = byBundle.get(item.bundle_id) ?? []
    list.push(item)
    byBundle.set(item.bundle_id, list)
  }
  return (bundles ?? []).map((b) => ({
    ...b,
    items: byBundle.get(b.id) ?? [],
  }))
}

export async function upsertPluginBundle(
  row: PluginBundleInsert,
  packIds: string[],
): Promise<void> {
  const { error: bErr } = await adminDb.from('plugin_bundles').upsert(row, {
    onConflict: 'id',
  })
  if (bErr) throw bErr

  const { error: delErr } = await adminDb
    .from('plugin_bundle_items')
    .delete()
    .eq('bundle_id', row.id)
  if (delErr) throw delErr

  if (packIds.length === 0) return
  const rows = packIds.map((pack_id, i) => ({
    bundle_id: row.id,
    pack_id,
    sort_order: (i + 1) * 10,
  }))
  const { error: insErr } = await adminDb.from('plugin_bundle_items').insert(rows)
  if (insErr) throw insErr
}

export async function updatePluginBundle(
  id: string,
  patch: Database['public']['Tables']['plugin_bundles']['Update'],
): Promise<void> {
  const { error } = await adminDb
    .from('plugin_bundles')
    .update(patch)
    .eq('id', id)
  if (error) throw error
}

export async function deletePluginBundle(id: string): Promise<void> {
  const { error } = await adminDb.from('plugin_bundles').delete().eq('id', id)
  if (error) throw error
}

export function slugifyId(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}
