import type { IptvPortalRow } from '@/lib/sync-domains'

const SHARE_CODE_LENGTH = 8
const CHARSET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'
const KEY_PREFIX = 'forja-iptv-share-v1:'
const IV_PREFIX = 'forja-iptv-iv-v1:'

export function normalizeShareCode(raw: string): string {
  return raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, '')
}

export function isValidShareCode(raw: string): boolean {
  return normalizeShareCode(raw).length === SHARE_CODE_LENGTH
}

export function formatShareCode(raw: string): string {
  const code = normalizeShareCode(raw)
  if (code.length <= 4) return code
  return `${code.slice(0, 4)}-${code.slice(4)}`
}

function generateCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(SHARE_CODE_LENGTH))
  return Array.from(bytes, (b) => CHARSET[b % CHARSET.length]).join('')
}

async function sha256(text: string): Promise<Uint8Array> {
  const data = new TextEncoder().encode(text)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return new Uint8Array(digest)
}

async function deriveKey(code: string): Promise<CryptoKey> {
  const raw = await sha256(`${KEY_PREFIX}${code}`)
  return crypto.subtle.importKey('raw', raw, { name: 'AES-CBC' }, false, [
    'encrypt',
    'decrypt',
  ])
}

async function deriveIv(code: string): Promise<Uint8Array> {
  const hash = await sha256(`${IV_PREFIX}${code}`)
  return hash.slice(0, 16)
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary)
}

function base64ToBytes(value: string): Uint8Array {
  const clean = value.replace(/\n/g, '').trim()
  const binary = atob(clean)
  const out = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i += 1) out[i] = binary.charCodeAt(i)
  return out
}

async function encryptPortal(
  portal: Pick<IptvPortalRow, 'url' | 'username' | 'password'>,
  code: string,
): Promise<string> {
  const plain = new TextEncoder().encode(
    JSON.stringify({
      v: 1,
      url: portal.url,
      username: portal.username,
      password: portal.password,
    }),
  )
  const key = await deriveKey(code)
  const iv = await deriveIv(code)
  const cipher = await crypto.subtle.encrypt(
    { name: 'AES-CBC', iv },
    key,
    plain,
  )
  return bytesToBase64(new Uint8Array(cipher))
}

async function decryptPortal(
  encryptedB64: string,
  code: string,
): Promise<IptvPortalRow | null> {
  try {
    const key = await deriveKey(code)
    const iv = await deriveIv(code)
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
      label: '',
      name: username || url,
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

/** Encrypt credentials and upload ciphertext; returns 8-char share code. */
export async function createPortalShare(
  portal: Pick<IptvPortalRow, 'url' | 'username' | 'password'>,
): Promise<string> {
  let lastError: unknown
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const code = generateCode()
    try {
      const text = await encryptPortal(portal, code)
      await postShareApi('/api/iptv-share', { action: 'create', code, text })
      return code
    } catch (error) {
      lastError = error
      const message = error instanceof Error ? error.message : ''
      if (message.toLowerCase().includes('already in use')) continue
      throw error
    }
  }
  throw new Error(
    lastError instanceof Error
      ? lastError.message
      : 'Could not allocate share code',
  )
}

/** Resolve an 8-char share code into portal credentials. */
export async function resolvePortalShare(
  rawCode: string,
): Promise<IptvPortalRow | null> {
  const code = normalizeShareCode(rawCode)
  if (code.length !== SHARE_CODE_LENGTH) return null
  const json = await postShareApi('/api/iptv-share', { action: 'fetch', code })
  const text = typeof json.text === 'string' ? json.text : ''
  if (!text) return null
  return decryptPortal(text, code)
}
