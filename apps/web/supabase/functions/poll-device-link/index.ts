import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

/**
 * TV polls with device_code. When approved, mints a new GoTrue session
 * (same magiclink/OTP pattern as mint-desktop-session), labels it for Android
 * TV, marks the row consumed, and returns tokens once.
 */

const TV_USER_AGENT = 'Forja Android TV (device link)'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders(req) })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405, req)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: 'Server misconfigured' }, 500, req)
  }

  let body: { device_code?: unknown }
  try {
    body = (await req.json()) as { device_code?: unknown }
  } catch {
    return json({ error: 'Invalid JSON body' }, 400, req)
  }

  const deviceCode =
    typeof body.device_code === 'string' ? body.device_code.trim() : ''
  if (!deviceCode || deviceCode.length < 16) {
    return json({ error: 'device_code required' }, 400, req)
  }

  const admin = createClient(supabaseUrl, serviceKey)
  await admin.rpc('expire_device_link_codes')

  const { data: row, error: lookupError } = await admin
    .from('device_link_codes')
    .select('id, status, user_id, expires_at')
    .eq('device_code', deviceCode)
    .maybeSingle()

  if (lookupError) {
    return json({ error: lookupError.message }, 500, req)
  }
  if (!row) {
    return json({ error: 'Unknown device_code', status: 'expired' }, 404, req)
  }

  if (row.status === 'expired' || new Date(row.expires_at).getTime() < Date.now()) {
    if (row.status !== 'expired') {
      await admin
        .from('device_link_codes')
        .update({ status: 'expired' })
        .eq('id', row.id)
    }
    return json({ error: 'expired', status: 'expired' }, 410, req)
  }

  if (row.status === 'denied') {
    return json({ error: 'denied', status: 'denied' }, 403, req)
  }

  if (row.status === 'consumed') {
    return json({ error: 'already_used', status: 'consumed' }, 409, req)
  }

  if (row.status === 'pending') {
    return json({ status: 'pending' }, 202, req)
  }

  if (row.status !== 'approved' || !row.user_id) {
    return json({ error: 'invalid_state', status: row.status }, 409, req)
  }

  // Claim before mint so two polls never both receive tokens.
  const { data: claimed, error: claimError } = await admin
    .from('device_link_codes')
    .update({
      status: 'consumed',
      consumed_at: new Date().toISOString(),
    })
    .eq('id', row.id)
    .eq('status', 'approved')
    .select('user_id')
    .maybeSingle()

  if (claimError) {
    return json({ error: claimError.message }, 500, req)
  }
  if (!claimed?.user_id) {
    return json({ error: 'already_used', status: 'consumed' }, 409, req)
  }

  const {
    data: { user },
    error: userError,
  } = await admin.auth.admin.getUserById(claimed.user_id)
  const email = user?.email?.trim()
  if (userError || !email) {
    return json(
      {
        error:
          'This account has no email; TV device link needs an email on the account.',
      },
      400,
      req,
    )
  }

  const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email,
  })
  const hashedToken = linkData?.properties?.hashed_token
  if (linkError || !hashedToken) {
    return json(
      { error: linkError?.message ?? 'Could not mint a TV session.' },
      500,
      req,
    )
  }

  const mintClient = createClient(supabaseUrl, anonKey)
  const { data: verified, error: verifyError } = await mintClient.auth.verifyOtp({
    type: 'email',
    token_hash: hashedToken,
  })

  const session = verified.session
  if (verifyError || !session?.access_token || !session.refresh_token) {
    return json(
      { error: verifyError?.message ?? 'Could not create a TV session.' },
      500,
      req,
    )
  }

  const sessionId = sessionIdFromJwt(session.access_token)
  if (sessionId) {
    await admin.rpc('service_label_auth_session', {
      p_session_id: sessionId,
      p_user_agent: TV_USER_AGENT,
    })
    await admin.rpc('service_revoke_other_labeled_sessions', {
      p_user_id: claimed.user_id,
      p_keep_session_id: sessionId,
      p_user_agent: TV_USER_AGENT,
    })
  }

  return json(
    {
      status: 'approved',
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      expires_in: session.expires_in,
      expires_at: session.expires_at,
      token_type: session.token_type ?? 'bearer',
    },
    200,
    req,
  )
})

function sessionIdFromJwt(accessToken: string): string | null {
  try {
    const parts = accessToken.split('.')
    if (parts.length < 2 || !parts[1]) return null
    const json = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'))
    const payload = JSON.parse(json) as { session_id?: unknown }
    return typeof payload.session_id === 'string' ? payload.session_id : null
  } catch {
    return null
  }
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
