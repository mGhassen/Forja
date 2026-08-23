import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { Window } from 'happy-dom'

const vendorDir = join(dirname(fileURLToPath(import.meta.url)), 'vendor')
const wasmBytes = readFileSync(join(vendorDir, 'gasm.wasm'))
const gasmModuleUrl = pathToFileURL(join(vendorDir, 'gasm-esm.mjs')).href

function pagePath(slot) {
  return slot.path || `${slot.league}/${slot.date}/${slot.slug}`
}

function readVarint(buf, offset) {
  let value = 0
  let shift = 0
  let i = offset
  while (i < buf.length) {
    const byte = buf[i++]
    value |= (byte & 0x7f) << shift
    if (!(byte & 0x80)) return { value, next: i }
    shift += 7
  }
  return { value, next: i }
}

/** Protobuf field 2 string from /fetch body — slug used to pick the right m3u8. */
function slugFromFetchBody(body) {
  const buf = Buffer.from(body)
  let i = 0
  while (i < buf.length) {
    const tag = buf[i++]
    const field = tag >> 3
    const wire = tag & 7
    if (wire !== 2) break
    const { value: len, next } = readVarint(buf, i)
    i = next
    if (i + len > buf.length) break
    const value = buf.subarray(i, i + len).toString('utf8')
    i += len
    if (field === 2 && value && !value.startsWith('{')) return value
  }
  return null
}

function extractUrl(memory, slug) {
  const text = Buffer.from(memory.buffer).toString('latin1')
  const re = /https:\/\/[a-z0-9.-]+\/secure\/[^\x00-\x1f\s"']+?index\.m3u8/gi
  const matches = []
  let match
  while ((match = re.exec(text)) !== null) matches.push(match[0])
  if (!matches.length) return null
  if (slug) {
    const hit = matches.find((url) => url.includes(`/${slug}/`))
    if (hit) return hit
  }
  return matches[matches.length - 1]
}

/**
 * Port of sharoon7171/ppv-hls-stream-resolver decrypt:
 * set_stream_jw(island, bodyBytes) then scrape WASM linear memory for CDN m3u8.
 */
async function crack(slot, island, bodyHex, embedOrigin) {
  const body = Buffer.from(bodyHex, 'hex')
  const path = pagePath(slot)
  const slug = slugFromFetchBody(body)
  const pageUrl = `${embedOrigin}/embed/${path}${
    slot.gid ? `?gid=${encodeURIComponent(slot.gid)}` : ''
  }`

  const saved = {
    fetch: globalThis.fetch,
    Request: globalThis.Request,
    Response: globalThis.Response,
    window: globalThis.window,
    document: globalThis.document,
    location: globalThis.location,
    self: globalThis.self,
    jwplayer: globalThis.jwplayer,
  }

  const jwEngine = { destroy() {} }
  const jwPlayer = {
    remove() {
      return jwEngine
    },
    setup() {},
    on() {},
    load() {},
    play() {},
    getPlaylistItem: () => ({}),
    getState: () => 'idle',
  }
  Object.defineProperty(jwPlayer, '__wasm_jw_player', {
    value: jwPlayer,
    enumerable: false,
  })
  Object.defineProperty(jwEngine, '__wasm_jw_engine', {
    value: jwEngine,
    enumerable: false,
  })

  const window = new Window({ url: pageUrl })
  window.eval = () => undefined
  window.jwplayer = () => jwPlayer
  window.__wasm_jw_player = jwPlayer
  window.__wasm_jw_engine = jwEngine
  window.__wasm_player = { core: { mediaControl: { volume: 0 } } }
  window.__wasm_p2p_config = {}
  window.P2PEngineHls = class {}

  const resolveEmbedUrl = (url) =>
    typeof url === 'string' && url.startsWith('/')
      ? `${embedOrigin}${url}`
      : url

  const embedFetch = async (input) => {
    const href =
      typeof input === 'string'
        ? input
        : input?.url != null
          ? String(input.url)
          : String(input)
    if (href.includes('gasm.wasm') || href.endsWith('.wasm')) {
      return new window.Response(wasmBytes, {
        status: 200,
        headers: { 'Content-Type': 'application/wasm' },
      })
    }
    // WASM always re-hits /fetch; feed the already-captured island+body.
    return new window.Response(body, {
      status: 200,
      headers: {
        'content-type': 'application/octet-stream',
        island,
      },
    })
  }

  const BaseRequest = saved.Request
  globalThis.Request = class extends BaseRequest {
    constructor(input, init) {
      if (typeof input === 'string') {
        super(resolveEmbedUrl(input), init)
        return
      }
      super(input, init)
    }
  }
  globalThis.fetch = embedFetch
  window.fetch = embedFetch
  window.Request = globalThis.Request
  globalThis.Response = window.Response

  Object.assign(globalThis, {
    window,
    document: window.document,
    location: window.location,
    self: window,
    jwplayer: window.jwplayer,
  })

  try {
    const mod = await import(gasmModuleUrl)
    const wasm = await mod.default({
      module_or_path: wasmBytes,
      fetch: embedFetch,
    })

    // Flags used by the public gasm build (same offsets as ppv-hls-stream-resolver).
    try {
      const u8 = new Uint8Array(wasm.memory.buffer)
      const dv = new DataView(wasm.memory.buffer)
      if (u8.length > 1070513) {
        u8[1070512] = 3
        u8[1070513] = 1
        u8[1070488] = 1
        u8[1070508] = 1
        dv.setInt32(1070476, -2147483648, true)
        dv.setInt32(1070472, 0, true)
        dv.setInt32(1070496, -2147483648, true)
        dv.setInt32(1070492, 0, true)
      }
    } catch (_) {}

    await wasm.init_wasm?.()

    const call = wasm.set_stream_jw(island, new Uint8Array(body))
    await Promise.race([
      Promise.resolve(call),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('set_stream_jw timeout')), 15000),
      ),
    ]).catch(() => {})

    try {
      await wasm.on_unmute?.()
    } catch (_) {}

    const streamUrl = extractUrl(wasm.memory, slug)
    if (!streamUrl) {
      throw new Error(
        `gasm did not yield m3u8 (slug=${slug || '-'} island=${island.length}B body=${body.length}B)`,
      )
    }
    return streamUrl
  } finally {
    globalThis.fetch = saved.fetch
    globalThis.Request = saved.Request
    globalThis.Response = saved.Response
    globalThis.window = saved.window
    globalThis.document = saved.document
    globalThis.location = saved.location
    globalThis.self = saved.self
    globalThis.jwplayer = saved.jwplayer
  }
}

const input = JSON.parse(readFileSync(0, 'utf8'))
crack(
  input.slot,
  input.island,
  input.bodyHex,
  input.embedOrigin || 'https://embedindia.st',
)
  .then((url) => {
    process.stdout.write(JSON.stringify({ ok: true, url }))
  })
  .catch((err) => {
    process.stdout.write(
      JSON.stringify({
        ok: false,
        error: String(err?.stack || err?.message || err || 'unknown'),
      }),
    )
    process.exit(1)
  })
