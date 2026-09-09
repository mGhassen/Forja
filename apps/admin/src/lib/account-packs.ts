import { adminDb } from '@/lib/admin-db'
import { fetchAccountProfiles, type ProfileOpt } from '@/lib/iptv-portal-assign'

export type AccountPackRow = {
  manifestUrl: string
  name?: string
  version?: string
  addedAt?: string
}

export type ProfileSettingsPacks = {
  profileId: string
  profileName: string
  packs: AccountPackRow[]
  /** Raw payload for surgical writes. */
  payload: Record<string, unknown>
  updatedAt: string | null
}

export { type ProfileOpt }

type ManifestMeta = {
  name?: string
  version?: string
}

function errMessage(e: unknown, fallback: string): string {
  if (e && typeof e === 'object' && 'message' in e) {
    const m = (e as { message?: string }).message
    if (m) return m
  }
  return e instanceof Error ? e.message : fallback
}

function packsFromPayload(payload: unknown): AccountPackRow[] {
  if (!payload || typeof payload !== 'object') return []
  const cs = (payload as { connectedServices?: unknown }).connectedServices
  if (!cs || typeof cs !== 'object') return []
  const forja = (cs as { forja?: unknown }).forja
  if (!forja || typeof forja !== 'object') return []
  const packs = (forja as { packs?: unknown }).packs
  if (!Array.isArray(packs)) return []
  const out: AccountPackRow[] = []
  for (const raw of packs) {
    if (!raw || typeof raw !== 'object') continue
    const row = raw as Record<string, unknown>
    const manifestUrl =
      typeof row.manifestUrl === 'string' ? row.manifestUrl.trim() : ''
    if (!manifestUrl) continue
    const next: AccountPackRow = { manifestUrl }
    const name = typeof row.name === 'string' ? row.name.trim() : ''
    if (name) next.name = name
    const version = typeof row.version === 'string' ? row.version.trim() : ''
    if (version) next.version = version
    const addedAt = typeof row.addedAt === 'string' ? row.addedAt.trim() : ''
    if (addedAt) next.addedAt = addedAt
    out.push(next)
  }
  return out
}

function leanPackRows(packs: AccountPackRow[]): AccountPackRow[] {
  return packs.map((p) => {
    const row: AccountPackRow = { manifestUrl: p.manifestUrl.trim() }
    const name = p.name?.trim()
    if (name && name !== row.manifestUrl) row.name = name
    const version = p.version?.trim()
    if (version) row.version = version
    const addedAt = p.addedAt?.trim()
    if (addedAt) row.addedAt = addedAt
    return row
  })
}

/** Write packs into payload without wiping playback / nav / other services. */
function withForjaPacks(
  payload: Record<string, unknown>,
  packs: AccountPackRow[],
): Record<string, unknown> {
  const prevCs =
    payload.connectedServices &&
    typeof payload.connectedServices === 'object' &&
    !Array.isArray(payload.connectedServices)
      ? { ...(payload.connectedServices as Record<string, unknown>) }
      : {}
  const prevForja =
    prevCs.forja &&
    typeof prevCs.forja === 'object' &&
    !Array.isArray(prevCs.forja)
      ? { ...(prevCs.forja as Record<string, unknown>) }
      : {}
  const lean = leanPackRows(packs)
  // Always keep forja key when we touch packs (empty [] must purge devices).
  prevCs.forja = {
    ...prevForja,
    packs: lean,
    ...(prevForja.onboarded === true ? { onboarded: true } : {}),
  }
  return { ...payload, connectedServices: prevCs }
}

export async function fetchManifestMeta(
  manifestUrl: string,
): Promise<ManifestMeta> {
  const url = manifestUrl.trim()
  if (!url) return {}
  const res = await fetch(url, { cache: 'no-store' })
  if (!res.ok) {
    throw new Error(`Could not fetch manifest (${res.status})`)
  }
  const data = (await res.json()) as { name?: unknown; version?: unknown }
  const name = typeof data.name === 'string' ? data.name.trim() : ''
  const version = typeof data.version === 'string' ? data.version.trim() : ''
  const out: ManifestMeta = {}
  if (name) out.name = name
  if (version) out.version = version
  return out
}

export async function fetchProfilePacks(
  accountId: string,
  profileId: string,
): Promise<ProfileSettingsPacks> {
  const profiles = await fetchAccountProfiles(accountId)
  const profile = profiles.find((p) => p.id === profileId)
  if (!profile) throw new Error('Profile not found on this account')

  const { data, error } = await adminDb
    .from('profile_settings')
    .select('payload, updated_at')
    .eq('account_id', accountId)
    .eq('profile_id', profileId)
    .maybeSingle()
  if (error) throw error

  const payload =
    data?.payload && typeof data.payload === 'object'
      ? (data.payload as Record<string, unknown>)
      : {}

  return {
    profileId,
    profileName: profile.name,
    packs: packsFromPayload(payload),
    payload,
    updatedAt: (data?.updated_at as string | null) ?? null,
  }
}

export async function listAccountProfiles(
  accountId: string,
): Promise<ProfileOpt[]> {
  return fetchAccountProfiles(accountId)
}

async function upsertPacks(opts: {
  accountId: string
  profileId: string
  payload: Record<string, unknown>
  packs: AccountPackRow[]
}): Promise<void> {
  const nextPayload = withForjaPacks(opts.payload, opts.packs)
  const { error } = await adminDb.from('profile_settings').upsert({
    account_id: opts.accountId,
    profile_id: opts.profileId,
    payload: nextPayload,
    updated_at: new Date().toISOString(),
  })
  if (error) throw new Error(errMessage(error, 'Could not save packs'))
}

export async function addPackToProfile(opts: {
  accountId: string
  profileId: string
  manifestUrl: string
  name?: string
}): Promise<AccountPackRow> {
  const manifestUrl = opts.manifestUrl.trim()
  if (!manifestUrl) throw new Error('Manifest URL required')

  const current = await fetchProfilePacks(opts.accountId, opts.profileId)
  if (current.packs.some((p) => p.manifestUrl.trim() === manifestUrl)) {
    throw new Error('Pack already on this profile')
  }

  const meta = await fetchManifestMeta(manifestUrl)
  const version = meta.version?.trim()
  if (!version) {
    throw new Error('Manifest has no version — cannot add pack')
  }
  const name =
    opts.name?.trim() ||
    meta.name?.trim() ||
    manifestUrl

  const row: AccountPackRow = {
    manifestUrl,
    name,
    version,
    addedAt: new Date().toISOString(),
  }

  await upsertPacks({
    accountId: opts.accountId,
    profileId: opts.profileId,
    payload: current.payload,
    packs: [...current.packs, row],
  })
  return row
}

export async function removePackFromProfile(opts: {
  accountId: string
  profileId: string
  manifestUrl: string
}): Promise<void> {
  const manifestUrl = opts.manifestUrl.trim()
  const current = await fetchProfilePacks(opts.accountId, opts.profileId)
  const packs = current.packs.filter(
    (p) => p.manifestUrl.trim() !== manifestUrl,
  )
  await upsertPacks({
    accountId: opts.accountId,
    profileId: opts.profileId,
    payload: current.payload,
    packs,
  })
}
