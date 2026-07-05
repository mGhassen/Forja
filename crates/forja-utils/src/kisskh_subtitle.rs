use aes::cipher::{block_padding::Pkcs7, BlockDecryptMut, KeyIvInit};
use base64::{engine::general_purpose::STANDARD, Engine};
use regex::Regex;
use std::sync::LazyLock;

type Aes128CbcDec = cbc::Decryptor<aes::Aes128>;

struct KeyIv {
    key: [u8; 16],
    iv: [u8; 16],
}

const KEY_VARIANTS: [KeyIv; 3] = [
    KeyIv {
        key: *b"AmSmZVcH93UQUezi",
        iv: *b"ReBKWW8cqdjPEnF6",
    },
    KeyIv {
        key: *b"8056483646328763",
        iv: *b"6852612370185273",
    },
    KeyIv {
        key: *b"sWODXX04QRTkHdlZ",
        iv: *b"8pwhapJeC4hrS9hO",
    },
];

static B64_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^[A-Za-z0-9+/=\s]+$").unwrap());

fn try_decrypt(ct: &[u8], kiv: &KeyIv) -> Option<String> {
    let mut buf = ct.to_vec();
    let pt = Aes128CbcDec::new(&kiv.key.into(), &kiv.iv.into())
        .decrypt_padded_mut::<Pkcs7>(&mut buf)
        .ok()?;
    String::from_utf8(pt.to_vec()).ok()
}

fn preferred_for(url: &str) -> Option<usize> {
    let ext = url.split('?').next()?.split('.').next_back()?.to_lowercase();
    match ext.as_str() {
        "srt" => None,
        "txt" => Some(1),
        "txt1" => Some(0),
        _ => Some(2),
    }
}

pub fn decrypt_cue(b64: &str, source_url: Option<&str>) -> Option<String> {
    let trimmed = b64.trim();
    if trimmed.is_empty() || !B64_RE.is_match(trimmed) {
        return None;
    }
    let ct = STANDARD.decode(trimmed.replace('\n', "")).ok()?;
    if ct.is_empty() || !ct.len().is_multiple_of(16) {
        return None;
    }
    let preferred = source_url.and_then(preferred_for);
    if let Some(idx) = preferred {
        if let Some(r) = try_decrypt(&ct, &KEY_VARIANTS[idx]) {
            return Some(r);
        }
    }
    for (i, kiv) in KEY_VARIANTS.iter().enumerate() {
        if Some(i) == preferred {
            continue;
        }
        if let Some(r) = try_decrypt(&ct, kiv) {
            return Some(r);
        }
    }
    None
}

pub fn decrypt_body(body: &str, source_url: Option<&str>) -> String {
    let line_re = Regex::new(r"\r?\n").unwrap();
    let index_re = Regex::new(r"^\d+$").unwrap();
    let mut out = String::new();
    for line in line_re.split(body) {
        let t = line.trim();
        if t.is_empty()
            || t == "WEBVTT"
            || t.starts_with("NOTE")
            || index_re.is_match(t)
            || line.contains("-->")
        {
            out.push_str(line);
            out.push('\n');
            continue;
        }
        let decoded = decrypt_cue(line, source_url);
        out.push_str(decoded.as_deref().unwrap_or(line));
        out.push('\n');
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keeps_plain_header() {
        let body = "WEBVTT\n\n1\n00:00:00.000 --> 00:00:01.000\nHello\n";
        let out = decrypt_body(body, None);
        assert!(out.starts_with("WEBVTT"));
        assert!(out.contains("Hello"));
    }
}
