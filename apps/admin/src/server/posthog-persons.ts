/** Server-only PostHog persons lookup (personal API key — never VITE_*). */

export type PosthogPersonRuntime = {
  distinctId: string
  appVersion: string | null
  platform: string | null
  osVersion: string | null
  arch: string | null
  lastSeenAt: string | null
  memberNumber: number | null
}

export type PosthogPersonsResult = {
  configured: boolean
  persons: Record<string, PosthogPersonRuntime>
  error?: string
}

type PosthogEnv = {
  apiKey: string
  /** Raw env: numeric id or project API token (`phc_…`). */
  projectRef: string
  host: string
}

/** process-lifetime cache: phc_/numeric → numeric project id string */
const resolvedProjectIds = new Map<string, string>()

function posthogEnv(): PosthogEnv | null {
  const apiKey =
    process.env.POSTHOG_PERSONAL_API_KEY?.trim() ||
    process.env.POSTHOG_PRIVATE_API_KEY?.trim() ||
    ''
  const projectRef =
    process.env.POSTHOG_PROJECT_ID?.trim() ||
    process.env.POSTHOG_PROJECT_API_ID?.trim() ||
    ''
  if (!apiKey || !projectRef) return null
  const hostRaw =
    process.env.POSTHOG_HOST?.trim() ||
    process.env.POSTHOG_API_HOST?.trim() ||
    'https://us.i.posthog.com'
  const host = hostRaw.replace(/\/$/, '')
  return { apiKey, projectRef, host }
}

function strProp(v: unknown): string | null {
  if (v == null) return null
  if (typeof v === 'string') {
    const t = v.trim()
    return t.length ? t : null
  }
  if (typeof v === 'number' || typeof v === 'boolean') return String(v)
  return null
}

function numProp(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return Math.trunc(v)
  if (typeof v === 'string') {
    const n = Number(v)
    return Number.isFinite(n) ? Math.trunc(n) : null
  }
  return null
}

function isUuid(id: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    id,
  )
}

function isNumericProjectId(ref: string): boolean {
  return /^\d+$/.test(ref)
}

/**
 * PostHog REST paths need the numeric project id.
 *
 * Env may be that id, or the project API token (`phc_…`).
 * Scoped personal keys cannot hit GET /api/projects/ (org list) — resolve via a
 * project-based GET with ?token=phc_… (PostHog overrides path id from the token).
 */
async function resolveNumericProjectId(env: PosthogEnv): Promise<string> {
  const ref = env.projectRef
  if (isNumericProjectId(ref)) return ref

  const cached = resolvedProjectIds.get(ref)
  if (cached) return cached

  // Path id is a placeholder; ?token= selects the real project (GET-only token parse).
  const url = new URL(`${env.host}/api/projects/0/`)
  url.searchParams.set('token', ref)
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${env.apiKey}` },
  })
  const json = (await res.json().catch(() => ({}))) as {
    id?: number | string
    detail?: string
    error?: string
  }
  if (!res.ok) {
    throw new Error(
      json.error || json.detail || `PostHog project resolve ${res.status}`,
    )
  }
  if (json.id == null) {
    throw new Error('POSTHOG_PROJECT_ID phc_… did not resolve to a project id')
  }
  const numeric = String(json.id)
  resolvedProjectIds.set(ref, numeric)
  return numeric
}

function runtimeFromProperties(
  distinctId: string,
  props: Record<string, unknown>,
): PosthogPersonRuntime {
  return {
    distinctId,
    appVersion: strProp(props.app_version),
    platform: strProp(props.platform),
    osVersion: strProp(props.os_version),
    arch: strProp(props.arch),
    lastSeenAt: strProp(props.last_seen_at),
    memberNumber: numProp(props.member_number),
  }
}

type ResolvedEnv = PosthogEnv & { projectId: string }

/** HogQL batch: map distinct_id → runtime props. */
async function fetchViaHogQl(
  env: ResolvedEnv,
  ids: string[],
): Promise<Record<string, PosthogPersonRuntime>> {
  const list = ids.map((id) => `'${id}'`).join(', ')
  const query = `
SELECT
  arrayJoin(distinct_ids) AS distinct_id,
  properties.app_version AS app_version,
  properties.platform AS platform,
  properties.os_version AS os_version,
  properties.arch AS arch,
  properties.last_seen_at AS last_seen_at,
  properties.member_number AS member_number
FROM persons
WHERE hasAny(distinct_ids, [${list}])
LIMIT ${Math.min(ids.length * 4, 500)}
`.trim()

  const res = await fetch(
    `${env.host}/api/projects/${encodeURIComponent(env.projectId)}/query/`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        query: { kind: 'HogQLQuery', query },
        name: 'forja_admin_account_runtimes',
      }),
    },
  )
  const json = (await res.json().catch(() => ({}))) as {
    results?: unknown[][]
    columns?: string[]
    error?: string
    detail?: string
  }
  if (!res.ok) {
    throw new Error(json.error || json.detail || `PostHog query ${res.status}`)
  }

  const cols = (json.columns ?? []).map((c) => c.toLowerCase())
  const idx = (name: string) => cols.indexOf(name)
  const out: Record<string, PosthogPersonRuntime> = {}
  for (const row of json.results ?? []) {
    if (!Array.isArray(row)) continue
    const distinctId = strProp(row[idx('distinct_id')])
    if (!distinctId || !ids.includes(distinctId)) continue
    out[distinctId] = {
      distinctId,
      appVersion: strProp(row[idx('app_version')]),
      platform: strProp(row[idx('platform')]),
      osVersion: strProp(row[idx('os_version')]),
      arch: strProp(row[idx('arch')]),
      lastSeenAt: strProp(row[idx('last_seen_at')]),
      memberNumber: numProp(row[idx('member_number')]),
    }
  }
  return out
}

/** Fallback: one persons list call per distinct_id (capped concurrency). */
async function fetchViaPersonsApi(
  env: ResolvedEnv,
  ids: string[],
): Promise<Record<string, PosthogPersonRuntime>> {
  const out: Record<string, PosthogPersonRuntime> = {}
  const concurrency = 6
  let cursor = 0
  let lastErr: string | null = null

  async function worker() {
    while (cursor < ids.length) {
      const i = cursor++
      const id = ids[i]!
      const url = new URL(
        `${env.host}/api/projects/${encodeURIComponent(env.projectId)}/persons/`,
      )
      url.searchParams.set('distinct_id', id)
      const res = await fetch(url, {
        headers: { Authorization: `Bearer ${env.apiKey}` },
      })
      if (!res.ok) {
        const body = (await res.json().catch(() => ({}))) as {
          detail?: string
          error?: string
        }
        lastErr = body.error || body.detail || `PostHog persons ${res.status}`
        continue
      }
      const json = (await res.json().catch(() => ({}))) as {
        results?: Array<{
          distinct_ids?: string[]
          properties?: Record<string, unknown>
        }>
      }
      const person = json.results?.[0]
      if (!person?.properties) continue
      out[id] = runtimeFromProperties(id, person.properties)
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(concurrency, ids.length) }, () => worker()),
  )
  if (Object.keys(out).length === 0 && lastErr) {
    throw new Error(lastErr)
  }
  return out
}

/**
 * Load PostHog person runtime props for account UUIDs (distinct ids).
 * Never returns email / display name.
 */
export async function fetchPosthogPersonsByDistinctIds(
  distinctIds: string[],
): Promise<PosthogPersonsResult> {
  const env = posthogEnv()
  if (!env) {
    return { configured: false, persons: {} }
  }

  const ids = [
    ...new Set(distinctIds.map((id) => id.trim()).filter(isUuid)),
  ].slice(0, 100)
  if (ids.length === 0) {
    return { configured: true, persons: {} }
  }

  try {
    const projectId = await resolveNumericProjectId(env)
    const resolved: ResolvedEnv = { ...env, projectId }

    let persons: Record<string, PosthogPersonRuntime>
    let hogErr: string | null = null
    try {
      persons = await fetchViaHogQl(resolved, ids)
    } catch (e) {
      hogErr = e instanceof Error ? e.message : 'HogQL failed'
      persons = await fetchViaPersonsApi(resolved, ids)
    }
    return {
      configured: true,
      persons,
      ...(hogErr && Object.keys(persons).length === 0
        ? { error: hogErr }
        : {}),
    }
  } catch (e) {
    return {
      configured: true,
      persons: {},
      error: e instanceof Error ? e.message : 'PostHog persons failed',
    }
  }
}
