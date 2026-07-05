use aes::cipher::{block_padding::Pkcs7, BlockDecryptMut, KeyIvInit};
use base64::{engine::general_purpose::STANDARD, Engine};
use md5::{Digest, Md5};
use pbkdf2::pbkdf2_hmac;
use sha2::Sha512;

type Aes256CbcDec = cbc::Decryptor<aes::Aes256>;

pub fn decrypt_blob(
    id: &str,
    server_key: &str,
    client_key: &str,
    cipher_bytes: &[u8],
) -> Option<String> {
    if cipher_bytes.len() < 17 {
        return None;
    }
    let salt = &cipher_bytes[8..16];
    let ct = &cipher_bytes[16..];
    let password = format!("{id}{server_key}{client_key}https://paste.sh");

    if let Some(out) = try_pbkdf2(ct, password.as_bytes(), salt) {
        if !out.is_empty() {
            return Some(out);
        }
    }
    try_evp(ct, password.as_bytes(), salt)
}

pub fn decrypt_from_paste_response(
    url_with_hash: &str,
    raw_response: &str,
) -> Option<String> {
    let hash_idx = url_with_hash.find('#')?;
    let base_url = &url_with_hash[..hash_idx];
    let client_key = &url_with_hash[hash_idx + 1..];
    let id = base_url.rsplit('/').next()?;
    let lines: Vec<&str> = raw_response.split('\n').collect();
    if lines.is_empty() {
        return None;
    }
    let server_key = lines[0].trim();
    let b64: String = lines.iter().skip(1).map(|l| l.trim()).collect();
    if b64.is_empty() {
        return None;
    }
    let cipher_bytes = STANDARD.decode(b64).ok()?;
    decrypt_blob(id, server_key, client_key, &cipher_bytes)
}

fn try_pbkdf2(ct: &[u8], password: &[u8], salt: &[u8]) -> Option<String> {
    let mut key_iv = [0u8; 48];
    pbkdf2_hmac::<Sha512>(password, salt, 1, &mut key_iv);
    let key = &key_iv[..32];
    let iv = &key_iv[32..48];
    aes_cbc_decrypt(ct, key, iv)
}

fn try_evp(ct: &[u8], password: &[u8], salt: &[u8]) -> Option<String> {
    let (key, iv) = evp_bytes_to_key(password, salt, 32, 16)?;
    aes_cbc_decrypt(ct, &key, &iv)
}

fn aes_cbc_decrypt(ct: &[u8], key: &[u8], iv: &[u8]) -> Option<String> {
    let key: [u8; 32] = key.try_into().ok()?;
    let iv: [u8; 16] = iv.try_into().ok()?;
    let mut buf = ct.to_vec();
    let pt = Aes256CbcDec::new(&key.into(), &iv.into())
        .decrypt_padded_mut::<Pkcs7>(&mut buf)
        .ok()?;
    String::from_utf8(pt.to_vec()).ok()
}

fn evp_bytes_to_key(password: &[u8], salt: &[u8], key_len: usize, iv_len: usize) -> Option<(Vec<u8>, Vec<u8>)> {
    let mut out = Vec::new();
    let mut prev: Vec<u8> = Vec::new();
    while out.len() < key_len + iv_len {
        let mut input = prev.clone();
        input.extend_from_slice(password);
        input.extend_from_slice(salt);
        let hash = Md5::digest(&input);
        prev = hash.to_vec();
        out.extend_from_slice(&prev);
    }
    Some((
        out[..key_len].to_vec(),
        out[key_len..key_len + iv_len].to_vec(),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_short_cipher() {
        assert!(decrypt_blob("id", "srv", "cli", &[0u8; 10]).is_none());
    }
}
