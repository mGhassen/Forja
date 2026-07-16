#!/usr/bin/env node

/**
 * Create local Forja portal test users via Supabase Auth Admin API.
 * Run after `supabase db reset` (or via scripts/reset-forja-supabase.js).
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
  },
  {
    email: 'demo@forja.local',
    password: 'password123',
    label: 'Demo',
  },
]

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
    return
  }

  const { error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  })
  if (error) throw error
  console.log(`  ✓ ${label}: ${email}`)
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

  console.log('Creating Forja test users…')
  for (const user of TEST_USERS) {
    await ensureUser(admin, user)
  }
  console.log('Done.')
}

main().catch((err) => {
  console.error(err.message || err)
  process.exit(1)
})
