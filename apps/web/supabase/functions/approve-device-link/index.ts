import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

/**
 * Approves a pending device-link user_code for the signed-in portal user.
 * Does not mint a session — TV poll mints on the next successful poll.
 */

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

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return json({ error: 'Unauthorized' }, 401, req)
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  })
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser()
  if (userError || !user) {
    return json({ error: 'Unauthorized' }, 401, req)
  }

  let body: { user_code?: unknown }
  try {
    body = (await req.json()) as { user_code?: unknown }
  } catch {
    return json({ error: 'Invalid JSON body' }, 400, req)
  }

  const rawCode = typeof body.user_code === 'string' ? body.user_code : ''
  const userCode = rawCode.trim().toUpperCase().replace(/[^A-Z0-9]/g, '')
  if (userCode.length < 6 || userCode.length > 12) {
    return json({ error: 'Enter the code shown on your TV.' }, 400, req)
  }

  const admin = createClient(supabaseUrl, serviceKey)
  await admin.rpc('expire_device_link_codes')

  const { data: row, error: lookupError } = await admin
    .from('device_link_codes')
    .select('id, status, expires_at')
    .eq('user_code', userCode)
    .maybeSingle()

  if (lookupError) {
    return json({ error: lookupError.message }, 500, req)
  }
  if (!row) {
    return json({ error: 'That code was not found. Check the TV screen.' }, 404, req)
  }
  if (row.status === 'expired' || new Date(row.expires_at).getTime() < Date.now()) {
    if (row.status !== 'expired') {
      await admin
        .from('device_link_codes')
        .update({ status: 'expired' })
        .eq('id', row.id)
    }
    return json({ error: 'This code has expired. Start again on the TV.' }, 410, req)
  }
  if (row.status === 'consumed') {
    return json({ error: 'This code was already used.' }, 409, req)
  }
  if (row.status === 'denied') {
    return json({ error: 'This code was cancelled.' }, 409, req)
  }
  if (row.status === 'approved') {
    return json({ ok: true, status: 'approved' }, 200, req)
  }
  if (row.status !== 'pending') {
    return json({ error: 'This code cannot be approved.' }, 409, req)
  }

  const { error: updateError } = await admin
    .from('device_link_codes')
    .update({ status: 'approved', user_id: user.id })
    .eq('id', row.id)
    .eq('status', 'pending')

  if (updateError) {
    return json({ error: updateError.message }, 500, req)
  }

  return json({ ok: true, status: 'approved' }, 200, req)
})

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
