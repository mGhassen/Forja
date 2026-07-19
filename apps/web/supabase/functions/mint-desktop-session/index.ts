import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

/**
 * Mints a *new* GoTrue session for the desktop app from the caller's JWT.
 * Portal keeps its own session — do not move / wipe the browser refresh token.
 */
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(req),
    })
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

  const email = user.email?.trim()
  if (!email) {
    return json(
      { error: 'This account has no email; desktop Web login needs an email.' },
      400,
      req,
    )
  }

  const admin = createClient(supabaseUrl, serviceKey)
  const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email,
  })

  const hashedToken = linkData?.properties?.hashed_token
  if (linkError || !hashedToken) {
    return json(
      { error: linkError?.message ?? 'Could not mint a desktop session.' },
      500,
      req,
    )
  }

  // Verify on a fresh anon client so we only create session B server-side.
  const mintClient = createClient(supabaseUrl, anonKey)
  // hashed_token from generateLink(magiclink) verifies as type `email`.
  const { data: verified, error: verifyError } = await mintClient.auth.verifyOtp({
    type: 'email',
    token_hash: hashedToken,
  })

  const session = verified.session
  if (verifyError || !session?.access_token || !session.refresh_token) {
    return json(
      { error: verifyError?.message ?? 'Could not create a desktop session.' },
      500,
      req,
    )
  }

  return json(
    {
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
