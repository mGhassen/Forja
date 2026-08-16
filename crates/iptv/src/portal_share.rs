//! Self-contained IPTV portal share tokens (no pastebin / no server lookup).
//!
//! Format: `F1.` + URL-safe base64 (no pad) of `iv[16] || aes-256-cbc-pkcs7(json)`.
//! Key = SHA-256(`forja-iptv-share-embedded-v1`).

use aes::cipher::{block_padding::Pkcs7, BlockDecryptMut, BlockEncryptMut, KeyIvInit};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

type Aes256CbcEnc = cbc::Encryptor<aes::Aes256>;
type Aes256CbcDec = cbc::Decryptor<aes::Aes256>;

pub const TOKEN_PREFIX: &str = "F1.";
const KEY_MATERIAL: &[u8] = b"forja-iptv-share-embedded-v1";

fn derive_key() -> [u8; 32] {
    Sha256::digest(KEY_MATERIAL).into()
}

/// True when `raw` looks like an embedded `F1.` share token.
pub fn is_embedded_token(raw: &str) -> bool {
    raw.trim().starts_with(TOKEN_PREFIX)
}

/// Encrypt portal credentials into a self-contained share token.
pub fn encode(url: &str, username: &str, password: &str) -> Result<String, String> {
    let url = url.trim();
    let username = username.trim();
    let password = password.trim();
    if url.is_empty() || username.is_empty() || password.is_empty() {
        return Err("url, username, and password are required".into());
    }

    let plain = json!({
        "v": 1,
        "url": url,
        "username": username,
        "password": password,
    })
    .to_string();
    let plain_bytes = plain.as_bytes();

    let mut iv = [0u8; 16];
    getrandom::getrandom(&mut iv).map_err(|e| format!("rng: {e}"))?;

    let key = derive_key();
    let mut buf = vec![0u8; plain_bytes.len() + 16];
    buf[..plain_bytes.len()].copy_from_slice(plain_bytes);
    let ct = Aes256CbcEnc::new(&key.into(), &iv.into())
        .encrypt_padded_mut::<Pkcs7>(&mut buf, plain_bytes.len())
        .map_err(|_| "encrypt failed".to_string())?;

    let mut packed = Vec::with_capacity(16 + ct.len());
    packed.extend_from_slice(&iv);
    packed.extend_from_slice(ct);
    Ok(format!("{TOKEN_PREFIX}{}", URL_SAFE_NO_PAD.encode(packed)))
}

/// Decrypt an embedded share token into portal JSON
/// `{"url","username","password"}` (empty string / error JSON on failure via FFI helpers).
pub fn decode(token: &str) -> Result<(String, String, String), String> {
    let token = token.trim();
    if !token.starts_with(TOKEN_PREFIX) {
        return Err("not an embedded share token".into());
    }
    let b64 = &token[TOKEN_PREFIX.len()..];
    if b64.is_empty() {
        return Err("empty payload".into());
    }
    let packed = URL_SAFE_NO_PAD
        .decode(b64.as_bytes())
        .or_else(|_| base64::engine::general_purpose::STANDARD.decode(b64.as_bytes()))
        .map_err(|e| format!("base64: {e}"))?;
    if packed.len() < 32 || packed.len() % 16 != 0 {
        return Err("invalid payload length".into());
    }
    let (iv, ct) = packed.split_at(16);
    let key = derive_key();
    let iv: [u8; 16] = iv.try_into().map_err(|_| "bad iv".to_string())?;
    let mut buf = ct.to_vec();
    let pt = Aes256CbcDec::new(&key.into(), &iv.into())
        .decrypt_padded_mut::<Pkcs7>(&mut buf)
        .map_err(|_| "decrypt failed".to_string())?;
    let text = String::from_utf8(pt.to_vec()).map_err(|_| "utf8".to_string())?;
    let value: Value =
        serde_json::from_str(&text).map_err(|e| format!("json: {e}"))?;
    let url = value
        .get("url")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "missing url".to_string())?
        .to_string();
    let username = value
        .get("username")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "missing username".to_string())?
        .to_string();
    let password = value
        .get("password")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "missing password".to_string())?
        .to_string();
    Ok((url, username, password))
}

/// FFI-friendly: returns portal JSON or empty string on failure.
pub fn encode_token(url: &str, username: &str, password: &str) -> String {
    encode(url, username, password).unwrap_or_default()
}

/// FFI-friendly: returns `{"url","username","password"}` or empty string on failure.
pub fn decode_token_json(token: &str) -> String {
    match decode(token) {
        Ok((url, username, password)) => json!({
            "url": url,
            "username": username,
            "password": password,
        })
        .to_string(),
        Err(_) => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip() {
        let token = encode(
            "http://portal.example.com:8080",
            "user1",
            "pass1",
        )
        .unwrap();
        assert!(token.starts_with(TOKEN_PREFIX));
        assert!(is_embedded_token(&token));
        let (url, user, pass) = decode(&token).unwrap();
        assert_eq!(url, "http://portal.example.com:8080");
        assert_eq!(user, "user1");
        assert_eq!(pass, "pass1");
    }

    #[test]
    fn rejects_legacy_short_code() {
        assert!(decode("FGNVUSEL").is_err());
        assert!(!is_embedded_token("FGNVUSEL"));
    }

    #[test]
    fn rejects_tampered() {
        let mut token = encode("http://x", "u", "p").unwrap();
        token.push('x');
        assert!(decode(&token).is_err());
    }

    #[test]
    fn ffi_helpers() {
        let token = encode_token("http://x", "u", "p");
        assert!(!token.is_empty());
        let json = decode_token_json(&token);
        assert!(json.contains("http://x"));
        assert!(decode_token_json("nope").is_empty());
    }
}
