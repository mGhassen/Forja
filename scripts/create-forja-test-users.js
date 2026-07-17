#!/usr/bin/env node

/**
 * Create local Forja portal test users + profile_settings + iptv_portals +
 * user_iptv_portals. Run after `supabase db reset`.
 *
 * Auth users cannot be created in seed.sql (need Admin Auth API).
 *
 * Correct model:
 * - iptv_portals = shared credentials (url, username, password, expiry, max)
 * - user_iptv_portals.portal_name = per-profile label
 * - profile_settings.playback = full prefs (incl. play_source_*)
 * - profile_settings.navigation = navbar visibleIds + defaultTab
 * - profile_settings.iptv = M3U URLs only (no portals)
 */

const path = require('path')
const { createRequire } = require('module')
const { runSupabaseStatus } = require('./supabase-local-status')

const webCwd = path.join(__dirname, '..', 'apps', 'web')
const requireFromWeb = createRequire(path.join(webCwd, 'package.json'))
const { createClient } = requireFromWeb('@supabase/supabase-js')

const TEST_USERS = [
  {
    email: 'user@forja.local',
    password: 'password123',
    label: 'User',
    seedVariant: 'full',
    isAdmin: true,
  },
  {
    email: 'demo@forja.local',
    password: 'password123',
    label: 'Demo',
    seedVariant: 'light',
    isAdmin: false,
  },
]

const nowMs = Date.now()

const PORTAL_A = {
  url: 'http://demo-iptv.forja.local:8080',
  username: 'forja_user',
  password: 'demo_pass_1',
  source: 'seed',
  expiry: '2027-12-31',
  max_connections: '3',
}

const PORTAL_B = {
  url: 'http://backup-iptv.forja.local:25461',
  username: 'forja_backup',
  password: 'demo_pass_2',
  source: 'seed',
  expiry: '2026-09-15',
  max_connections: '1',
}

async function upsertIptvPortal(admin, portal, actorId) {
  const now = new Date().toISOString()
  const { data: existing, error: findError } = await admin
    .from('iptv_portals')
    .select('id')
    .ilike('url', portal.url.trim())
    .ilike('username', portal.username.trim())
    .maybeSingle()
  if (findError) throw findError

  if (existing?.id) {
    const { data, error } = await admin
      .from('iptv_portals')
      .update({
        password: portal.password,
        source: portal.source,
        expiry: portal.expiry,
        max_connections: portal.max_connections,
        updated_at: now,
        updated_by: actorId,
      })
      .eq('id', existing.id)
      .select('id')
      .single()
    if (error) throw error
    return data.id
  }

  const { data, error } = await admin
    .from('iptv_portals')
    .insert({
      ...portal,
      created_by: actorId,
      updated_by: actorId,
    })
    .select('id')
    .single()
  if (error) throw error
  return data.id
}

/** Full playback prefs for Home profile — includes play_source_* modes. */
function fullPlaybackPayload() {
  return {
    play_source_torrent_enabled: true,
    play_source_stremio_enabled: true,
    play_source_webstreaming_enabled: true,
    preferred_audio_lang: 'English',
    avoid_unsupported_audio: true,
    auto_next_episode: true,
    auto_skip_intro: true,
    iptv_epg_enabled: true,
    max_playback_height: 1080,
  }
}

function lightPlaybackPayload() {
  return {
    play_source_torrent_enabled: true,
    play_source_stremio_enabled: true,
    play_source_webstreaming_enabled: true,
    preferred_audio_lang: 'None',
    avoid_unsupported_audio: true,
    auto_next_episode: true,
    auto_skip_intro: false,
    iptv_epg_enabled: true,
    max_playback_height: 0,
  }
}

function navigationPayload(variant) {
  if (variant === 'full') {
    return {
      visibleIds: [
        'home',
        'search',
        'anime',
        'asian_drama',
        'iptv',
        'live_matches',
        'mylist',
        'settings',
      ],
      defaultTab: 'home',
    }
  }
  return {
    visibleIds: ['home', 'search', 'iptv', 'settings'],
    defaultTab: 'home',
  }
}

/** profile_settings only — no portal assignments here. */
function settingsPayloadFor(variant) {
  const stremioAddons =
    variant === 'full'
      ? [
          {
            baseUrl: 'https://v3-cinemeta.strem.io/manifest.json',
            name: 'Cinemeta',
          },
          {
            baseUrl: 'https://torrentio.strem.fun/manifest.json',
            name: 'Torrentio',
          },
        ]
      : [
          {
            baseUrl: 'https://v3-cinemeta.strem.io/manifest.json',
            name: 'Cinemeta',
          },
        ]

  const payload = {
    playback:
      variant === 'full' ? fullPlaybackPayload() : lightPlaybackPayload(),
    navigation: navigationPayload(variant),
    connectedServices: { stremio: { addons: stremioAddons } },
  }

  if (variant === 'full') {
    payload.iptv = {
      m3uPlaylists: [
        {
          id: `seed_m3u_${nowMs.toString(16)}`,
          name: 'Public demo M3U',
          sourceUrl: 'https://iptv-org.github.io/iptv/countries/us.m3u',
          addedAt: nowMs - 86_400_000,
          updatedAt: nowMs,
        },
      ],
    }
  }

  return payload
}

/** Assignments go to user_iptv_portals — portal_name is the profile label. */
function portalAssignmentsFor(variant, portalIds) {
  const [portalAId, portalBId] = portalIds
  if (variant === 'full') {
    return [
      {
        portal_id: portalAId,
        portal_name: 'Home XT',
        favorite: true,
      },
      {
        portal_id: portalBId,
        portal_name: 'Backup',
        favorite: false,
      },
    ]
  }
  return [
    {
      portal_id: portalAId,
      portal_name: 'Demo portal',
      favorite: false,
    },
  ]
}

async function ensureUser(admin, { email, password, label }) {
  const { data: listed, error: listError } = await admin.auth.admin.listUsers({
    page: 1,
    perPage: 200,
  })
  if (listError) throw listError

  const existing = listed.users.find(
    (u) => u.email?.toLowerCase() === email.toLowerCase(),
  )

  if (existing) {
    const { error } = await admin.auth.admin.updateUserById(existing.id, {
      password,
      email_confirm: true,
    })
    if (error) throw error
    console.log(`  ↻ ${label}: ${email} (updated password)`)
    return existing.id
  }

  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  })
  if (error) throw error
  console.log(`  ✓ ${label}: ${email}`)
  return data.user.id
}

async function ensureAccount(admin, userId, email, isAdmin) {
  const now = new Date().toISOString()
  const { error } = await admin.from('accounts').upsert({
    id: userId,
    email,
    is_admin: isAdmin,
    updated_at: now,
  })
  if (error) throw error
  if (isAdmin) {
    console.log(`    · accounts.is_admin = true`)
  }
}

async function ensureProfiles(admin, accountId, variant) {
  const desired =
    variant === 'full'
      ? [
          { name: 'Home', color: '#1ce783', avatar_key: 'forge', settings: 'full' },
          { name: 'Kids', color: '#ff4d1c', avatar_key: 'flame', settings: 'light' },
          { name: 'Guest', color: '#5aa9ff', avatar_key: 'orbit', settings: 'light' },
        ]
      : [
          {
            name: 'Demo',
            color: '#c084fc',
            avatar_key: 'pixel',
            settings: 'light',
          },
        ]

  const { data: current, error: loadError } = await admin
    .from('profiles')
    .select('*')
    .eq('account_id', accountId)
    .order('created_at')
  if (loadError) throw loadError

  const profiles = [...(current ?? [])]
  if (profiles.length > 0 && !desired.some((item) => item.name === profiles[0].name)) {
    const first = desired[0]
    const { data, error } = await admin
      .from('profiles')
      .update({
        name: first.name,
        color: first.color,
        avatar_key: first.avatar_key,
      })
      .eq('id', profiles[0].id)
      .select('*')
      .single()
    if (error) throw error
    profiles[0] = data
  }

  for (const item of desired) {
    const existing = profiles.find((profile) => profile.name === item.name)
    if (existing) {
      const { data, error } = await admin
        .from('profiles')
        .update({ color: item.color, avatar_key: item.avatar_key })
        .eq('id', existing.id)
        .select('*')
        .single()
      if (error) throw error
      Object.assign(existing, data)
      continue
    }
    const { data, error } = await admin
      .from('profiles')
      .insert({
        account_id: accountId,
        name: item.name,
        color: item.color,
        avatar_key: item.avatar_key,
      })
      .select('*')
      .single()
    if (error) throw error
    profiles.push(data)
  }

  return desired.map((item) => ({
    ...profiles.find((profile) => profile.name === item.name),
    settings: item.settings,
  }))
}

async function seedProfileSettings(admin, accountId, profile, variant) {
  const now = new Date().toISOString()
  const payload = settingsPayloadFor(variant)
  const { error } = await admin.from('profile_settings').upsert({
    profile_id: profile.id,
    account_id: accountId,
    payload,
    updated_at: now,
    updated_by: accountId,
  })
  if (error) throw error
  const sections = Object.keys(payload).join(', ')
  console.log(`    · ${profile.name}: profile_settings (${variant}) [${sections}]`)
}

async function seedUserIptvPortals(admin, accountId, profile, variant, portalIds) {
  const now = new Date().toISOString()
  const { error: delError } = await admin
    .from('user_iptv_portals')
    .delete()
    .eq('account_id', accountId)
    .eq('profile_id', profile.id)
  if (delError) throw delError

  const rows = portalAssignmentsFor(variant, portalIds).map((row) => ({
    account_id: accountId,
    profile_id: profile.id,
    portal_id: row.portal_id,
    portal_name: row.portal_name,
    favorite: row.favorite,
    created_by: accountId,
    updated_by: accountId,
    updated_at: now,
  }))

  if (rows.length) {
    const { error } = await admin.from('user_iptv_portals').insert(rows)
    if (error) throw error
  }
  const names = rows.map((r) => r.portal_name).join(', ')
  console.log(`    · ${profile.name}: user_iptv_portals [${names || 'none'}]`)
}

async function main() {
  const { status } = runSupabaseStatus(webCwd)
  if (!status) {
    throw new Error(
      'Could not parse `supabase status -o json`. Is local Supabase running?',
    )
  }
  const url = status.API_URL
  const serviceKey = status.SERVICE_ROLE_KEY
  if (!url || !serviceKey) {
    throw new Error(
      'Missing API_URL or SERVICE_ROLE_KEY from `supabase status`. Is local Supabase running?',
    )
  }

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  console.log(
    'Creating Forja test users + profile_settings + user_iptv_portals…',
  )

  let portalAId = null
  let portalBId = null

  for (const user of TEST_USERS) {
    const userId = await ensureUser(admin, user)
    await ensureAccount(admin, userId, user.email, user.isAdmin)

    if (!portalAId) {
      portalAId = await upsertIptvPortal(admin, PORTAL_A, userId)
      portalBId = await upsertIptvPortal(admin, PORTAL_B, userId)
      console.log(
        `    · iptv_portals seeded (${portalAId.slice(0, 8)}…, ${portalBId.slice(0, 8)}…)`,
      )
    }

    const profiles = await ensureProfiles(admin, userId, user.seedVariant)
    for (const profile of profiles) {
      await seedProfileSettings(admin, userId, profile, profile.settings)
      await seedUserIptvPortals(admin, userId, profile, profile.settings, [
        portalAId,
        portalBId,
      ])
    }
  }
  console.log('Done.')
  console.log('Admin: user@forja.local / password123 → /admin')
}

main().catch((err) => {
  console.error(err.message || err)
  process.exit(1)
})
