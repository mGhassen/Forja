/**
 * POST /fetch is done in Dart; this runs set_stream / set_stream_jw then
 * scrapes WASM linear memory (and JW setup) for the CDN m3u8.
 */
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { Window } from 'happy-dom'

const vendorDir = join(dirname(fileURLToPath(import.meta.url)), 'vendor')
const nodeRequire = createRequire(import.meta.url)

/** embedindia.st ships one wasm + ESM glue — try flags on/off. */
const PAIRS = [
  {
    name: 'live',
    js: join(vendorDir, 'gasm-esm.mjs'),
    wasm: join(vendorDir, 'gasm-live.wasm'),
    applyFlags: true,
  },
  {
    name: 'live-noflags',
    js: join(vendorDir, 'gasm-esm.mjs'),
    wasm: join(vendorDir, 'gasm-live.wasm'),
    applyFlags: false,
  },
]

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
  const re = /https:\/\/[a-z0-9.-]+\/secure\/[^\x00-\x1f\s"']+?\.m3u8/gi
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

function lookLikeStream(url) {
  if (typeof url !== 'string' || !url) return false
  return /\.m3u8/i.test(url) || url.includes('/secure/') || url.includes('/stream/')
}

/** Same linear-memory flags as decrypt.js (tuned for ref gasm.wasm). */
function applyRefFlags(memory) {
  const u8 = new Uint8Array(memory.buffer)
  const dv = new DataView(memory.buffer)
  if (u8.length <= 1070513) return
  u8[1070512] = 3
  u8[1070513] = 1
  u8[1070488] = 1
  u8[1070508] = 1
  dv.setInt32(1070476, -2147483648, true)
  dv.setInt32(1070472, 0, true)
  dv.setInt32(1070496, -2147483648, true)
  dv.setInt32(1070492, 0, true)
}

async function decryptWithPair(pair, island, body, embedOrigin, path, slug) {
  const wasmBytes = readFileSync(pair.wasm)
  const saved = {
    fetch: globalThis.fetch,
    Request: globalThis.Request,
    Response: globalThis.Response,
    URL: globalThis.URL,
    require: globalThis.require,
    window: globalThis.window,
    Window: globalThis.Window,
    document: globalThis.document,
    location: globalThis.location,
    self: globalThis.self,
    jwplayer: globalThis.jwplayer,
  }

  let m3u8 = null
  const capture = (url) => {
    if (lookLikeStream(url)) m3u8 = url
  }

  const jwCfg = { file: null }
  const takeFile = (cfg) => {
    const file =
      typeof cfg === 'string'
        ? cfg
        : cfg?.file || cfg?.sources?.[0]?.file || (Array.isArray(cfg) ? cfg[0]?.file : null)
    if (typeof file !== 'string' || !file) return
    jwCfg.file = file
    capture(file)
  }

  const jwEngine = { destroy() { } }
  const jwBase = {
    id: 'player',
    uniqueId: 'player',
    plugins: {},
    version: '8.38.10',
    Events: {},
    utils: {},
    _: {},
    remove() {
      return jwEngine
    },
    setup: takeFile,
    load: takeFile,
    setConfig: takeFile,
    getConfig: () => jwCfg,
    on() { },
    play() { },
    getPlaylistItem: () => jwCfg,
    getPlaylist: () => (jwCfg.file ? [{ file: jwCfg.file }] : []),
    getState: () => 'idle',
    getContainer: () => null,
    getAudioTracks: () => [],
    getBuffer: () => 0,
    getCaptions: () => null,
    getCaptionsList: () => [],
    getControls: () => true,
    getCues: () => [],
    qoe: () => ({}),
    addCues() { },
  }
  const jwPlayer = new Proxy(jwBase, {
    get(target, prop, receiver) {
      if (Reflect.has(target, prop)) return Reflect.get(target, prop, receiver)
      if (prop === Symbol.toStringTag) return 'Object'
      return () => null
    },
  })

  const window = new Window({
    url: `${embedOrigin}/embed/${path}`,
    settings: {
      disableJavaScriptFileLoading: true,
      disableJavaScriptEvaluation: false,
    },
  })

  window.eval = () => undefined
  window.jwplayer = () => jwPlayer
  window.__wasm_jw_player = jwPlayer
  window.__wasm_jw_engine = jwEngine
  // Live embedindia reads __wasm_jw_p2p_config (not the older __wasm_p2p_config alone).
  window.__wasm_jw_p2p_config = {
    live: true,
    token: '',
    channelId: '',
    announce: '',
    showSlogan: false,
    sharePlaylist: false,
    startFromSegmentOffset: 0,
    trickleICE: false,
  }
  window.__wasm_p2p_config = window.__wasm_jw_p2p_config
  window.__wasm_player = { core: { mediaControl: { volume: 0 } } }
  window.P2PEngineHls = class {
    static isSupported() {
      return false
    }
    static isMSESupported() {
      return false
    }
  }
  window.P2pEngineHls = window.P2PEngineHls
  try {
    window.document.body.innerHTML = '<div id="player"></div>'
  } catch (_) { }

  const resolveEmbedUrl = (url) => {
    if (typeof url !== 'string') return url
    if (url.startsWith('/')) return `${embedOrigin}${url}`
    return url
  }

  const NativeRequest = saved.Request
  const NativeResponse = saved.Response
  const NativeURL = saved.URL

  globalThis.URL = class extends NativeURL {
    constructor(input, base) {
      if (typeof input === 'string' && input.startsWith('/')) {
        input = `${embedOrigin}${input}`
      }
      super(input, base ?? `${embedOrigin}/`)
    }
  }

  globalThis.Request = class extends NativeRequest {
    constructor(input, init) {
      if (typeof input === 'string') {
        super(resolveEmbedUrl(input), init)
        return
      }
      super(input, init)
    }
  }

  const embedFetch = async (input) => {
    let href =
      typeof input === 'string'
        ? input
        : input?.url || (input instanceof URL ? String(input) : String(input))
    href = resolveEmbedUrl(href)
    if (lookLikeStream(href)) {
      capture(href)
      return new NativeResponse('#EXTM3U\n#EXT-X-VERSION:3\n', {
        status: 200,
        headers: { 'content-type': 'application/vnd.apple.mpegurl' },
      })
    }
    // WASM re-hits /fetch; feed captured island+body (never network).
    return new NativeResponse(body, {
      status: 200,
      headers: { 'content-type': 'application/octet-stream', island },
    })
  }

  globalThis.fetch = embedFetch
  window.fetch = embedFetch
  window.Request = globalThis.Request
  globalThis.Response = NativeResponse
  globalThis.require = (name) => {
    try {
      return nodeRequire(name)
    } catch {
      return {}
    }
  }

  Object.assign(globalThis, {
    window,
    Window,
    document: window.document,
    location: window.location,
    self: window,
    jwplayer: window.jwplayer,
  })

  try {
    const mod = await import(`${pathToFileURL(pair.js).href}?t=${Date.now()}`)
    const wasm = await mod.default({ module_or_path: wasmBytes, fetch: embedFetch })

    if (typeof wasm.init_wasm === 'function') {
      try {
        await Promise.resolve(wasm.init_wasm())
      } catch (_) { }
    }

    if (pair.applyFlags) {
      try {
        applyRefFlags(wasm.memory)
      } catch (_) { }
    }

    // Current embedindia gasm writes the playlist via set_stream (set_stream_jw
    // rejects empty and leaves memory blank). Keep jw as a fallback.
    const setters = []
    if (typeof wasm.set_stream === 'function') setters.push(['set_stream', wasm.set_stream])
    if (typeof wasm.set_stream_jw === 'function') {
      setters.push(['set_stream_jw', wasm.set_stream_jw])
    }
    if (!setters.length) {
      throw new Error(`${pair.name}: no set_stream / set_stream_jw`)
    }

    for (const [name, fn] of setters) {
      try {
        const result = fn.call(wasm, island, new Uint8Array(body))
        await Promise.race([
          Promise.resolve(result),
          new Promise((resolve) => {
            const iv = setInterval(() => {
              if (m3u8 || extractUrl(wasm.memory, slug)) {
                clearInterval(iv)
                resolve(null)
              }
            }, 10)
            setTimeout(() => {
              clearInterval(iv)
              resolve(null)
            }, 8000)
          }),
        ]).catch(() => { })
      } catch (_) { }

      const streamUrl = m3u8 || jwCfg.file || extractUrl(wasm.memory, slug)
      if (streamUrl) return streamUrl
    }

    throw new Error(
      `${pair.name}: no m3u8 (slug=${slug || '-'} mem=${wasm.memory.buffer.byteLength})`,
    )
  } finally {
    globalThis.fetch = saved.fetch
    globalThis.Request = saved.Request
    globalThis.Response = saved.Response
    globalThis.URL = saved.URL
    globalThis.require = saved.require
    globalThis.window = saved.window
    globalThis.Window = saved.Window
    globalThis.document = saved.document
    globalThis.location = saved.location
    globalThis.self = saved.self
    globalThis.jwplayer = saved.jwplayer
  }
}

async function crack(slot, island, bodyHex, embedOrigin) {
  if (!island || !bodyHex) throw new Error('missing island or bodyHex')
  const body = Buffer.from(bodyHex, 'hex')
  const path = pagePath(slot)
  const slug = slugFromFetchBody(body)
  const errors = []

  for (const pair of PAIRS) {
    try {
      readFileSync(pair.js)
      readFileSync(pair.wasm)
    } catch (e) {
      errors.push(`${pair.name}: missing assets (${e.message})`)
      continue
    }
    try {
      return await decryptWithPair(pair, island, body, embedOrigin, path, slug)
    } catch (e) {
      errors.push(String(e?.message || e))
    }
  }

  throw new Error(`gasm did not yield m3u8 — ${errors.join(' | ')}`)
}

const input = JSON.parse(readFileSync(0, 'utf8'))
crack(
  input.slot || {},
  input.island || '',
  input.bodyHex || '',
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
