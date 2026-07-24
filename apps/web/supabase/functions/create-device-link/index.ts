import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

/**
 * Creates a pending device-link code for Android TV (anon + apikey).
 * Returns user_code (shown on TV / typed on /connect) and device_code (poll secret).
 */

const USER_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const USER_CODE_LENGTH = 8
const EXPIRES_SECONDS = 600
const POLL_INTERVAL_SECONDS = 5

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders(req) })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405, req)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceKey) {
    return json({ error: 'Server misconfigured' }, 500, req)
  }

  const admin = createClient(supabaseUrl, serviceKey)
  await admin.rpc('expire_device_link_codes')

  const verificationUri =
    Deno.env.get('FORJA_WEB_URL')?.replace(/\/$/, '') ?? 'https://www.forjahq.xyz'
  const expiresAt = new Date(Date.now() + EXPIRES_SECONDS * 1000).toISOString()

  for (let attempt = 0; attempt < 8; attempt++) {
    const userCode = randomUserCode()
    const deviceCode = crypto.randomUUID().replace(/-/g, '') + crypto.randomUUID().replace(/-/g, '')

    const { error } = await admin.from('device_link_codes').insert({
      user_code: userCode,
      device_code: deviceCode,
      status: 'pending',
      expires_at: expiresAt,
    })

    if (error) {
      // Unique violation — retry with a new code.
      if (error.code === '23505') continue
      return json({ error: error.message }, 500, req)
    }

    return json(
      {
        user_code: userCode,
        device_code: deviceCode,
        interval: POLL_INTERVAL_SECONDS,
        expires_in: EXPIRES_SECONDS,
        verification_uri: `${verificationUri}/connect`,
        verification_uri_complete: `${verificationUri}/connect?code=${userCode}`,
      },
      200,
      req,
    )
  }

  return json({ error: 'Could not allocate a device code.' }, 500, req)
})

function randomUserCode(): string {
  const bytes = new Uint8Array(USER_CODE_LENGTH)
  crypto.getRandomValues(bytes)
  let out = ''
  for (let i = 0; i < USER_CODE_LENGTH; i++) {
    out += USER_CODE_ALPHABET[bytes[i]! % USER_CODE_ALPHABET.length]
  }
  return out
}

function corsHeaders(req: Request): HeadersInit {
  const origin = req.headers.get('Origin') ?? '*'
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }
}

function json(body: unknown, status: number, req: Request): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(req),
      'Content-Type': 'application/json',
    },
  })
}
