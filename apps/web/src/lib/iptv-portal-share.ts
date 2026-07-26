import type { IptvPortalRow } from '@/lib/sync-domains'

const SHARE_CODE_LENGTH = 8
const EMBEDDED_PREFIX = 'F1.'
const KEY_MATERIAL = 'forja-iptv-share-embedded-v1'
/** Legacy rentry key/IV prefixes (8-char codes only). */
const LEGACY_KEY_PREFIX = 'forja-iptv-share-v1:'
const LEGACY_IV_PREFIX = 'forja-iptv-iv-v1:'

export function normalizeShareCode(raw: string): string {
  return raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, '')
}

export function isEmbeddedShareToken(raw: string): boolean {
  return raw.trim().startsWith(EMBEDDED_PREFIX)
}

export function isValidShareCode(raw: string): boolean {
  if (isEmbeddedShareToken(raw)) return raw.trim().length > EMBEDDED_PREFIX.length + 16
  return normalizeShareCode(raw).length === SHARE_CODE_LENGTH
}

export function formatShareCode(raw: string): string {
  const trimmed = raw.trim()
  if (isEmbeddedShareToken(trimmed)) return trimmed
  const code = normalizeShareCode(trimmed)
  if (code.length <= 4) return code
  return `${code.slice(0, 4)}-${code.slice(4)}`
}

async function sha256(text: string): Promise<Uint8Array> {
  const data = new TextEncoder().encode(text)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return new Uint8Array(digest)
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
}

function base64UrlToBytes(value: string): Uint8Array {
  const clean = value.replace(/\n/g, '').trim()
  const padded = clean.replace(/-/g, '+').replace(/_/g, '/')
  const padLen = (4 - (padded.length % 4)) % 4
  const binary = atob(padded + '='.repeat(padLen))
  const out = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i += 1) out[i] = binary.charCodeAt(i)
  return out
}

function base64ToBytes(value: string): Uint8Array {
  const clean = value.replace(/\n/g, '').trim()
  const binary = atob(clean)
  const out = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i += 1) out[i] = binary.charCodeAt(i)
  return out
}

async function embeddedKey(): Promise<CryptoKey> {
  const raw = await sha256(KEY_MATERIAL)
  return crypto.subtle.importKey('raw', raw, { name: 'AES-CBC' }, false, [
    'encrypt',
    'decrypt',
  ])
}

async function encodeEmbeddedShare(
  portal: Pick<IptvPortalRow, 'url' | 'username' | 'password'>,
): Promise<string> {
  const url = portal.url.trim()
  const username = portal.username.trim()
  const password = portal.password.trim()
  if (!url || !username || !password) {
    throw new Error('url, username, and password are required')
  }
  const plain = new TextEncoder().encode(
    JSON.stringify({
      v: 1,
      url,
      username,
      password,
    }),
  )
  const iv = crypto.getRandomValues(new Uint8Array(16))
  const key = await embeddedKey()
  const cipher = await crypto.subtle.encrypt({ name: 'AES-CBC', iv }, key, plain)
  const packed = new Uint8Array(16 + cipher.byteLength)
  packed.set(iv, 0)
  packed.set(new Uint8Array(cipher), 16)
  return `${EMBEDDED_PREFIX}${bytesToBase64Url(packed)}`
}

async function decodeEmbeddedShare(
  token: string,
): Promise<IptvPortalRow | null> {
  try {
    const trimmed = token.trim()
    if (!trimmed.startsWith(EMBEDDED_PREFIX)) return null
    const packed = base64UrlToBytes(trimmed.slice(EMBEDDED_PREFIX.length))
    if (packed.length < 32 || packed.length % 16 !== 0) return null
    const iv = packed.slice(0, 16)
    const cipherBytes = packed.slice(16)
    const key = await embeddedKey()
    const plainBuf = await crypto.subtle.decrypt(
      { name: 'AES-CBC', iv },
      key,
      cipherBytes,
    )
    const decoded = JSON.parse(new TextDecoder().decode(plainBuf)) as {
      url?: string
      username?: string
      password?: string
    }
    const url = decoded.url?.trim() ?? ''
    const username = decoded.username?.trim() ?? ''
    const password = decoded.password?.trim() ?? ''
    if (!url || !username || !password) return null
    return {
      url,
      username,
      password,
      source: 'Shared',
      portalName: '',
      expiry: '',
      max: '1',
      active: '0',
    }
  } catch {
    return null
  }
}

async function deriveLegacyKey(code: string): Promise<CryptoKey> {
  const raw = await sha256(`${LEGACY_KEY_PREFIX}${code}`)
  return crypto.subtle.importKey('raw', raw, { name: 'AES-CBC' }, false, [
    'encrypt',
    'decrypt',
  ])
}

async function deriveLegacyIv(code: string): Promise<Uint8Array> {
  const hash = await sha256(`${LEGACY_IV_PREFIX}${code}`)
  return hash.slice(0, 16)
}

async function decryptLegacyPortal(
  encryptedB64: string,
  code: string,
): Promise<IptvPortalRow | null> {
  try {
    const key = await deriveLegacyKey(code)
    const iv = await deriveLegacyIv(code)
    const cipherBytes = base64ToBytes(encryptedB64)
    const plainBuf = await crypto.subtle.decrypt(
      { name: 'AES-CBC', iv },
      key,
      cipherBytes,
    )
    const decoded = JSON.parse(new TextDecoder().decode(plainBuf)) as {
      url?: string
      username?: string
      password?: string
    }
    const url = decoded.url?.trim() ?? ''
    const username = decoded.username?.trim() ?? ''
    const password = decoded.password?.trim() ?? ''
    if (!url || !username || !password) return null
    return {
      url,
      username,
      password,
      source: 'Shared',
      portalName: '',
      expiry: '',
      max: '1',
      active: '0',
    }
  } catch {
    return null
  }
}

async function postShareApi(
  path: string,
  body: Record<string, string>,
): Promise<Record<string, unknown>> {
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const json = (await response.json().catch(() => ({}))) as Record<
    string,
    unknown
  >
  if (!response.ok) {
    throw new Error(
      typeof json.error === 'string' ? json.error : 'Share service failed',
    )
  }
  return json
}

/** Encrypt credentials into a self-contained `F1.` token (no pastebin). */
export async function createPortalShare(
  portal: Pick<IptvPortalRow, 'url' | 'username' | 'password'>,
): Promise<string> {
  return encodeEmbeddedShare(portal)
}

/** Resolve an `F1.` token or a legacy 8-char rentry code. */
export async function resolvePortalShare(
  rawCode: string,
): Promise<IptvPortalRow | null> {
  const trimmed = rawCode.trim()
  if (isEmbeddedShareToken(trimmed)) {
    return decodeEmbeddedShare(trimmed)
  }
  const code = normalizeShareCode(trimmed)
  if (code.length !== SHARE_CODE_LENGTH) return null
  const json = await postShareApi('/api/iptv-share', { action: 'fetch', code })
  const text = typeof json.text === 'string' ? json.text : ''
  if (!text) return null
  return decryptLegacyPortal(text, code)
}
