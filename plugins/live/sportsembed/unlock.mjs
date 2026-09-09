import { randomBytes } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { stdin } from 'node:process'

const wasmBytes = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), 'vendor', 'stream-lock.wasm'),
)

const embedPath = /\/embed\/(\d+)\/([^/]+)\/([^/]+)\/(\d+)\/?$/
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

let wasm = null

function view() {
  return new DataView(wasm.memory.buffer)
}

function mem() {
  return new Uint8Array(wasm.memory.buffer)
}

async function ensureWasm() {
  if (wasm) return
  const { instance } = await WebAssembly.instantiate(wasmBytes, {})
  wasm = instance.exports
}

function malloc(size) {
  return wasm.zonl3736033c71(size, 1)
}

function pack(op, chunks) {
  return Buffer.concat([
    Buffer.from([op]),
    ...chunks.flatMap((chunk) => {
      const body = Buffer.from(chunk)
      const len = Buffer.alloc(4)
      len.writeUInt32LE(body.length)
      return [len, body]
    }),
  ])
}

function dispatch(input) {
  const retptr = wasm.yojc788d654767(-8)
  const buf = Buffer.from(input)
  const ptr = malloc(buf.length)
  mem().set(buf, ptr)
  wasm.juut545fd2befc(retptr, ptr, buf.length)
  const outPtr = view().getUint32(retptr, true)
  const outLen = view().getUint32(retptr + 4, true)
  const out = Buffer.from(mem().slice(outPtr, outPtr + outLen))
  wasm.yojc788d654767(8)
  return out
}

async function signRequest(body, nonce) {
  await ensureWasm()
  const factor = dispatch(pack(0x17, [body, nonce]))
  if (factor.length !== 16) throw new Error('invalid client factor')
  const proof = dispatch(pack(0x29, [body, nonce, factor])).toString('utf8')
  if (!/^[0-9a-f]{64}$/.test(proof)) throw new Error('invalid client proof')
  return { factor, proof }
}

async function decryptStreamUrl(body, live, edge, nonce, factor, bodyTag) {
  await ensureWasm()
  const key = Buffer.from(String(live || '').split('_').pop(), 'hex')
  if (key.length !== 16) throw new Error('invalid x-live header')
  const edgeBuf = Buffer.from(edge, 'base64')
  const tagBuf = Buffer.from(bodyTag, 'base64')
  if (edgeBuf.length !== 16 || tagBuf.length !== 8) {
    throw new Error('invalid edge response headers')
  }
  const url = dispatch(
    pack(0x3b, [body, Buffer.concat([key, edgeBuf]), nonce, factor, tagBuf]),
  ).toString('utf8')
  if (!url.startsWith('http')) throw new Error('decrypt returned empty url')
  return url
}

function varint(n) {
  const bytes = []
  let v = n
  while (v > 0x7f) {
    bytes.push((v & 0x7f) | 0x80)
    v >>>= 7
  }
  bytes.push(v)
  return Buffer.from(bytes)
}

function fieldString(out, field, value) {
  const body = Buffer.from(String(value), 'utf8')
  out.push(Buffer.from([(field << 3) | 2]))
  out.push(varint(body.length))
  out.push(body)
}

function encodeRequestBody({ category, slug, stream, matchId }) {
  const out = []
  fieldString(out, 1, category)
  fieldString(out, 2, slug)
  fieldString(out, 3, stream)
  fieldString(out, 4, matchId)
  return Buffer.concat(out)
}

function parseEmbed(raw) {
  const url = new URL(String(raw || '').trim())
  const m = url.pathname.match(embedPath)
  if (!m) throw new Error('expected /embed/{id}/{slug}/{category}/{n}')
  const [, matchId, slug, category, stream] = m
  return {
    origin: url.origin,
    path: `${matchId}/${slug}/${category}/${stream}`,
    matchId,
    slug,
    category,
    stream,
  }
}

async function readStdin() {
  const chunks = []
  for await (const c of stdin) chunks.push(c)
  return Buffer.concat(chunks).toString('utf8')
}

async function main() {
  const raw = (await readStdin()).trim()
  if (!raw) {
    process.stdout.write(JSON.stringify({ ok: false, error: 'empty stdin' }))
    process.exit(1)
  }
  let input
  try {
    input = JSON.parse(raw)
  } catch (e) {
    process.stdout.write(
      JSON.stringify({ ok: false, error: `invalid json: ${e.message || e}` }),
    )
    process.exit(1)
  }

  try {
    const embed =
      input.embedUrl || input.url
        ? parseEmbed(input.embedUrl || input.url)
        : {
            origin: String(input.origin || 'https://sportsembed.su').replace(
              /\/+$/,
              '',
            ),
            path: `${input.matchId}/${input.slug}/${input.category}/${input.stream}`,
            matchId: String(input.matchId || ''),
            slug: String(input.slug || ''),
            category: String(input.category || ''),
            stream: String(input.stream || '1'),
          }

    const body = encodeRequestBody(embed)
    const nonce = randomBytes(32)
    const { factor, proof } = await signRequest(body, nonce)
    const referer = `${embed.origin}/embed/${embed.path}`
    const res = await fetch(`${embed.origin}/api/get`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/octet-stream',
        Origin: embed.origin,
        Referer: referer,
        'User-Agent': UA,
        'x-client-nonce': nonce.toString('base64'),
        'x-client-factor': factor.toString('base64'),
        'x-client-proof': proof,
      },
      body,
    })
    if (!res.ok) {
      const detail = (await res.text()).trim() || res.statusText
      throw new Error(`embed /api/get ${res.status}: ${detail}`)
    }
    const encBody = Buffer.from(await res.arrayBuffer())
    const streamUrl = await decryptStreamUrl(
      encBody,
      res.headers.get('x-live'),
      res.headers.get('x-edge'),
      nonce,
      factor,
      res.headers.get('x-body-tag'),
    )
    process.stdout.write(
      JSON.stringify({
        ok: true,
        url: streamUrl,
        origin: embed.origin,
        path: embed.path,
      }),
    )
  } catch (e) {
    process.stdout.write(
      JSON.stringify({ ok: false, error: String(e.message || e) }),
    )
    process.exit(1)
  }
}

main()
