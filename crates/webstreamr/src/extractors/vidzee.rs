use crate::fetcher::{fetch_json, fetch_text, FetchConfig};
use crate::types::{ExtractResult, StreamFormat};
use aes::Aes256;
use aes_gcm::{aead::Aead, Aes256Gcm, KeyInit, Nonce};
use cbc::cipher::{block_padding::Pkcs7, BlockDecryptMut, KeyIvInit};
use serde::Deserialize;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::Mutex;
use url::Url;

type Aes256CbcDec = cbc::Decryptor<Aes256>;

const API_KEY_URL: &str = "https://core.vidzee.wtf/api-key";
const SERVER_API_URL: &str = "https://player.vidzee.wtf/api/server";
const ENCRYPTION_KEY_SECRET: &str = "4f2a9c7d1e8b3a6f0d5c2e9a7b1f4d8c";
const REFERER: &str = "https://player.vidzee.wtf/";

static API_KEY_CACHE: Mutex<Option<String>> = Mutex::new(None);

#[derive(Debug, Deserialize)]
struct ServerResponse {
    headers: Option<HashMap<String, String>>,
    url: Option<Vec<ServerStream>>,
    error: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ServerStream {
    lang: Option<String>,
    link: String,
    #[serde(rename = "type")]
    stream_type: Option<String>,
    name: Option<String>,
    flag: Option<String>,
}

pub fn supports_host(host: &str) -> bool {
    host == "player.vidzee.wtf" || host.ends_with(".vidzee.wtf")
}

pub fn extract_from_embed_url(page_url: &str) -> Vec<ExtractResult> {
    let Ok(parsed) = Url::parse(page_url) else {
        return Vec::new();
    };
    let Some((tmdb_id, season, episode, server_id)) = parse_embed(&parsed) else {
        return Vec::new();
    };
    let Some(api_key) = get_api_key() else {
        return Vec::new();
    };

    let mut api = Url::parse(SERVER_API_URL).unwrap();
    {
        let mut q = api.query_pairs_mut();
        q.append_pair("id", &tmdb_id);
        q.append_pair("sr", &server_id);
        if let Some(ss) = season.as_deref() {
            q.append_pair("ss", ss);
            q.append_pair("ep", episode.as_deref().unwrap_or("1"));
        }
    }

    let Ok(value) = fetch_json(api.as_str(), &FetchConfig::default()) else {
        return Vec::new();
    };
    let Ok(resp) = serde_json::from_value::<ServerResponse>(value) else {
        return Vec::new();
    };
    if resp.error.is_some() {
        return Vec::new();
    }
    let Some(streams) = resp.url else {
        return Vec::new();
    };

    let ua = resp
        .headers
        .as_ref()
        .and_then(|h| h.get("User-Agent").cloned());

    let mut out = Vec::new();
    for stream in streams {
        let decrypted = decrypt_server_url(&stream.link, &api_key);
        if decrypted.is_empty() {
            continue;
        }
        let is_hls = stream
            .stream_type
            .as_deref()
            .map(|t| t == "hls")
            .unwrap_or(false)
            || decrypted.contains(".m3u8");
        let format = if is_hls {
            StreamFormat::Hls
        } else {
            StreamFormat::Mp4
        };
        let name = stream.name.unwrap_or_else(|| "VidZee".into());
        let flag = stream.flag.unwrap_or_default();
        let lang = stream.lang.unwrap_or_default();
        let mut headers = HashMap::from([("Referer".into(), REFERER.into())]);
        if let Some(ua) = ua.clone() {
            headers.insert("User-Agent".into(), ua);
        }
        out.push(ExtractResult {
            url: decrypted,
            format,
            title: Some(format!("{name} - {lang}")),
            height: None,
            yt_id: None,
            next_url: None,
            is_external: false,
            request_headers: Some(headers),
            label: Some(format!("{name} ({flag}) - {lang}")),
            bytes: None,
            meta_extractor_id: Some("vidzee".into()),
        });
    }
    out
}

fn parse_embed(url: &Url) -> Option<(String, Option<String>, Option<String>, String)> {
    let parts: Vec<&str> = url.path_segments().map(|s| s.collect()).unwrap_or_default();
    let server_id = url
        .query_pairs()
        .find(|(k, _)| k == "sr")
        .map(|(_, v)| v.into_owned())
        .unwrap_or_else(|| "4".into());

    let mut tmdb_id = None;
    let mut season = None;
    let mut episode = None;
    if let Some(i) = parts.iter().position(|p| *p == "movie") {
        tmdb_id = parts.get(i + 1).map(|s| (*s).to_string());
    } else if let Some(i) = parts.iter().position(|p| *p == "tv") {
        tmdb_id = parts.get(i + 1).map(|s| (*s).to_string());
        season = parts.get(i + 2).map(|s| (*s).to_string());
        episode = parts.get(i + 3).map(|s| (*s).to_string());
    }
    Some((tmdb_id?, season, episode, server_id))
}

fn get_api_key() -> Option<String> {
    if let Ok(guard) = API_KEY_CACHE.lock() {
        if let Some(k) = guard.as_ref() {
            return Some(k.clone());
        }
    }
    let encrypted = fetch_text(API_KEY_URL, &FetchConfig::default()).ok()?;
    let key = decrypt_api_key(encrypted.trim()).ok()?;
    if let Ok(mut guard) = API_KEY_CACHE.lock() {
        *guard = Some(key.clone());
    }
    Some(key)
}

fn decrypt_api_key(encrypted_b64: &str) -> Result<String, String> {
    use base64::Engine;
    let encrypted = base64::engine::general_purpose::STANDARD
        .decode(encrypted_b64)
        .map_err(|e| e.to_string())?;
    if encrypted.len() <= 28 {
        return Err("api key too short".into());
    }
    let iv = &encrypted[0..12];
    let auth_tag = &encrypted[12..28];
    let ciphertext = &encrypted[28..];
    let mut cipher_and_tag = ciphertext.to_vec();
    cipher_and_tag.extend_from_slice(auth_tag);

    let derived = Sha256::digest(ENCRYPTION_KEY_SECRET.as_bytes());
    let cipher = Aes256Gcm::new_from_slice(&derived).map_err(|e| e.to_string())?;
    let nonce = Nonce::from_slice(iv);
    let plain = cipher
        .decrypt(nonce, cipher_and_tag.as_ref())
        .map_err(|e| e.to_string())?;
    String::from_utf8(plain).map_err(|e| e.to_string())
}

fn decrypt_server_url(encrypted_link: &str, api_key: &str) -> String {
    use base64::Engine;
    let Ok(decoded) = base64::engine::general_purpose::STANDARD.decode(encrypted_link) else {
        return String::new();
    };
    let Ok(decoded_str) = String::from_utf8(decoded) else {
        return String::new();
    };
    let Some(colon) = decoded_str.find(':') else {
        return String::new();
    };
    let iv_b64 = &decoded_str[..colon];
    let ct_b64 = &decoded_str[colon + 1..];
    if iv_b64.is_empty() || ct_b64.is_empty() {
        return String::new();
    }
    let Ok(iv) = base64::engine::general_purpose::STANDARD.decode(iv_b64) else {
        return String::new();
    };
    let Ok(ciphertext) = base64::engine::general_purpose::STANDARD.decode(ct_b64) else {
        return String::new();
    };
    let mut key = [0u8; 32];
    let kb = api_key.as_bytes();
    let n = kb.len().min(32);
    key[..n].copy_from_slice(&kb[..n]);

    let Ok(dec) = Aes256CbcDec::new_from_slices(&key, &iv) else {
        return String::new();
    };
    let mut buf = ciphertext;
    let Ok(plain) = dec.decrypt_padded_mut::<Pkcs7>(&mut buf) else {
        return String::new();
    };
    String::from_utf8_lossy(plain).into_owned()
}
