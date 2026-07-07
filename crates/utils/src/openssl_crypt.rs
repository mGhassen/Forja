use aes::cipher::{block_padding::Pkcs7, BlockDecryptMut, KeyIvInit};
use base64::{engine::general_purpose::STANDARD, Engine};
use md5::{Digest, Md5};

type Aes256CbcDec = cbc::Decryptor<aes::Aes256>;

/// CryptoJS / OpenSSL-compatible AES-256-CBC decrypt of a base64 `Salted__` blob.
pub fn decrypt_openssl_salted_b64(b64: &str, passphrase: &str) -> Result<String, String> {
    let raw = STANDARD
        .decode(b64.trim())
        .map_err(|e| format!("base64: {e}"))?;
    if raw.len() < 17 {
        return Err("blob too short".into());
    }
    if &raw[..8] != b"Salted__" {
        return Err("not an OpenSSL Salted__ blob".into());
    }
    let salt = &raw[8..16];
    let ct = &raw[16..];
    let (key, iv) = evp_bytes_to_key(passphrase.as_bytes(), salt, 32, 16)
        .ok_or_else(|| "evp key derivation failed".to_string())?;
    aes_cbc_decrypt(ct, &key, &iv).ok_or_else(|| "aes decrypt failed".into())
}

pub fn decrypt_openssl_salted_b64_json(b64: &str, passphrase: &str) -> String {
    match decrypt_openssl_salted_b64(b64, passphrase) {
        Ok(text) => text,
        Err(error) => serde_json::json!({ "error": error }).to_string(),
    }
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

fn evp_bytes_to_key(
    password: &[u8],
    salt: &[u8],
    key_len: usize,
    iv_len: usize,
) -> Option<(Vec<u8>, Vec<u8>)> {
    let mut out = Vec::new();
    let mut prev: Vec<u8> = Vec::new();
    while out.len() < key_len + iv_len {
        let mut input = prev;
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
    use aes::cipher::{BlockEncryptMut, KeyIvInit};

    type Aes256CbcEnc = cbc::Encryptor<aes::Aes256>;

    fn encrypt_fixture(plaintext: &str, passphrase: &str, salt: [u8; 8]) -> String {
        let (key, iv) = evp_bytes_to_key(passphrase.as_bytes(), &salt, 32, 16).unwrap();
        let key: [u8; 32] = key.try_into().unwrap();
        let iv: [u8; 16] = iv.try_into().unwrap();
        let pt = plaintext.as_bytes();
        let mut buf = vec![0u8; pt.len() + 16];
        buf[..pt.len()].copy_from_slice(pt);
        let enc = Aes256CbcEnc::new(&key.into(), &iv.into())
            .encrypt_padded_mut::<Pkcs7>(&mut buf, pt.len())
            .unwrap();
        let mut out = b"Salted__".to_vec();
        out.extend_from_slice(&salt);
        out.extend_from_slice(enc);
        STANDARD.encode(out)
    }

    #[test]
    fn round_trip_empty_passphrase() {
        let b64 = encrypt_fixture(r#"{"sources":[{"url":"https://x/a.m3u8"}]}"#, "", [9; 8]);
        let plain = decrypt_openssl_salted_b64(&b64, "").unwrap();
        assert!(plain.contains("sources"));
    }

    #[test]
    fn rejects_non_salted_blob() {
        let b64 = STANDARD.encode(b"not salted");
        assert!(decrypt_openssl_salted_b64(&b64, "").is_err());
    }
}
