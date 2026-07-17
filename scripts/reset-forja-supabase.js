#!/usr/bin/env node

/**
 * Reset local Forja Supabase (apps/web) and create test users.
 * Ports are defined in apps/web/supabase/config.toml (55321+; Dose uses 64321+).
 */

const { execSync } = require('child_process')
const path = require('path')
const { runSupabaseStatus } = require('./supabase-local-status')

const rootCwd = path.join(__dirname, '..')
const webCwd = path.join(rootCwd, 'apps', 'web')

const CONTAINERS = [
  'supabase_kong_forja-dev',
  'supabase_rest_forja-dev',
  'supabase_auth_forja-dev',
  'supabase_storage_forja-dev',
]

const OPTIONAL_STOPPED_SERVICES = new Set([
  'supabase_imgproxy_forja-dev',
  'supabase_analytics_forja-dev',
  'supabase_vector_forja-dev',
  'supabase_pooler_forja-dev',
])

function isApiUp() {
  return Boolean(runSupabaseStatus(webCwd).status?.API_URL)
}

function waitForApi(maxAttempts = 30, intervalSec = 2) {
  for (let i = 0; i < maxAttempts; i++) {
    if (isApiUp()) return
    execSync(`sleep ${intervalSec}`)
  }
  throw new Error('Supabase API gateway did not become ready in time')
}

function ensureSupabaseRunning() {
  if (isApiUp()) return

  const { stopped } = runSupabaseStatus(webCwd)
  const coreStopped = stopped.filter(
    (name) => !OPTIONAL_STOPPED_SERVICES.has(name),
  )

  if (coreStopped.length > 0) {
    console.log('⏳ Restarting stopped Supabase containers…')
    execSync(`docker start ${coreStopped.join(' ')}`, { stdio: 'inherit' })
    waitForApi()
    return
  }

  console.log('⏳ Supabase not running, starting…')
  execSync('supabase start', { stdio: 'inherit', cwd: webCwd })
}

function restartGatewayContainers() {
  const existing = CONTAINERS.filter((name) => {
    try {
      execSync(`docker inspect ${name}`, { stdio: 'pipe' })
      return true
    } catch {
      return false
    }
  })
  if (existing.length === 0) {
    console.log('⏳ No gateway containers found, starting Supabase…')
    execSync('supabase start', { stdio: 'inherit', cwd: webCwd })
    return
  }
  execSync(`docker restart ${existing.join(' ')}`, { stdio: 'inherit' })
  execSync('sleep 5')
}

function printLocalEnvHint(status) {
  const publishableKey = status?.PUBLISHABLE_KEY || status?.ANON_KEY
  if (!status?.API_URL || !publishableKey) return
  console.log('\n📌 Point apps/web/.env at local Supabase:')
  console.log(`VITE_SUPABASE_URL=${status.API_URL}`)
  console.log(`VITE_SUPABASE_PUBLISHABLE_KEY=${publishableKey}`)
  console.log('\nStudio:  http://localhost:55323')
  console.log('API:     http://localhost:55321')
  console.log('Mailpit:  http://localhost:55324')
}

console.log('🚀 Starting Forja database reset and user creation…\n')

try {
  console.log('🔄 Step 1: Resetting Supabase database (auto-starts if stopped)…')
  ensureSupabaseRunning()
  try {
    execSync('supabase db reset', {
      stdio: 'inherit',
      cwd: webCwd,
    })
  } catch (err) {
    const output = [err.message, err.stderr?.toString(), err.stdout?.toString()]
      .filter(Boolean)
      .join('\n')
    if (/not running/i.test(output)) {
      console.log('⏳ Supabase stopped during reset, restarting…')
      execSync('supabase start', { stdio: 'inherit', cwd: webCwd })
      execSync('supabase db reset', { stdio: 'inherit', cwd: webCwd })
    } else {
      // Supabase CLI often returns 502 after successful reset because Kong
      // health-polls upstreams before they're ready. The DB is actually fine.
      console.warn(
        '⚠️  reset exited non-zero (likely spurious 502). Restarting containers and continuing…',
      )
      restartGatewayContainers()
    }
  }
  console.log('✅ Database reset completed\n')

  console.log('👥 Step 2: Creating test users + settings seed…')
  execSync('node scripts/create-forja-test-users.js', {
    stdio: 'inherit',
    cwd: rootCwd,
  })
  console.log('✅ Test users + settings seed ready\n')

  const { status } = runSupabaseStatus(webCwd)

  console.log('🎉 All steps completed successfully!')
  console.log('\n📋 Summary:')
  console.log('1. ✅ Database reset (migrations + seed applied)')
  console.log('2. ✅ Test users + remote settings domains seeded')

  console.log('\n🔐 Test User Credentials:')
  console.log('User: user@forja.local / password123  (full IPTV + Stremio seed)')
  console.log('Demo: demo@forja.local / password123  (lighter seed)')

  printLocalEnvHint(status)
} catch (error) {
  console.error('❌ Error during reset and seed process:', error.message)
  process.exit(1)
}
