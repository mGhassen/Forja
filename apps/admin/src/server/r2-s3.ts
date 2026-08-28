/** Minimal R2 S3 API (SigV4) — GET/PUT JSON objects. */

const REGION = 'auto'
const SERVICE = 's3'
const DEFAULT_ACCOUNT = 'e8d83ffa2ffe56b9b95da0f8ba54e956'

export function r2Config() {
  const accountId =
    process.env.R2_ACCOUNT_ID?.trim() ||
    process.env.CLOUDFLARE_ACCOUNT_ID?.trim() ||
    DEFAULT_ACCOUNT
  const accessKey = process.env.R2_ACCESS_KEY_ID?.trim() || ''
  const secretKey = process.env.R2_SECRET_ACCESS_KEY?.trim() || ''
  const bucket = process.env.R2_BUCKET?.trim() || 'forja-releases'
  const endpoint =
    process.env.R2_ENDPOINT?.trim() ||
    `https://${accountId}.r2.cloudflarestorage.com`
  const cdnBase = (
    process.env.RELEASE_CDN_URL?.trim() ||
    process.env.VITE_RELEASE_CDN_URL?.trim() ||
    ''
  ).replace(/\/$/, '')
  return { accountId, accessKey, secretKey, bucket, endpoint, cdnBase }
}

export function hasR2S3Creds(): boolean {
  const c = r2Config()
  return Boolean(c.accessKey && c.secretKey)
}

function requireS3Creds() {
  const c = r2Config()
  if (!c.accessKey || !c.secretKey) {
    throw new Error('R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY required')
  }
  return c
}

function bufferSource(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer
}

async function hmac(key: BufferSource, msg: string): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  return crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(msg))
}

async function sha256Hex(data: BufferSource | string | Uint8Array): Promise<string> {
  const bytes =
    typeof data === 'string'
      ? new TextEncoder().encode(data)
      : data instanceof Uint8Array
        ? bufferSource(data)
        : data
  const dig = await crypto.subtle.digest('SHA-256', bytes)
  return [...new Uint8Array(dig)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

function encodeKey(key: string): string {
  return key
    .split('/')
    .map((p) => encodeURIComponent(p))
    .join('/')
}

async function awsV4Headers(opts: {
  method: string
  host: string
  canonicalUri: string
  accessKey: string
  secretKey: string
  contentType?: string
  body: Uint8Array
  unsignedPayload?: boolean
  extraHeaders?: Record<string, string>
}): Promise<Record<string, string>> {
  const now = new Date()
  const amzDate = now.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z')
  const dateStamp = amzDate.slice(0, 8)
  const payloadHash = opts.unsignedPayload
    ? 'UNSIGNED-PAYLOAD'
    : await sha256Hex(opts.body)

  const headers: Record<string, string> = {
    host: opts.host,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date': amzDate,
  }
  if (opts.contentType) headers['content-type'] = opts.contentType
  if (opts.extraHeaders) {
    for (const [k, v] of Object.entries(opts.extraHeaders)) {
      headers[k.toLowerCase()] = v
    }
  }

  const signedNames = Object.keys(headers).sort()
  const canonicalHeaders = signedNames.map((k) => `${k}:${headers[k]}\n`).join('')
  const signedHeaders = signedNames.join(';')
  const canonicalRequest = [
    opts.method,
    opts.canonicalUri,
    '',
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n')

  const credentialScope = `${dateStamp}/${REGION}/${SERVICE}/aws4_request`
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    await sha256Hex(canonicalRequest),
  ].join('\n')

  const kDate = await hmac(new TextEncoder().encode(`AWS4${opts.secretKey}`), dateStamp)
  const kRegion = await hmac(kDate, REGION)
  const kService = await hmac(kRegion, SERVICE)
  const kSigning = await hmac(kService, 'aws4_request')
  const sigBuf = await hmac(kSigning, stringToSign)
  const signature = [...new Uint8Array(sigBuf)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')

  headers.authorization =
    `AWS4-HMAC-SHA256 Credential=${opts.accessKey}/${credentialScope}, ` +
    `SignedHeaders=${signedHeaders}, Signature=${signature}`
  return headers
}

export async function r2GetObject(key: string): Promise<Uint8Array | null> {
  const { endpoint, bucket, accessKey, secretKey } = requireS3Creds()
  const host = endpoint.replace(/^https?:\/\//, '')
  const canonicalUri = `/${bucket}/${encodeKey(key)}`
  const headers = await awsV4Headers({
    method: 'GET',
    host,
    canonicalUri,
    accessKey,
    secretKey,
    body: new Uint8Array(),
  })
  const res = await fetch(`${endpoint}${canonicalUri}`, { headers })
  if (res.status === 404) return null
  if (!res.ok) {
    throw new Error(`R2 GET ${key} failed HTTP ${res.status}`)
  }
  return new Uint8Array(await res.arrayBuffer())
}

/** Public custom-domain GET (no S3 keys). Returns null on 404. */
export async function r2GetObjectPublic(
  key: string,
): Promise<Uint8Array | null> {
  const { cdnBase } = r2Config()
  if (!cdnBase) return null
  const url = `${cdnBase}/${key.split('/').map(encodeURIComponent).join('/')}`
  const res = await fetch(url, {
    cache: 'no-store',
    headers: { Accept: 'application/json' },
  })
  if (res.status === 404) return null
  if (!res.ok) {
    throw new Error(`CDN GET ${key} failed HTTP ${res.status}`)
  }
  return new Uint8Array(await res.arrayBuffer())
}

export async function r2PutObject(
  key: string,
  body: Uint8Array | string,
  contentType = 'application/json',
): Promise<void> {
  const { endpoint, bucket, accessKey, secretKey } = requireS3Creds()
  const host = endpoint.replace(/^https?:\/\//, '')
  const canonicalUri = `/${bucket}/${encodeKey(key)}`
  const bytes =
    typeof body === 'string' ? new TextEncoder().encode(body) : body
  const headers = await awsV4Headers({
    method: 'PUT',
    host,
    canonicalUri,
    accessKey,
    secretKey,
    contentType,
    body: bytes,
    unsignedPayload: true,
    extraHeaders: {
      'cache-control': 'no-cache, max-age=0',
    },
  })
  const res = await fetch(`${endpoint}${canonicalUri}`, {
    method: 'PUT',
    headers,
    body: bufferSource(bytes),
  })
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(`R2 PUT ${key} failed HTTP ${res.status}: ${text}`)
  }
}
