/** Known account feature flags (`accounts.features`). Add a row + RPC when shipping a new flag. */

export type AccountFeatureKey = 'iptvScrape' | 'dealPortal'

export type AccountFeatureDef = {
  key: AccountFeatureKey
  /** Table / dialog title */
  label: string
  /** Compact chip when enabled */
  shortLabel: string
  description: string
  /** Dedicated admin RPC (per-flag, not a generic setter). */
  rpc: 'admin_set_iptv_scrape' | 'admin_set_deal_portal'
}

export const ACCOUNT_FEATURES: readonly AccountFeatureDef[] = [
  {
    key: 'iptvScrape',
    label: 'Find Portals',
    shortLabel: 'Scrape',
    description: 'Reddit / Find Portals scrape in the IPTV tab.',
    rpc: 'admin_set_iptv_scrape',
  },
  {
    key: 'dealPortal',
    label: 'Deal portals',
    shortLabel: 'Deal',
    description:
      'Spend catalog credits to deal lottery packs from the shared pool.',
    rpc: 'admin_set_deal_portal',
  },
] as const

export type AccountFeaturesMap = Partial<Record<AccountFeatureKey, boolean>>

export function parseAccountFeatures(
  raw: Record<string, unknown> | null | undefined,
): AccountFeaturesMap {
  const out: AccountFeaturesMap = {}
  for (const def of ACCOUNT_FEATURES) {
    if (raw?.[def.key] === true) out[def.key] = true
  }
  return out
}

export function enabledFeatureDefs(
  features: AccountFeaturesMap,
): AccountFeatureDef[] {
  return ACCOUNT_FEATURES.filter((d) => features[d.key] === true)
}
