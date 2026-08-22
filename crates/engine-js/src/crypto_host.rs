//! Native crypto for the CryptoJS façade (hex in / hex out).

use aes::cipher::{block_padding::Pkcs7, BlockDecryptMut, BlockEncryptMut, KeyIvInit};
use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes128Gcm, Aes256Gcm, Nonce,
};
use cbc::{Decryptor as CbcDecryptor, Encryptor as CbcEncryptor};
use hmac::Mac;
use md5::{Digest as _, Md5};
use sha1::Sha1;
use sha2::{Sha256, Sha512};

type Aes128CbcEnc = CbcEncryptor<aes::Aes128>;
type Aes128CbcDec = CbcDecryptor<aes::Aes128>;
type Aes256CbcEnc = CbcEncryptor<aes::Aes256>;
type Aes256CbcDec = CbcDecryptor<aes::Aes256>;

pub fn bytes_from_hex(hex: &str) -> Result<Vec<u8>, String> {
    let cleaned: String = hex
        .trim()
        .to_lowercase()
        .chars()
        .filter(|c| !c.is_whitespace())
        .collect();
    if cleaned.is_empty() {
        return Ok(vec![]);
    }
    let even = if cleaned.len() % 2 == 0 {
        cleaned
    } else {
        format!("0{cleaned}")
    };
    let mut out = Vec::with_capacity(even.len() / 2);
    for i in 0..(even.len() / 2) {
        let v = u8::from_str_radix(&even[i * 2..i * 2 + 2], 16)
            .map_err(|_| "invalid hex".to_string())?;
        out.push(v);
    }
    Ok(out)
}

pub fn hex_from_bytes(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

pub fn utf8_to_hex(data: &str) -> String {
    hex_from_bytes(data.as_bytes())
}

pub fn hex_to_utf8(hex: &str) -> String {
    let Ok(bytes) = bytes_from_hex(hex) else {
        return String::new();
    };
    String::from_utf8_lossy(&bytes).into_owned()
}

pub fn digest_hex(algo: &str, data: &str) -> String {
    digest_hex_bytes(algo, data.as_bytes())
}

pub fn digest_hex_bytes(algo: &str, data: &[u8]) -> String {
    let a = algo.to_uppercase();
    if a.contains("MD5") {
        return hex_from_bytes(&Md5::digest(data));
    }
    if a.contains("SHA1") || a == "SHA-1" {
        return hex_from_bytes(&Sha1::digest(data));
    }
    if a.contains("SHA512") {
        return hex_from_bytes(&Sha512::digest(data));
    }
    hex_from_bytes(&Sha256::digest(data))
}

pub fn hmac_hex(algo: &str, key: &str, data: &str) -> String {
    let a = algo.to_uppercase();
    if a.contains("MD5") {
        let mut mac = <hmac::Hmac<Md5> as Mac>::new_from_slice(key.as_bytes()).unwrap();
        mac.update(data.as_bytes());
        return hex_from_bytes(&mac.finalize().into_bytes());
    }
    if a.contains("SHA1") {
        let mut mac = <hmac::Hmac<Sha1> as Mac>::new_from_slice(key.as_bytes()).unwrap();
        mac.update(data.as_bytes());
        return hex_from_bytes(&mac.finalize().into_bytes());
    }
    if a.contains("SHA512") {
        let mut mac = <hmac::Hmac<Sha512> as Mac>::new_from_slice(key.as_bytes()).unwrap();
        mac.update(data.as_bytes());
        return hex_from_bytes(&mac.finalize().into_bytes());
    }
    let mut mac = <hmac::Hmac<Sha256> as Mac>::new_from_slice(key.as_bytes()).unwrap();
    mac.update(data.as_bytes());
    hex_from_bytes(&mac.finalize().into_bytes())
}

/// AES hex in / hex out. Modes: AES-CBC, AES-GCM, AES-ECB (+ optional -NoPadding).
pub fn aes_hex(
    encrypt: bool,
    mode: &str,
    key_hex: &str,
    iv_hex: &str,
    data_hex: &str,
) -> Result<String, String> {
    let key = bytes_from_hex(key_hex)?;
    let iv = bytes_from_hex(iv_hex)?;
    let data = bytes_from_hex(data_hex)?;
    let normalized = mode
        .to_uppercase()
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .collect::<String>();
    let no_padding = normalized.contains("NOPADDING");
    let out = if normalized.contains("GCM") {
        aes_gcm(encrypt, &key, &iv, &data)?
    } else if normalized.contains("ECB") {
        aes_ecb(encrypt, &key, &data, !no_padding)?
    } else {
        aes_cbc(encrypt, &key, &iv, &data, !no_padding)?
    };
    Ok(hex_from_bytes(&out))
}

fn aes_cbc(
    encrypt: bool,
    key: &[u8],
    iv: &[u8],
    data: &[u8],
    pkcs7: bool,
) -> Result<Vec<u8>, String> {
    if iv.len() != 16 {
        return Err("AES-CBC requires a 16-byte IV".into());
    }
    match (key.len(), encrypt, pkcs7) {
        (16, true, true) => {
            let enc = Aes128CbcEnc::new(key.into(), iv.into());
            Ok(enc.encrypt_padded_vec_mut::<Pkcs7>(data))
        }
        (16, false, true) => {
            let mut buf = data.to_vec();
            Aes128CbcDec::new(key.into(), iv.into())
                .decrypt_padded_mut::<Pkcs7>(&mut buf)
                .map(|pt| pt.to_vec())
                .map_err(|e| e.to_string())
        }
        (32, true, true) => {
            let enc = Aes256CbcEnc::new(key.into(), iv.into());
            Ok(enc.encrypt_padded_vec_mut::<Pkcs7>(data))
        }
        (32, false, true) => {
            let mut buf = data.to_vec();
            Aes256CbcDec::new(key.into(), iv.into())
                .decrypt_padded_mut::<Pkcs7>(&mut buf)
                .map(|pt| pt.to_vec())
                .map_err(|e| e.to_string())
        }
        (16 | 32, true, false) => {
            if data.len() % 16 != 0 {
                return Err("AES-CBC input must be a multiple of 16 bytes".into());
            }
            let mut buf = data.to_vec();
            if key.len() == 16 {
                let mut enc = Aes128CbcEnc::new(key.into(), iv.into());
                for chunk in buf.chunks_exact_mut(16) {
                    enc.encrypt_block_mut(chunk.into());
                }
            } else {
                let mut enc = Aes256CbcEnc::new(key.into(), iv.into());
                for chunk in buf.chunks_exact_mut(16) {
                    enc.encrypt_block_mut(chunk.into());
                }
            }
            Ok(buf)
        }
        (16 | 32, false, false) => {
            if data.len() % 16 != 0 {
                return Err("AES-CBC input must be a multiple of 16 bytes".into());
            }
            let mut buf = data.to_vec();
            if key.len() == 16 {
                let mut dec = Aes128CbcDec::new(key.into(), iv.into());
                for chunk in buf.chunks_exact_mut(16) {
                    dec.decrypt_block_mut(chunk.into());
                }
            } else {
                let mut dec = Aes256CbcDec::new(key.into(), iv.into());
                for chunk in buf.chunks_exact_mut(16) {
                    dec.decrypt_block_mut(chunk.into());
                }
            }
            Ok(buf)
        }
        _ => Err("AES key must be 16 or 32 bytes".into()),
    }
}

fn aes_ecb(encrypt: bool, key: &[u8], data: &[u8], pkcs7: bool) -> Result<Vec<u8>, String> {
    use aes::cipher::{BlockDecrypt, BlockEncrypt, KeyInit as AesKeyInit};
    let mut out = if encrypt && pkcs7 {
        pkcs7_pad(data, 16)
    } else {
        data.to_vec()
    };
    if out.len() % 16 != 0 {
        return Err("AES-ECB input must be a multiple of 16 bytes".into());
    }
    match key.len() {
        16 => {
            let cipher = aes::Aes128::new(key.into());
            for chunk in out.chunks_exact_mut(16) {
                if encrypt {
                    cipher.encrypt_block(chunk.into());
                } else {
                    cipher.decrypt_block(chunk.into());
                }
            }
        }
        32 => {
            let cipher = aes::Aes256::new(key.into());
            for chunk in out.chunks_exact_mut(16) {
                if encrypt {
                    cipher.encrypt_block(chunk.into());
                } else {
                    cipher.decrypt_block(chunk.into());
                }
            }
        }
        _ => return Err("AES key must be 16 or 32 bytes".into()),
    }
    if !encrypt && pkcs7 {
        out = pkcs7_unpad(&out, 16)?;
    }
    Ok(out)
}

fn aes_gcm(encrypt: bool, key: &[u8], iv: &[u8], data: &[u8]) -> Result<Vec<u8>, String> {
    if iv.len() != 12 {
        return Err(format!("AES-GCM IV must be 12 bytes (got {})", iv.len()));
    }
    let nonce = Nonce::from_slice(iv);
    match key.len() {
        16 => {
            let cipher = Aes128Gcm::new_from_slice(key).map_err(|e| e.to_string())?;
            if encrypt {
                cipher.encrypt(nonce, data).map_err(|e| e.to_string())
            } else {
                cipher.decrypt(nonce, data).map_err(|e| e.to_string())
            }
        }
        32 => {
            let cipher = Aes256Gcm::new_from_slice(key).map_err(|e| e.to_string())?;
            if encrypt {
                cipher.encrypt(nonce, data).map_err(|e| e.to_string())
            } else {
                cipher.decrypt(nonce, data).map_err(|e| e.to_string())
            }
        }
        _ => Err("AES-GCM key must be 16 or 32 bytes".into()),
    }
}

fn pkcs7_pad(data: &[u8], block: usize) -> Vec<u8> {
    let pad = block - (data.len() % block);
    let mut out = Vec::with_capacity(data.len() + pad);
    out.extend_from_slice(data);
    out.extend(std::iter::repeat(pad as u8).take(pad));
    out
}

fn pkcs7_unpad(data: &[u8], block: usize) -> Result<Vec<u8>, String> {
    if data.is_empty() || data.len() % block != 0 {
        return Err("invalid padded data".into());
    }
    let pad = *data.last().unwrap() as usize;
    if pad == 0 || pad > block {
        return Err("invalid pkcs7 padding".into());
    }
    if data[data.len() - pad..].iter().any(|&b| b as usize != pad) {
        return Err("invalid pkcs7 padding".into());
    }
    Ok(data[..data.len() - pad].to_vec())
}

pub fn aes_bridge_json(payload: &str) -> String {
    let Ok(v) = serde_json::from_str::<serde_json::Value>(payload) else {
        return String::new();
    };
    let encrypt = v.get("encrypt").and_then(|x| x.as_bool()).unwrap_or(false);
    let mode = v
        .get("mode")
        .and_then(|x| x.as_str())
        .unwrap_or("AES-CBC");
    let key = v.get("key").and_then(|x| x.as_str()).unwrap_or("");
    let iv = v.get("iv").and_then(|x| x.as_str()).unwrap_or("");
    let data = v.get("data").and_then(|x| x.as_str()).unwrap_or("");
    aes_hex(encrypt, mode, key, iv, data).unwrap_or_default()
}

pub fn digest_bridge_json(payload: &str) -> String {
    let Ok(v) = serde_json::from_str::<serde_json::Value>(payload) else {
        return String::new();
    };
    let algo = v.get("algo").and_then(|x| x.as_str()).unwrap_or("SHA256");
    if let Some(hex) = v.get("hex").and_then(|x| x.as_str()) {
        if !hex.is_empty() {
            let Ok(bytes) = bytes_from_hex(hex) else {
                return String::new();
            };
            return digest_hex_bytes(algo, &bytes);
        }
    }
    let data = v.get("data").and_then(|x| x.as_str()).unwrap_or("");
    digest_hex(algo, data)
}

pub fn hmac_bridge_json(payload: &str) -> String {
    let Ok(v) = serde_json::from_str::<serde_json::Value>(payload) else {
        return String::new();
    };
    let algo = v.get("algo").and_then(|x| x.as_str()).unwrap_or("SHA256");
    let key = v.get("key").and_then(|x| x.as_str()).unwrap_or("");
    let data = v.get("data").and_then(|x| x.as_str()).unwrap_or("");
    hmac_hex(algo, key, data)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn utf8_hex_roundtrip() {
        let h = utf8_to_hex("hello");
        assert_eq!(hex_to_utf8(&h), "hello");
    }

    #[test]
    fn aes_cbc_roundtrip() {
        let key = "00112233445566778899aabbccddeeff";
        let iv = "0102030405060708090a0b0c0d0e0f10";
        let pt = utf8_to_hex("hello world!!!!");
        let ct = aes_hex(true, "AES-CBC", key, iv, &pt).unwrap();
        let out = aes_hex(false, "AES-CBC", key, iv, &ct).unwrap();
        assert_eq!(hex_to_utf8(&out), "hello world!!!!");
    }

    #[test]
    fn digest_md5() {
        assert_eq!(digest_hex("MD5", ""), "d41d8cd98f00b204e9800998ecf8427e");
    }
}
