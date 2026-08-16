import type { IptvPortalRow } from '@/lib/sync-domains'
import { supabase, supabaseConfigured } from '@/lib/supabase'

const SHARE_CODE_LENGTH = 8
const EMBEDDED_PREFIX = 'F1.'
const KEY_MATERIAL = 'forja-iptv-share-embedded-v1'
const CHARSET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'

export function isEmbeddedShareToken(raw: string): boolean {
  return raw.trim().startsWith(EMBEDDED_PREFIX)
}

export function normalizeShareCode(raw: string): string {
  return raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, '')
}

export function formatShareCode(raw: string): string {
  const trimmed = raw.trim()
  if (isEmbeddedShareToken(trimmed)) return trimmed
  const code = normalizeShareCode(trimmed)
  if (code.length <= 4) return code
  return `${code.slice(0, 4)}-${code.slice(4)}`
}

function generateShareCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(SHARE_CODE_LENGTH))
  let out = ''
  for (const b of bytes) out += CHARSET[b % CHARSET.length]!
  return out
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

/** Encrypt credentials and store under an 8-char code. */
export async function createPortalShare(
  portal: Pick<IptvPortalRow, 'url' | 'username' | 'password'>,
): Promise<string> {
  if (!supabaseConfigured) throw new Error('Share service unavailable')
  const token = await encodeEmbeddedShare(portal)
  for (let i = 0; i < 6; i += 1) {
    const code = generateShareCode()
    const { error } = await supabase
      .from('iptv_share_codes')
      .insert({ code, token })
    if (!error) return code
    if (error.code === '23505') continue
    throw new Error(error.message || 'Could not create share code')
  }
  throw new Error('Could not allocate share code')
}

/** Resolve an 8-char code or a leftover `F1.` token. */
export async function resolvePortalShare(
  rawCode: string,
): Promise<IptvPortalRow | null> {
  const trimmed = rawCode.trim()
  if (isEmbeddedShareToken(trimmed)) {
    return decodeEmbeddedShare(trimmed)
  }
  const code = normalizeShareCode(trimmed)
  if (code.length !== SHARE_CODE_LENGTH) return null
  if (!supabaseConfigured) throw new Error('Share service unavailable')
  const { data, error } = await supabase
    .from('iptv_share_codes')
    .select('token')
    .eq('code', code)
    .maybeSingle()
  if (error || !data?.token) return null
  return decodeEmbeddedShare(data.token)
}
