import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { Window } from 'happy-dom'

const vendorDir = join(dirname(fileURLToPath(import.meta.url)), 'vendor')
const wasmPath = join(vendorDir, 'gasm.wasm')
const gasmModuleUrl = pathToFileURL(join(vendorDir, 'gasm-esm.mjs')).href
const wasmBytes = readFileSync(wasmPath)

function pageUrl(slot, embedOrigin) {
  const path = slot.path || `${slot.league}/${slot.date}/${slot.slug}`
  const gid = slot.gid ? `?gid=${encodeURIComponent(slot.gid)}` : ''
  return `${embedOrigin}/embed/${path}${gid}`
}

function mountDom(slot, embedOrigin) {
  const window = new Window({ url: pageUrl(slot, embedOrigin) })
  const doc = window.document
  doc.documentElement.innerHTML =
    '<head></head><body><div id="player"></div></body>'

  const jwCfg = { file: null }
  const jwBase = {
    getContainer: () => doc.getElementById('player'),
    getState: () => 'idle',
    load: (cfg) => {
      if (cfg?.file) jwCfg.file = cfg.file
    },
    setConfig: (cfg) => {
      if (cfg?.file) jwCfg.file = cfg.file
    },
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
  const WasmResponse = window.Response ?? NativeResponse

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
  window.Response = WasmResponse
  window.Headers = NativeHeaders

  return { NativeResponse, WasmResponse }
}

function mockFetch(WasmResponse, embedOrigin, island, body, onM3u8, islandHeaders) {
  return async (input) => {
    const href = typeof input === 'string' ? input : input?.url ?? String(input)
    if (href.includes('gasm.wasm')) {
      return new WasmResponse(wasmBytes, {
        status: 200,
        headers: { 'Content-Type': 'application/wasm' },
      })
    }
    if (href.includes('/fetch')) {
      return new WasmResponse(body, {
        status: 200,
        headers: islandHeaders,
      })
    }
    if (href.includes('.m3u8')) {
      onM3u8(href)
      return new WasmResponse('#EXTM3U\n#EXT-X-VERSION:3\n', {
        status: 200,
        headers: { 'Content-Type': 'application/vnd.apple.mpegurl' },
      })
    }
    return new WasmResponse('', { status: 404 })
  }
}

function patchImports(imports, WasmResponse, island, body, onM3u8, islandHeaders) {
  const bg = imports?.['./wasmgasm_bg.js']
  if (!bg) return

  for (const key of Object.keys(bg)) {
    if (!key.includes('instanceof')) continue
    const orig = bg[key]
    bg[key] = (...args) => (orig(...args) ? 1 : 1)
  }

  const fetchKey = Object.keys(bg).find((k) => k.includes('fetch_e6e8e0'))
  if (!fetchKey) return

  bg[fetchKey] = (_win, req) => {
    const href = req?.url ?? ''
    if (href.includes('/fetch')) {
      return Promise.resolve(
        new WasmResponse(body, {
          status: 200,
          headers: islandHeaders,
        }),
      )
    }
    if (href.includes('.m3u8')) {
      onM3u8(href)
      return Promise.resolve(
        new WasmResponse('#EXTM3U\n#EXT-X-VERSION:3\n', {
          status: 200,
          headers: { 'Content-Type': 'application/vnd.apple.mpegurl' },
        }),
      )
    }
    return Promise.reject(new Error(`unexpected wasm fetch ${href}`))
  }
}

async function crack(slot, island, bodyHex, embedOrigin) {
  let m3u8 = null
  const body = Buffer.from(bodyHex, 'hex')
  const { WasmResponse } = mountDom(slot, embedOrigin)
  const islandHeaders = new globalThis.Headers({
    island,
    'Content-Type': 'application/octet-stream',
  })
  const fetchFn = mockFetch(WasmResponse, embedOrigin, island, body, (url) => {
    m3u8 = url
  }, islandHeaders)
  globalThis.fetch = fetchFn

  const origInstantiate = WebAssembly.instantiate.bind(WebAssembly)

  WebAssembly.instantiate = async (source, imports) => {
    patchImports(imports, WasmResponse, island, body, (url) => {
      m3u8 = url
    }, islandHeaders)
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

  const mod = await import(gasmModuleUrl)
  const api = await mod.default({
    module_or_path: `${embedOrigin}/js/wasm/gasm.wasm`,
    fetch: fetchFn,
  })
  await api.init_wasm?.()

  WebAssembly.instantiate = origInstantiate
  delete WebAssembly.instantiateStreaming

  try {
    await api.set_stream(slot.league, slot.date, slot.slug)
  } catch (err) {
    if (!m3u8) {
      try {
        await api.set_stream_jw(slot.league, slot.date)
      } catch (inner) {
        if (!m3u8) throw err
      }
    }
  }
  try {
    await api.on_unmute?.()
  } catch (_) {}
  if (!m3u8 && globalThis.__decryptLogs?.length) {
    const hit = globalThis.__decryptLogs.find((e) =>
      String(e ?? '').includes('.m3u8'),
    )
    if (hit) m3u8 = String(hit)
  }
  if (!m3u8) {
    const logs = globalThis.__decryptLogs
    const hint =
      Array.isArray(logs) && logs.length
        ? ` decryptLogs=${JSON.stringify(logs).slice(0, 240)}`
        : ''
    throw new Error(`gasm did not yield m3u8${hint}`)
  }
  return m3u8
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
        error: String(err?.stack || err?.message || err),
      }),
    )
    process.exit(1)
  })
