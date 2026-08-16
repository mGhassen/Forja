/** Client share-code helpers (same crypto as apps/web). */

const EMBEDDED_PREFIX = 'F1.'
const KEY_MATERIAL = 'forja-iptv-share-embedded-v1'

export type SharePortal = {
  url: string
  username: string
  password: string
}

export function isEmbeddedShareToken(raw: string): boolean {
  return raw.trim().startsWith(EMBEDDED_PREFIX)
}

export function formatShareCode(raw: string): string {
  return raw.trim()
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

async function embeddedKey(): Promise<CryptoKey> {
  const raw = await sha256(KEY_MATERIAL)
  return crypto.subtle.importKey('raw', raw, { name: 'AES-CBC' }, false, [
    'encrypt',
    'decrypt',
  ])
}

async function encodeEmbeddedShare(portal: SharePortal): Promise<string> {
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
): Promise<SharePortal | null> {
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
    return { url, username, password }
  } catch {
    return null
  }
}

/** Encrypt credentials into a self-contained `F1.` token (no server). */
export async function createPortalShare(portal: SharePortal): Promise<string> {
  return encodeEmbeddedShare(portal)
}

/** Resolve an `F1.` token. */
export async function resolvePortalShare(
  rawCode: string,
): Promise<SharePortal | null> {
  const trimmed = rawCode.trim()
  if (!isEmbeddedShareToken(trimmed)) return null
  return decodeEmbeddedShare(trimmed)
}
