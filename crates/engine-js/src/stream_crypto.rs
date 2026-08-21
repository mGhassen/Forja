//! STREAMCRYPTO (`enc=2`) — port of Dart `StreamCrypto.decrypt`.

use base64::{engine::general_purpose::STANDARD, Engine as _};

const MASK: u32 = 0xFFFF_FFFF;
const GOLDEN: u32 = 0x9E37_79B9;
const MAGIC: [u8; 4] = [109, 118, 109, 49]; // mvm1

#[derive(Debug, thiserror::Error)]
pub enum StreamCryptoError {
    #[error("STREAMCRYPTO: payload too short")]
    TooShort,
    #[error("STREAMCRYPTO: invalid media id")]
    BadMediaId,
    #[error("STREAMCRYPTO: empty payload")]
    Empty,
    #[error("STREAMCRYPTO: invalid payload")]
    InvalidB64,
    #[error("STREAMCRYPTO: bad seed or tampered payload")]
    BadMagic,
    #[error("STREAMCRYPTO: utf8")]
    Utf8,
}

fn imul(a: u32, b: u32) -> u32 {
    a.wrapping_mul(b)
}

fn f(mut e: u32) -> u32 {
    e ^= e >> 16;
    e = imul(e, 2246822507);
    e ^= e >> 13;
    e = imul(e, 3266489909);
    e ^= e >> 16;
    e
}

fn rotl(e: u32, t: u32) -> u32 {
    let t = t & 31;
    if t == 0 {
        e
    } else {
        e.rotate_left(t)
    }
}

fn fnv_f(text: &str) -> u32 {
    let mut t: u32 = 2166136261;
    for code in text.chars() {
        t = imul(t ^ (code as u32), 16777619);
    }
    f(t)
}

fn key_schedule(seed: &str, media_id: u32) -> (std::collections::HashMap<u32, u32>, u32) {
    let mut n = f(fnv_f(seed) ^ f((media_id & MASK) ^ GOLDEN));
    let mut state = std::collections::HashMap::new();
    for e in 0..8u32 {
        let idx = n % 61;
        n = rotl(n.wrapping_add(GOLDEN), 7 + (e & 7));
        state.insert(idx, n ^ f(n));
        n = f(n.wrapping_add(idx));
    }
    let acc = f(2779096485 ^ n);
    (state, acc)
}

fn keystream(seed: &str, media_id: u32, length: usize) -> Vec<u8> {
    let (mut state, mut acc) = key_schedule(seed, media_id);
    let mut out = vec![0u8; length];
    let mut pos = 0usize;
    let mut counter = 0u32;
    while pos < length {
        let a = acc;
        let i = a % 61;
        let mask = if state.contains_key(&i) { MASK } else { 0 };
        let low = *state.get(&i).unwrap_or(&0);
        let mixed = low ^ imul(GOLDEN, counter + 1);
        let mut c = (a ^ mixed) | (a & mixed & mask);
        c = rotl(c.wrapping_add(a), i & 31) ^ rotl(a, imul(i, 7) & 31);
        acc = f(c.wrapping_add(GOLDEN));
        state.insert(i, acc);
        counter = counter.wrapping_add(1);
        let val = acc;
        out[pos] = (val & 255) as u8;
        pos += 1;
        if pos < length {
            out[pos] = ((val >> 8) & 255) as u8;
            pos += 1;
        }
        if pos < length {
            out[pos] = ((val >> 16) & 255) as u8;
            pos += 1;
        }
        if pos < length {
            out[pos] = ((val >> 24) & 255) as u8;
            pos += 1;
        }
    }
    out
}

fn b64url_decode(text: &str) -> Result<Vec<u8>, StreamCryptoError> {
    let mut t = text.trim().replace('-', "+").replace('_', "/");
    if t.is_empty() {
        return Err(StreamCryptoError::Empty);
    }
    let pad = (4 - t.len() % 4) % 4;
    t.push_str(&"=".repeat(pad));
    STANDARD
        .decode(t.as_bytes())
        .map_err(|_| StreamCryptoError::InvalidB64)
}

/// Decrypt an `enc=2` body into UTF-8 JSON (no `mvm1` prefix).
pub fn decrypt(payload: &str, seed: &str, media_id: &str) -> Result<String, StreamCryptoError> {
    let mut data = b64url_decode(payload)?;
    if data.len() < MAGIC.len() {
        return Err(StreamCryptoError::TooShort);
    }
    let id: u32 = media_id
        .trim()
        .parse()
        .map_err(|_| StreamCryptoError::BadMediaId)?;
    let ks = keystream(seed, id, data.len());
    for i in 0..data.len() {
        data[i] ^= ks[i];
    }
    if data[..MAGIC.len()] != MAGIC {
        return Err(StreamCryptoError::BadMagic);
    }
    String::from_utf8(data[MAGIC.len()..].to_vec()).map_err(|_| StreamCryptoError::Utf8)
}

/// Inverse of [decrypt] for unit round-trips.
#[cfg(test)]
pub fn encrypt_for_test(json: &str, seed: &str, media_id: &str) -> Result<String, StreamCryptoError> {
    let id: u32 = media_id.parse().map_err(|_| StreamCryptoError::BadMediaId)?;
    let mut plain = Vec::with_capacity(MAGIC.len() + json.len());
    plain.extend_from_slice(&MAGIC);
    plain.extend_from_slice(json.as_bytes());
    let ks = keystream(seed, id, plain.len());
    for i in 0..plain.len() {
        plain[i] ^= ks[i];
    }
    Ok(base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(plain))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip() {
        let seed = "test-seed-abc";
        let media = "94997";
        let json = r#"{"sources":[{"url":"https://x/a.m3u8","quality":"1080p"}]}"#;
        let payload = encrypt_for_test(json, seed, media).unwrap();
        let out = decrypt(&payload, seed, media).unwrap();
        assert_eq!(out, json);
    }
}
