/** Schema 1 — mirrors Dart `ProviderRuntimeSnapshot` (RFC-039). */

export const SUPPORTED_SCHEMA = 1

export type UrlTemplates = { movie: string; tv: string }

export type AnimeEmbedHost = {
  host: string
  pathCatalog: string
  pathAnilist: string
  scrapeReferer: string
}

export type CdnRefererRule = {
  hostContains: string[]
  referer: string
  origin: string
  acceptRefererContains: string[]
}

export type AnimeProbeMode =
  | 'masterOnly'
  | 'segmentPoisonSample'
  | 'headOrRange'
  | 'skip'

export type AnimePlaybackProfile = {
  probe: AnimeProbeMode
  pngStripHostContains: string[]
}

export type ProviderRuntimeConfig = {
  schema: number
  templates: Record<string, UrlTemplates>
  apis: Record<string, string>
  webstreamr: Record<string, string>
  anime: {
    megaplay: AnimeEmbedHost
    vidwish: AnimeEmbedHost
    miruroOrigins: string[]
    kisskhMirrors: string[]
    playbackProfiles: Record<string, AnimePlaybackProfile>
  }
  cdnRefererRules: CdnRefererRule[]
}

const emptyHost = (): AnimeEmbedHost => ({
  host: '',
  pathCatalog: '',
  pathAnilist: '',
  scrapeReferer: '',
})

export function emptyConfig(): ProviderRuntimeConfig {
  return {
    schema: SUPPORTED_SCHEMA,
    templates: {},
    apis: {},
    webstreamr: {},
    anime: {
      megaplay: emptyHost(),
      vidwish: emptyHost(),
      miruroOrigins: [],
      kisskhMirrors: [],
      playbackProfiles: {},
    },
    cdnRefererRules: [],
  }
}

function asObject(v: unknown): Record<string, unknown> | null {
  if (!v || typeof v !== 'object' || Array.isArray(v)) return null
  return v as Record<string, unknown>
}

function str(v: unknown): string {
  return typeof v === 'string' ? v.trim() : v == null ? '' : String(v).trim()
}

function strList(v: unknown): string[] {
  if (!Array.isArray(v)) return []
  return v.map((e) => str(e)).filter(Boolean)
}

function parseHost(raw: unknown): AnimeEmbedHost {
  const o = asObject(raw)
  if (!o) return emptyHost()
  return {
    host: str(o.host),
    pathCatalog: str(o.pathCatalog),
    pathAnilist: str(o.pathAnilist),
    scrapeReferer: str(o.scrapeReferer),
  }
}

export function parseConfig(
  raw: unknown,
): { ok: true; value: ProviderRuntimeConfig } | { ok: false; error: string } {
  const root = asObject(raw)
  if (!root) return { ok: false, error: 'Config must be a JSON object' }

  const schema = root.schema
  if (schema !== SUPPORTED_SCHEMA) {
    return {
      ok: false,
      error: `schema must be ${SUPPORTED_SCHEMA} (got ${String(schema)})`,
    }
  }

  const templates: Record<string, UrlTemplates> = {}
  const rawTpl = asObject(root.templates)
  if (rawTpl) {
    for (const [id, val] of Object.entries(rawTpl)) {
      const t = asObject(val)
      if (!t) continue
      const movie = str(t.movie)
      const tv = str(t.tv)
      if (!movie && !tv) continue
      templates[id] = { movie, tv }
    }
  }

  const apis: Record<string, string> = {}
  const rawApis = asObject(root.apis)
  if (rawApis) {
    for (const [k, v] of Object.entries(rawApis)) {
      const s = str(v)
      if (s) apis[k] = s
    }
  }

  const webstreamr: Record<string, string> = {}
  const rawWs = asObject(root.webstreamr)
  if (rawWs) {
    for (const [k, v] of Object.entries(rawWs)) {
      const s = str(v)
      if (s) webstreamr[k] = s
    }
  }

  const animeObj = asObject(root.anime) ?? {}
  const cdnRefererRules: CdnRefererRule[] = []
  const rawRules = root.cdnRefererRules
  if (Array.isArray(rawRules)) {
    for (const r of rawRules) {
      const o = asObject(r)
      if (!o) continue
      const hostContains = strList(o.hostContains)
      const referer = str(o.referer)
      if (!hostContains.length || !referer) continue
      cdnRefererRules.push({
        hostContains,
        referer,
        origin: str(o.origin),
        acceptRefererContains: strList(o.acceptRefererContains),
      })
    }
  }

  const playbackProfiles: Record<string, AnimePlaybackProfile> = {}
  const rawProfiles = asObject(animeObj.playbackProfiles)
  if (rawProfiles) {
    for (const [id, val] of Object.entries(rawProfiles)) {
      const key = id.trim()
      const o = asObject(val)
      if (!key || !o) continue
      const probeRaw = str(o.probe)
      const probe: AnimeProbeMode =
        probeRaw === 'segmentPoisonSample' ||
        probeRaw === 'segment_poison_sample'
          ? 'segmentPoisonSample'
          : probeRaw === 'headOrRange' || probeRaw === 'head_or_range'
            ? 'headOrRange'
            : probeRaw === 'skip'
              ? 'skip'
              : 'masterOnly'
      playbackProfiles[key] = {
        probe,
        pngStripHostContains: strList(o.pngStripHostContains),
      }
    }
  }

  return {
    ok: true,
    value: {
      schema: SUPPORTED_SCHEMA,
      templates,
      apis,
      webstreamr,
      anime: {
        megaplay: parseHost(animeObj.megaplay),
        vidwish: parseHost(animeObj.vidwish),
        miruroOrigins: strList(animeObj.miruroOrigins),
        kisskhMirrors: strList(animeObj.kisskhMirrors),
        playbackProfiles,
      },
      cdnRefererRules,
    },
  }
}

export function parseConfigJson(
  raw: string,
): { ok: true; value: ProviderRuntimeConfig } | { ok: false; error: string } {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : 'Invalid JSON' }
  }
  return parseConfig(parsed)
}

/** Stable JSON for dirty-compare / save payload. */
export function serializeConfig(cfg: ProviderRuntimeConfig): unknown {
  return {
    schema: SUPPORTED_SCHEMA,
    templates: Object.fromEntries(
      Object.entries(cfg.templates)
        .filter(([id]) => id.trim())
        .map(([id, t]) => [
          id.trim(),
          { movie: t.movie.trim(), tv: t.tv.trim() },
        ])
        .filter(([, t]) => {
          const u = t as UrlTemplates
          return u.movie || u.tv
        }),
    ),
    apis: Object.fromEntries(
      Object.entries(cfg.apis)
        .map(([k, v]) => [k.trim(), v.trim()] as const)
        .filter(([k, v]) => k && v),
    ),
    webstreamr: Object.fromEntries(
      Object.entries(cfg.webstreamr)
        .map(([k, v]) => [k.trim(), v.trim()] as const)
        .filter(([k, v]) => k && v),
    ),
    anime: {
      megaplay: {
        host: cfg.anime.megaplay.host.trim(),
        pathCatalog: cfg.anime.megaplay.pathCatalog.trim(),
        pathAnilist: cfg.anime.megaplay.pathAnilist.trim(),
        scrapeReferer: cfg.anime.megaplay.scrapeReferer.trim(),
      },
      vidwish: {
        host: cfg.anime.vidwish.host.trim(),
        pathCatalog: cfg.anime.vidwish.pathCatalog.trim(),
        pathAnilist: cfg.anime.vidwish.pathAnilist.trim(),
        scrapeReferer: cfg.anime.vidwish.scrapeReferer.trim(),
      },
      miruroOrigins: cfg.anime.miruroOrigins.map((s) => s.trim()).filter(Boolean),
      kisskhMirrors: cfg.anime.kisskhMirrors.map((s) => s.trim()).filter(Boolean),
      playbackProfiles: Object.fromEntries(
        Object.entries(cfg.anime.playbackProfiles)
          .map(([id, p]) => {
            const key = id.trim()
            if (!key) return null
            return [
              key,
              {
                probe: p.probe,
                pngStripHostContains: p.pngStripHostContains
                  .map((s) => s.trim())
                  .filter(Boolean),
              },
            ] as const
          })
          .filter((e): e is readonly [string, AnimePlaybackProfile] => e != null),
      ),
    },
    cdnRefererRules: cfg.cdnRefererRules
      .map((r) => ({
        hostContains: r.hostContains.map((s) => s.trim()).filter(Boolean),
        referer: r.referer.trim(),
        origin: r.origin.trim(),
        ...(r.acceptRefererContains.some((s) => s.trim())
          ? {
              acceptRefererContains: r.acceptRefererContains
                .map((s) => s.trim())
                .filter(Boolean),
            }
          : {}),
      }))
      .filter((r) => r.hostContains.length > 0 && r.referer),
  }
}

export function configToPrettyJson(cfg: ProviderRuntimeConfig): string {
  return JSON.stringify(serializeConfig(cfg), null, 2)
}

export function canonicalJson(cfg: ProviderRuntimeConfig): string {
  return JSON.stringify(serializeConfig(cfg))
}

export type KvRow = { key: string; value: string }
export type TemplateRow = { id: string; movie: string; tv: string }

export function mapToKv(m: Record<string, string>): KvRow[] {
  return Object.entries(m).map(([key, value]) => ({ key, value }))
}

export function kvToMap(rows: KvRow[]): Record<string, string> {
  const out: Record<string, string> = {}
  for (const r of rows) {
    const k = r.key.trim()
    const v = r.value.trim()
    if (!k || !v) continue
    out[k] = v
  }
  return out
}

export function templatesToRows(
  m: Record<string, UrlTemplates>,
): TemplateRow[] {
  return Object.entries(m).map(([id, t]) => ({
    id,
    movie: t.movie,
    tv: t.tv,
  }))
}

export function rowsToTemplates(rows: TemplateRow[]): Record<string, UrlTemplates> {
  const out: Record<string, UrlTemplates> = {}
  for (const r of rows) {
    const id = r.id.trim()
    if (!id) continue
    const movie = r.movie.trim()
    const tv = r.tv.trim()
    if (!movie && !tv) continue
    out[id] = { movie, tv }
  }
  return out
}

export function linesToList(text: string): string[] {
  return text
    .split('\n')
    .map((s) => s.trim())
    .filter(Boolean)
}

export function listToLines(list: string[]): string {
  return list.join('\n')
}

export function csvToList(text: string): string[] {
  return text
    .split(/[,\n]/)
    .map((s) => s.trim())
    .filter(Boolean)
}

export function listToCsv(list: string[]): string {
  return list.join(', ')
}
