import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

/**
 * Authenticated self-service account deletion.
 * Verifies the caller's JWT, then deletes auth.users (cascades profiles + settings).
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

  let confirmEmail: string | undefined
  try {
    const body = (await req.json()) as { confirmEmail?: string }
    confirmEmail = body.confirmEmail?.trim()
  } catch {
    return json({ error: 'Invalid JSON body' }, 400, req)
  }

  if (!confirmEmail || confirmEmail.toLowerCase() !== (user.email ?? '').toLowerCase()) {
    return json(
      { error: 'Type your account email to confirm deletion.' },
      400,
      req,
    )
  }

  const admin = createClient(supabaseUrl, serviceKey)
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id)
  if (deleteError) {
    return json({ error: deleteError.message }, 500, req)
  }

  return json({ ok: true }, 200, req)
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
