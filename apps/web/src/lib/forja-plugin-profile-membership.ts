import { supabase } from '@/lib/supabase'
import type { Json } from '@/lib/database.types'
import {
  compactProfileSettingsPayload,
  emptyProfileSettingsPayload,
  expandProfileSettingsPayload,
  navigationAfterForjaPacksChange,
  type ForjaPackRow,
  type ForjaPayload,
  type ProfileSettingsPayload,
} from '@/lib/sync-domains'
import { isPackInstalled } from '@/lib/forja-plugin-install'

export type PackProfileMembership = {
  profileId: string
  installed: boolean
}

/** Lean packs[] membership for one manifest across account profiles. */
export async function fetchPackProfileMembership(opts: {
  accountId: string
  profileIds: string[]
  manifestUrl: string
}): Promise<Map<string, boolean>> {
  const want = opts.manifestUrl.trim()
  const out = new Map<string, boolean>()
  for (const id of opts.profileIds) out.set(id, false)
  if (!opts.accountId || opts.profileIds.length === 0 || !want) return out

  const { data, error } = await supabase
    .from('profile_settings')
    .select('profile_id, payload')
    .eq('account_id', opts.accountId)
    .in('profile_id', opts.profileIds)
  if (error) throw error

  for (const row of data ?? []) {
    const payload = expandProfileSettingsPayload(row.payload)
    const packs = payload.connectedServices?.forja?.packs ?? []
    out.set(row.profile_id, isPackInstalled(packs, want))
  }
  return out
}

function withPackMembership(
  current: ProfileSettingsPayload,
  pack: ForjaPackRow,
  selected: boolean,
): ProfileSettingsPayload {
  const prevForja = current.connectedServices?.forja
  const prevPacks = prevForja?.packs ?? []
  const url = pack.manifestUrl.trim()
  const had = isPackInstalled(prevPacks, url)
  if (selected === had) return current

  let nextPacks: ForjaPackRow[]
  if (selected) {
    const row: ForjaPackRow = {
      manifestUrl: url,
      addedAt: new Date().toISOString(),
    }
    const name = pack.name?.trim()
    if (name && name !== url) row.name = name
    const version = pack.version?.trim()
    if (version) row.version = version
    nextPacks = [...prevPacks, row]
  } else {
    nextPacks = prevPacks.filter((p) => p.manifestUrl.trim() !== url)
  }

  const nextForja: ForjaPayload = {
    packs: nextPacks,
    ...(prevForja?.onboarded === true ? { onboarded: true as const } : {}),
  }
  const navigation = navigationAfterForjaPacksChange({
    navigation: current.navigation,
    prevPacks,
    nextPacks,
    addonFeatureIptv: current.playback?.addon_feature_iptv,
  })

  return {
    ...current,
    connectedServices: {
      ...current.connectedServices,
      forja: nextForja,
    },
    navigation,
  }
}

/**
 * Add or remove one pack on each profile so membership matches `selectedIds`.
 * Profiles already matching are skipped.
 */
export async function applyPackProfileMembership(opts: {
  accountId: string
  userId: string
  pack: ForjaPackRow
  /** Profile ids that should have the pack after save. */
  selectedIds: Set<string>
  allProfileIds: string[]
}): Promise<void> {
  const url = opts.pack.manifestUrl.trim()
  if (!url || opts.allProfileIds.length === 0) return

  const { data, error } = await supabase
    .from('profile_settings')
    .select('profile_id, payload')
    .eq('account_id', opts.accountId)
    .in('profile_id', opts.allProfileIds)
  if (error) throw error

  const byId = new Map(
    (data ?? []).map((row) => [row.profile_id, row.payload] as const),
  )
  const now = new Date().toISOString()

  for (const profileId of opts.allProfileIds) {
    const want = opts.selectedIds.has(profileId)
    const current = expandProfileSettingsPayload(
      byId.get(profileId) ?? emptyProfileSettingsPayload(),
    )
    const next = withPackMembership(current, opts.pack, want)
    if (next === current) continue

    const lean = compactProfileSettingsPayload(next)
    const { error: upsertError } = await supabase
      .from('profile_settings')
      .upsert({
        profile_id: profileId,
        account_id: opts.accountId,
        payload: lean as Json,
        updated_at: now,
        updated_by: opts.userId,
      })
    if (upsertError) throw upsertError
  }
}
