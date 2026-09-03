import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import bi from 'big-integer'
import { Window } from 'happy-dom'

const vendorDir = join(dirname(fileURLToPath(import.meta.url)), 'vendor')
const wasmPath = join(vendorDir, 'lock.wasm')
const lockModuleUrl = pathToFileURL(join(vendorDir, 'lock-esm.mjs')).href
const wasmBytes = readFileSync(wasmPath)

// Live lock-esm still does require("big-integer") (CJS). Keep the shim here —
// not in lock-esm.mjs — so refreshing glue from embed.st cannot strip it again.
const nodeRequire = createRequire(import.meta.url)
if (typeof globalThis.require !== 'function') {
  globalThis.require = (name) =>
    name === 'big-integer' ? bi : nodeRequire(name)
}

function pageUrl(slot, embedOrigin) {
  return `${embedOrigin}/embed/${slot.path}`
}

function mountDom(slot, embedOrigin, onJwFile) {
  const window = new Window({ url: pageUrl(slot, embedOrigin) })
  const doc = window.document
  doc.body.innerHTML = '<div id="player"></div>'

  const jwCfg = { file: null }
  const takeFile = (cfg) => {
    const file = cfg?.file
    if (typeof file !== 'string' || !file) return
    jwCfg.file = file
    // admin often loads the playlist onto JW without a separate .m3u8 fetch
    if (file.includes('.m3u8') || file.includes('/stream/')) onJwFile?.(file)
  }

  const jwBase = {
    getContainer: () => doc.getElementById('player'),
    getState: () => 'idle',
    load: takeFile,
    setConfig: takeFile,
    getConfig: () => jwCfg,
    setup: () => {},
    on: () => {},
    play: () => {},
    getPlaylistItem: () => jwCfg,
    getPlaylist: () => (jwCfg.file ? [{ file: jwCfg.file }] : []),
  }
  window.__wasm_jw_player = new Proxy(jwBase, {
    get(target, prop, receiver) {
      if (Reflect.has(target, prop)) return Reflect.get(target, prop, receiver)
      if (prop === Symbol.toStringTag) return 'Object'
      return () => null
    },
  })
  window.jwplayer = () => window.__wasm_jw_player

  globalThis.window = window
  globalThis.document = doc
  globalThis.location = window.location
  globalThis.self = window
  globalThis.atob = (s) => Buffer.from(s, 'base64').toString('binary')
  globalThis.btoa = (s) => Buffer.from(s, 'binary').toString('base64')
  globalThis.TextDecoder = TextDecoder
  globalThis.TextEncoder = TextEncoder

  const NativeRequest = globalThis.Request
  const NativeResponse = globalThis.Response
  const NativeHeaders = globalThis.Headers
  const NativeUrl = globalThis.URL

  globalThis.URL = class extends NativeUrl {
    constructor(input, base) {
      if (input === '/fetch') input = `${embedOrigin}/fetch`
      super(input, base ?? `${embedOrigin}/`)
    }
  }
  globalThis.Request = class extends NativeRequest {
    constructor(input, init) {
      if (input === '/fetch') input = `${embedOrigin}/fetch`
      super(input, init)
    }
  }
  window.URL = globalThis.URL
  window.Request = globalThis.Request
  window.Response = NativeResponse
  window.Headers = NativeHeaders

  return NativeResponse
}

function mockFetch(NativeResponse, embedOrigin, goat, body, onM3u8) {
  return async (input) => {
    const href = typeof input === 'string' ? input : input?.url ?? String(input)
    if (href.includes('lock.wasm')) {
      return new NativeResponse(wasmBytes, {
        status: 200,
        headers: { 'Content-Type': 'application/wasm' },
      })
    }
    if (href.includes('/fetch')) {
      return new NativeResponse(body, {
        status: 200,
        headers: { goat, 'Content-Type': 'application/octet-stream' },
      })
    }
    if (href.includes('.m3u8')) {
      onM3u8(href)
      return new NativeResponse('#EXTM3U\n#EXT-X-VERSION:3\n', {
        status: 200,
        headers: { 'Content-Type': 'application/vnd.apple.mpegurl' },
      })
    }
    return new NativeResponse('', { status: 404 })
  }
}

function patchFetchImport(bg, NativeResponse, goat, body, onM3u8) {
  if (!bg || typeof bg !== 'object') return
  for (const key of Object.keys(bg)) {
    if (!key.includes('instanceof')) continue
    const orig = bg[key]
    bg[key] = (...args) => (orig(...args) ? 1 : 1)
  }
  const fetchKey = Object.keys(bg).find((k) => k.includes('fetch_'))
  if (!fetchKey) return
  bg[fetchKey] = (_win, req) => {
    const href = req?.url ?? ''
    if (href.includes('/fetch')) {
      return Promise.resolve(
        new NativeResponse(body, {
          status: 200,
          headers: { goat, 'Content-Type': 'application/octet-stream' },
        }),
      )
    }
    if (href.includes('.m3u8')) {
      onM3u8(href)
      return Promise.resolve(
        new NativeResponse('#EXTM3U\n#EXT-X-VERSION:3\n', {
          status: 200,
          headers: { 'Content-Type': 'application/vnd.apple.mpegurl' },
        }),
      )
    }
    return Promise.reject(new Error(`unexpected wasm fetch ${href}`))
  }
}

function patchImports(imports, NativeResponse, goat, body, onM3u8) {
  if (!imports || typeof imports !== 'object') return
  for (const modName of Object.keys(imports)) {
    patchFetchImport(imports[modName], NativeResponse, goat, body, onM3u8)
  }
}

async function crack(slot, goat, bodyHex, embedOrigin) {
  const source = String(slot?.source ?? '')
  const id = String(slot?.id ?? '')
  const stream = String(slot?.stream ?? '1')
  if (!source || !id) throw new Error('slot missing source/id')
  if (!goat || !bodyHex) throw new Error('missing goat/bodyHex')

  let m3u8 = null
  const capture = (url) => {
    if (typeof url === 'string' && url) m3u8 = url
  }
  const body = Buffer.from(bodyHex, 'hex')
  if (!body.length) throw new Error('empty /fetch body')
  const NativeResponse = mountDom(slot, embedOrigin, capture)
  const fetchFn = mockFetch(NativeResponse, embedOrigin, goat, body, capture)
  globalThis.fetch = fetchFn

  const origInstantiate = WebAssembly.instantiate.bind(WebAssembly)

  WebAssembly.instantiate = async (source, imports) => {
    patchImports(imports, NativeResponse, goat, body, capture)
    if (!(source instanceof ArrayBuffer) && !ArrayBuffer.isView(source)) {
      source = wasmBytes.buffer.slice(
        wasmBytes.byteOffset,
        wasmBytes.byteOffset + wasmBytes.byteLength,
      )
    }
    return origInstantiate(source, imports)
  }
  WebAssembly.instantiateStreaming = async (_resp, imports) =>
    WebAssembly.instantiate(wasmBytes, imports)

  try {
    const mod = await import(`${lockModuleUrl}?t=${Date.now()}`)
    const wasmBuf = wasmBytes.buffer.slice(
      wasmBytes.byteOffset,
      wasmBytes.byteOffset + wasmBytes.byteLength,
    )
    const api = await mod.default({
      module_or_path: wasmBuf,
      fetch: fetchFn,
    })
    await api.init_wasm?.()

    // Keep instantiate/fetch patches through set_stream_jw — delta/echo emit
    // the playlist from a wasm import fetch, not during init. Unpatching first
    // makes admin (jw load in init) look fine and every later source fail.
    try {
      const ret = api.set_stream_jw(source, id, stream)
      await Promise.race([
        Promise.resolve(ret),
        new Promise((resolve) => {
          const iv = setInterval(() => {
            if (m3u8) {
              clearInterval(iv)
              resolve(null)
            }
          }, 10)
          setTimeout(() => {
            clearInterval(iv)
            resolve(null)
          }, 8000)
        }),
      ])
    } catch (err) {
      if (!m3u8) {
        const msg =
          (err && (err.stack || err.message || err.name)) ||
          (err != null ? String(err) : 'set_stream_jw failed')
        throw new Error(String(msg).trim() || 'set_stream_jw failed')
      }
    }
    if (!m3u8) throw new Error('lock did not yield m3u8')
    return m3u8
  } finally {
    WebAssembly.instantiate = origInstantiate
    try {
      delete WebAssembly.instantiateStreaming
    } catch (_) {}
  }
}

const input = JSON.parse(readFileSync(0, 'utf8'))
crack(
  input.slot,
  input.goat,
  input.bodyHex,
  input.embedOrigin || 'https://embed.st',
)
  .then((url) => {
    process.stdout.write(JSON.stringify({ ok: true, url }))
  })
  .catch((err) => {
    process.stdout.write(
      JSON.stringify({
        ok: false,
        error: String(err?.stack || err?.message || err),
      }),
    )
    process.exit(1)
  })
