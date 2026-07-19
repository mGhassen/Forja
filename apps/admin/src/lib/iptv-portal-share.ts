/** Client share-code helpers (same crypto + API as apps/web). */

const SHARE_CODE_LENGTH = 8
const CHARSET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'
const KEY_PREFIX = 'forja-iptv-share-v1:'
const IV_PREFIX = 'forja-iptv-iv-v1:'

export type SharePortal = {
  url: string
  username: string
  password: string
}

export function normalizeShareCode(raw: string): string {
  return raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, '')
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

async function encryptPortal(
  portal: SharePortal,
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
export async function createPortalShare(portal: SharePortal): Promise<string> {
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
