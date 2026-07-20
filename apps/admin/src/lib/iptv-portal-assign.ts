import { adminDb } from '@/lib/admin-db'

export type ProfileOpt = { id: string; name: string }

export type PortalHit = {
  id: string
  url: string
  username: string
  alive: boolean | null
  catalog_pool: boolean
  region_primary: string
}

export type AccountHit = {
  id: string
  email: string | null
  iptv_credits: number
}

export type AssignmentRow = {
  id: string
  portal_id: string
  profile_id: string
  portal_name: string
  profile_name: string
  account_email: string | null
  url: string
  username: string
  alive: boolean | null
  expiry: string | null
  max_connections: string | null
  catalog_pool: boolean
  region_primary: string
}

function errMessage(e: unknown, fallback: string): string {
  if (e && typeof e === 'object' && 'message' in e) {
    const m = (e as { message?: string }).message
    if (m) return m
  }
  return e instanceof Error ? e.message : fallback
}

export async function fetchAccountProfiles(
  accountId: string,
): Promise<ProfileOpt[]> {
  const { data, error } = await adminDb
    .from('profiles')
    .select('id, name')
    .eq('account_id', accountId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return (data ?? []) as ProfileOpt[]
}

export async function searchAccounts(q: string): Promise<AccountHit[]> {
  let req = adminDb
    .from('accounts')
    .select('id, email, iptv_credits')
    .order('created_at', { ascending: false })
    .limit(20)
  if (q.trim()) req = req.ilike('email', `%${q.trim()}%`)
  const { data, error } = await req
  if (error) throw error
  return (data ?? []) as AccountHit[]
}

export async function searchPortals(q: string): Promise<PortalHit[]> {
  let req = adminDb
    .from('iptv_portals')
    .select('id, url, username, alive, catalog_pool, region_primary')
    .order('updated_at', { ascending: false })
    .limit(25)
  const t = q.trim()
  if (t) {
    req = req.or(`url.ilike.%${t}%,username.ilike.%${t}%`)
  }
  const { data, error } = await req
  if (error) throw error
  return (data ?? []) as PortalHit[]
}

export async function fetchAssignmentsForAccount(
  accountId: string,
): Promise<AssignmentRow[]> {
  const { data, error } = await adminDb
    .from('user_iptv_portals')
    .select(
      `
      id, portal_id, profile_id, portal_name,
      profiles!user_iptv_portals_profile_id_fkey ( name ),
      iptv_portals ( id, url, username, alive, expiry, max_connections, catalog_pool, region_primary )
    `,
    )
    .eq('account_id', accountId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return ((data ?? []) as Array<Record<string, unknown>>).map((r) =>
    mapAssignmentRow(r, { accountEmail: null }),
  )
}

export async function fetchAssignmentsForPortal(
  portalId: string,
): Promise<AssignmentRow[]> {
  const { data, error } = await adminDb
    .from('user_iptv_portals')
    .select(
      `
      id, portal_id, profile_id, portal_name, account_id,
      profiles!user_iptv_portals_profile_id_fkey ( name ),
      accounts!user_iptv_portals_account_id_fkey ( email ),
      iptv_portals ( id, url, username, alive, expiry, max_connections, catalog_pool, region_primary )
    `,
    )
    .eq('portal_id', portalId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return ((data ?? []) as Array<Record<string, unknown>>).map((r) => {
    const acct = r.accounts as { email?: string | null } | null
    return mapAssignmentRow(r, { accountEmail: acct?.email ?? null })
  })
}

function mapAssignmentRow(
  r: Record<string, unknown>,
  opts: { accountEmail: string | null },
): AssignmentRow {
  const prof = r.profiles as { name?: string } | null
  const portal = r.iptv_portals as {
    id?: string
    url?: string
    username?: string
    alive?: boolean | null
    expiry?: string | null
    max_connections?: string | null
    catalog_pool?: boolean
    region_primary?: string
  } | null
  return {
    id: r.id as string,
    portal_id: (portal?.id ?? r.portal_id) as string,
    profile_id: r.profile_id as string,
    portal_name: (r.portal_name as string) ?? '',
    profile_name: prof?.name ?? 'Profile',
    account_email: opts.accountEmail,
    url: portal?.url ?? '',
    username: portal?.username ?? '',
    alive: portal?.alive ?? null,
    expiry: portal?.expiry ?? null,
    max_connections: portal?.max_connections ?? null,
    catalog_pool: portal?.catalog_pool === true,
    region_primary: portal?.region_primary ?? 'UNKNOWN',
  }
}

export async function countAssignmentsForAccounts(
  accountIds: string[],
): Promise<Record<string, number>> {
  if (accountIds.length === 0) return {}
  const { data, error } = await adminDb
    .from('user_iptv_portals')
    .select('account_id')
    .in('account_id', accountIds)
  if (error) throw error
  const out: Record<string, number> = {}
  for (const row of data ?? []) {
    const id = (row as { account_id: string }).account_id
    out[id] = (out[id] ?? 0) + 1
  }
  return out
}

export async function assignPortal(opts: {
  profileId: string
  portalId: string
  burnCredit?: boolean
  bumpDealt?: boolean
}): Promise<string> {
  const { data, error } = await adminDb.rpc('admin_assign_iptv_portal', {
    p_profile_id: opts.profileId,
    p_portal_id: opts.portalId,
    p_burn_credit: opts.burnCredit ?? false,
    p_bump_dealt: opts.bumpDealt ?? true,
  })
  if (error) throw new Error(errMessage(error, 'Assign failed'))
  return data as string
}

export async function unassignPortal(assignmentId: string): Promise<void> {
  const { error } = await adminDb.rpc('admin_unassign_iptv_portal', {
    p_assignment_id: assignmentId,
  })
  if (error) throw new Error(errMessage(error, 'Unassign failed'))
}
