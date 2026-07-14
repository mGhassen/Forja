//! Port of webstreamr `hd-hub-helper.ts` / PlayTorrio `hd_hub_helper.dart`.
//!
//! Gadgetsweb / hub redirect pages embed `'o','<payload>'` where decoding
//! (base64 ×2 → ROT13 → base64 → JSON `{"o":"<b64 url>"}` → base64) yields
//! the real HubDrive / HubCloud URL.

use base64::{engine::general_purpose::STANDARD, Engine as _};
use regex::Regex;
use std::sync::LazyLock;

use crate::fetcher::{fetch_text, FetchConfig};

static O_PAYLOAD_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"'o'\s*,\s*'(.*?)'").unwrap());

fn atob(s: &str) -> Result<String, String> {
    let norm = s.replace('-', "+").replace('_', "/");
    let pad = (4 - norm.len() % 4) % 4;
    let padded = format!("{norm}{}", "=".repeat(pad));
    let bytes = STANDARD
        .decode(padded.as_bytes())
        .map_err(|e| e.to_string())?;
    String::from_utf8(bytes).map_err(|e| e.to_string())
}

fn rot13(s: &str) -> String {
    s.chars()
        .map(|c| match c {
            'A'..='Z' => ((c as u8 - b'A' + 13) % 26 + b'A') as char,
            'a'..='z' => ((c as u8 - b'a' + 13) % 26 + b'a') as char,
            _ => c,
        })
        .collect()
}

/// Decode the gadgetsweb / hub-redirect HTML payload to the real target URL.
pub fn decode_redirect_html(html: &str) -> Result<String, String> {
    let caps = O_PAYLOAD_RE
        .captures(html)
        .ok_or_else(|| "hd-hub redirect payload not found".to_string())?;
    let payload = caps.get(1).map(|m| m.as_str()).unwrap_or("");
    let inner = atob(&rot13(&atob(&atob(payload)?)?))?;
    let data: serde_json::Value =
        serde_json::from_str(&inner).map_err(|e| e.to_string())?;
    let o = data
        .get("o")
        .and_then(|v| v.as_str())
        .ok_or_else(|| "hd-hub redirect missing o".to_string())?;
    atob(o)
}

/// Fetch a gadgetsweb-style redirect URL and return the final HubDrive/HubCloud URL.
pub fn resolve_redirect_url(redirect_url: &str, referer: Option<&str>) -> Result<String, String> {
    let mut cfg = FetchConfig::default();
    if let Some(r) = referer {
        cfg.headers.insert("Referer".into(), r.to_string());
    }
    let html = fetch_text(redirect_url, &cfg)?;
    decode_redirect_html(&html)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decode_redirect_payload() {
        // Construct: final_url → b64 → wrap in {"o":…} → b64 → rot13 → b64 → b64
        let final_url = "https://hubdrive.example/file/abc";
        let o = STANDARD.encode(final_url.as_bytes());
        let json = format!(r#"{{"o":"{o}"}}"#);
        let step1 = STANDARD.encode(json.as_bytes());
        // Apply inverse of rot13 to simulate the stored form after atob(atob)
        let before_rot = step1.clone();
        let after_rot = rot13(&before_rot); // encode path: we rot13 before outer b64
        // PlayTorrio decode: atob(rot13(atob(atob(payload))))
        // So encode: payload = b64(b64(rot13(b64(json))))
        let mid = STANDARD.encode(after_rot.as_bytes());
        let payload = STANDARD.encode(mid.as_bytes());
        let html = format!("var x = ['o','{payload}'];");
        let got = decode_redirect_html(&html).expect("decode");
        assert_eq!(got, final_url);
    }
}
