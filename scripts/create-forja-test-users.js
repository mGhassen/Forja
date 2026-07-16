#!/usr/bin/env node

/**
 * Create local Forja portal test users + sample `user_settings` rows.
 * Run after `supabase db reset` (or via scripts/reset-forja-supabase.js).
 *
 * Auth users cannot be created in seed.sql (need Admin Auth API), so settings
 * seed lives here too — `user_settings.user_id` references auth.users.
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
  },
  {
    email: 'demo@forja.local',
    password: 'password123',
    label: 'Demo',
    seedVariant: 'light',
  },
]

const nowMs = Date.now()

function portalKey(url, username, password) {
  return `${url}|${username}|${password}`.toLowerCase()
}

function settingsFor(variant) {
  const portalA = {
    url: 'http://demo-iptv.forja.local:8080',
    username: 'forja_user',
    password: 'demo_pass_1',
    source: 'seed',
    name: 'Forja Demo Xtream',
    expiry: '2027-12-31',
    max: '3',
    active: '1',
  }
  const portalB = {
    url: 'http://backup-iptv.forja.local:25461',
    username: 'forja_backup',
    password: 'demo_pass_2',
    source: 'seed',
    name: 'Backup Panel',
    expiry: '2026-09-15',
    max: '1',
    active: '0',
  }

  const iptvFull = {
    portals: [portalA, portalB],
    favoriteKeys: [portalKey(portalA.url, portalA.username, portalA.password)],
    m3uPlaylists: [
      {
        id: `seed_m3u_${nowMs.toString(16)}`,
        name: 'Public demo M3U',
        sourceUrl: 'https://iptv-org.github.io/iptv/countries/us.m3u',
        addedAt: nowMs - 86_400_000,
        updatedAt: nowMs,
        channels: [
          {
            n: 'Example News',
            u: 'https://example.com/live/news.m3u8',
            g: 'News',
            l: '',
          },
          {
            n: 'Example Sports',
            u: 'https://example.com/live/sports.m3u8',
            g: 'Sports',
            l: '',
          },
        ],
      },
    ],
  }

  const iptvLight = {
    portals: [portalA],
    favoriteKeys: [],
    m3uPlaylists: [],
  }

  const preferences = {
    play_source_torrent_enabled: true,
    play_source_stremio_enabled: true,
    play_source_webstreaming_enabled: true,
    preferred_audio_lang: variant === 'full' ? 'English' : 'None',
    avoid_unsupported_audio: true,
    auto_next_episode: true,
    auto_skip_intro: variant === 'full',
    iptv_epg_enabled: true,
    max_playback_height: variant === 'full' ? 1080 : 0,
  }

  const providers = {
    stream_provider_order: [
      'videasy',
      'vidlink',
      'vidsrc',
      'vidsrcwin',
      'vixsrc',
      'vidnest',
      'vidzee',
      'vidrock',
      'vidfast',
      '2embed',
      'autoembed',
      'vidlove',
      'vidsrcsbs',
      '111movies',
      'moviesapi',
      'service111477',
      'webstreamr',
    ],
    anime_provider_order: [
      'miruro:bee',
      'allanime:Default',
      'allanime:Yt-mp4',
      'allanime:S-mp4',
      'allanime:Luf-Mp4',
      'vidnest:hianime',
      'vidnest:animepahe',
      'megaplay',
      'vidwish',
      'miruro:zoro',
      'miruro:kiwi',
      'miruro:ally',
      'miruro:hop',
      'miruro:bonk',
      'miruro:moo',
    ],
    asian_drama_provider_order: [
      'kisskh.co',
      'kisskh.nl',
      'kisskh.ovh',
      'kisskh.la',
      'kisskh.do',
    ],
  }

  const stremio = {
    addons: [
      {
        baseUrl: 'https://v3-cinemeta.strem.io/manifest.json',
        name: 'Cinemeta',
        description: 'Official catalog addon (seed)',
      },
      {
        baseUrl: 'https://torrentio.strem.fun/manifest.json',
        name: 'Torrentio',
        description: 'Torrent streams (seed)',
      },
    ],
  }

  return {
    iptv: variant === 'full' ? iptvFull : iptvLight,
    preferences,
    providers,
    stremio: variant === 'full' ? stremio : { addons: [stremio.addons[0]] },
  }
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

async function ensureProfiles(admin, userId, variant) {
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
    .eq('user_id', userId)
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
        user_id: userId,
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

async function seedUserSettings(admin, userId, profile, variant) {
  const domains = settingsFor(variant)
  const now = new Date().toISOString()
  const rows = Object.entries(domains).map(([domain, payload]) => ({
    user_id: userId,
    profile_id: profile.id,
    domain,
    payload,
    updated_at: now,
  }))

  const { error } = await admin.from('user_settings').upsert(rows)
  if (error) throw error
  console.log(
    `    · ${profile.name}: ${rows.map((r) => r.domain).join(', ')} (${variant})`,
  )
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

  console.log('Creating Forja test users + settings seed…')
  for (const user of TEST_USERS) {
    const userId = await ensureUser(admin, user)
    const profiles = await ensureProfiles(admin, userId, user.seedVariant)
    for (const profile of profiles) {
      await seedUserSettings(admin, userId, profile, profile.settings)
    }
  }
  console.log('Done.')
}

main().catch((err) => {
  console.error(err.message || err)
  process.exit(1)
})
