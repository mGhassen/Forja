import { createDecipheriv, createHash, pbkdf2Sync } from 'node:crypto'

/**
 * Port of crates/iptv/src/pastesh.rs — paste.sh AES-256-CBC decrypt.
 * Current paste.sh `.txt` bodies are OpenSSL `Salted__` blobs (no server-key line);
 * older responses used `serverKey\n` + ciphertext.
 */
export function decryptFromPasteResponse(
  urlWithHash: string,
  rawResponse: string,
): string | null {
  const hashIdx = urlWithHash.indexOf('#')
  if (hashIdx < 0) return null
  const baseUrl = urlWithHash.slice(0, hashIdx)
  const clientKey = urlWithHash.slice(hashIdx + 1)
  const id = baseUrl.split('/').pop()
  if (!id || !clientKey) return null

  const { serverKey, b64 } = splitPasteBody(rawResponse)
  if (!b64) return null

  let cipherBytes: Buffer
  try {
    cipherBytes = Buffer.from(b64, 'base64')
  } catch {
    return null
  }
  return decryptBlob(id, serverKey, clientKey, cipherBytes)
}

function splitPasteBody(rawResponse: string): { serverKey: string; b64: string } {
  const compact = rawResponse.replace(/\s+/g, '')
  // OpenSSL Salted__ in base64 starts with U2FsdGVkX1
  if (compact.startsWith('U2FsdGVkX1')) {
    return { serverKey: '', b64: compact }
  }

  const lines = rawResponse.split('\n')
  const serverKey = (lines[0] ?? '').trim()
  const b64 = lines
    .slice(1)
    .map((l) => l.trim())
    .join('')
  return { serverKey, b64 }
}

function decryptBlob(
  id: string,
  serverKey: string,
  clientKey: string,
  cipherBytes: Buffer,
): string | null {
  if (cipherBytes.length < 17) return null
  const salt = cipherBytes.subarray(8, 16)
  const ct = cipherBytes.subarray(16)
  const password = `${id}${serverKey}${clientKey}https://paste.sh`

  const pbkdf = tryPbkdf2(ct, password, salt)
  if (pbkdf != null && pbkdf.length > 0) return pbkdf
  return tryEvp(ct, password, salt)
}

function tryPbkdf2(ct: Buffer, password: string, salt: Buffer): string | null {
  try {
    const keyIv = pbkdf2Sync(password, salt, 1, 48, 'sha512')
    return aesCbcDecrypt(ct, keyIv.subarray(0, 32), keyIv.subarray(32, 48))
  } catch {
    return null
  }
}

function tryEvp(ct: Buffer, password: string, salt: Buffer): string | null {
  const keyIv = evpBytesToKey(Buffer.from(password), salt, 32, 16)
  if (!keyIv) return null
  return aesCbcDecrypt(ct, keyIv.key, keyIv.iv)
}

function aesCbcDecrypt(ct: Buffer, key: Buffer, iv: Buffer): string | null {
  try {
    const decipher = createDecipheriv('aes-256-cbc', key, iv)
    const out = Buffer.concat([decipher.update(ct), decipher.final()])
    return out.toString('utf8')
  } catch {
    return null
  }
}

/** OpenSSL EVP_BytesToKey (MD5). */
function evpBytesToKey(
  password: Buffer,
  salt: Buffer,
  keyLen: number,
  ivLen: number,
): { key: Buffer; iv: Buffer } | null {
  const out: Buffer[] = []
  let prev = Buffer.alloc(0)
  while (Buffer.concat(out).length < keyLen + ivLen) {
    const h = createHash('md5')
    h.update(prev)
    h.update(password)
    h.update(salt)
    prev = h.digest()
    out.push(prev)
  }
  const buf = Buffer.concat(out)
  return {
    key: buf.subarray(0, keyLen),
    iv: buf.subarray(keyLen, keyLen + ivLen),
  }
}
