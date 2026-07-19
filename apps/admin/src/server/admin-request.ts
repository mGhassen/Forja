import { createClient, type SupabaseClient } from '@supabase/supabase-js'

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

/** Bearer JWT + is_admin() for admin API routes. */
export async function authedAdmin(
  request: Request,
): Promise<
  | { sb: SupabaseClient; user: { id: string }; error?: undefined }
  | { error: Response; sb?: undefined; user?: undefined }
> {
  const auth = request.headers.get('authorization') ?? ''
  const token = auth.replace(/^Bearer\s+/i, '').trim()
  if (!token) return { error: json({ error: 'not authenticated' }, 401) }

  const url =
    process.env.SUPABASE_URL?.trim() ||
    process.env.VITE_SUPABASE_URL?.trim() ||
    ''
  const anon =
    process.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() ||
    process.env.SUPABASE_PUBLISHABLE_KEY?.trim() ||
    ''
  if (!url || !anon) {
    return { error: json({ error: 'Supabase env missing' }, 500) }
  }

  const sb = createClient(url, anon, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  })
  const {
    data: { user },
    error: userErr,
  } = await sb.auth.getUser(token)
  if (userErr || !user) {
    return { error: json({ error: 'not authenticated' }, 401) }
  }

  const { data: admin, error: adminErr } = await sb.rpc('is_admin')
  if (adminErr) return { error: json({ error: adminErr.message }, 500) }
  if (!admin) return { error: json({ error: 'admin only' }, 403) }

  return { sb, user: { id: user.id } }
}
