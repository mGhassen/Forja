import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const GITHUB_REPO = Deno.env.get('GITHUB_REPO') ?? 'mGhassen/Forja'

type GhAsset = {
  name: string
  browser_download_url: string
  size: number
}

type GhRelease = {
  tag_name: string
  body: string | null
  published_at: string
  html_url: string
  assets: GhAsset[]
}

function detectPlatform(name: string): string {
  const lower = name.toLowerCase()
  if (lower.includes('windows') || lower.endsWith('.exe') || lower.endsWith('.msi')) {
    return 'windows'
  }
  if (lower.includes('macos') || lower.includes('darwin') || lower.endsWith('.dmg')) {
    return 'macos'
  }
  if (
    lower.includes('linux') ||
    lower.endsWith('.appimage') ||
    lower.endsWith('.deb') ||
    lower.endsWith('.rpm')
  ) {
    return 'linux'
  }
  if (lower.includes('android-tv') || lower.includes('android_tv') || lower.includes('androidtv')) {
    return 'android_tv'
  }
  if (lower.endsWith('.apk') || lower.includes('android')) {
    return 'android_tv'
  }
  if (lower.includes('ios') || lower.endsWith('.ipa')) {
    return 'ios'
  }
  return 'other'
}

Deno.serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!supabaseUrl || !serviceKey) {
      return new Response(JSON.stringify({ error: 'Missing Supabase env' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const githubHeaders: Record<string, string> = {
      Accept: 'application/vnd.github+json',
      'User-Agent': 'forja-sync-github-releases',
    }
    const token = Deno.env.get('GITHUB_TOKEN')
    if (token) githubHeaders.Authorization = `Bearer ${token}`

    const ghRes = await fetch(
      `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`,
      { headers: githubHeaders },
    )
    if (!ghRes.ok) {
      const text = await ghRes.text()
      return new Response(
        JSON.stringify({ error: `GitHub ${ghRes.status}`, detail: text }),
        { status: 502, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const release = (await ghRes.json()) as GhRelease
    const version = release.tag_name.replace(/^v/, '')
    const supabase = createClient(supabaseUrl, serviceKey)

    const { data: upserted, error: upsertError } = await supabase
      .from('releases')
      .upsert(
        {
          tag: release.tag_name,
          version,
          body: release.body,
          published_at: release.published_at,
          html_url: release.html_url,
          source: 'github',
          synced_at: new Date().toISOString(),
        },
        { onConflict: 'tag' },
      )
      .select('id')
      .single()

    if (upsertError || !upserted) {
      return new Response(JSON.stringify({ error: upsertError?.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    await supabase.from('release_assets').delete().eq('release_id', upserted.id)

    const rows = (release.assets ?? []).map((asset) => ({
      release_id: upserted.id,
      platform: detectPlatform(asset.name),
      name: asset.name,
      download_url: asset.browser_download_url,
      size_bytes: asset.size,
    }))

    if (rows.length > 0) {
      const { error: assetsError } = await supabase.from('release_assets').insert(rows)
      if (assetsError) {
        return new Response(JSON.stringify({ error: assetsError.message }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        })
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        tag: release.tag_name,
        version,
        assets: rows.length,
        invoked_via: req.method,
      }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : String(e) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
