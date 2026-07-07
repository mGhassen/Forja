use std::collections::HashMap;

use serde::Serialize;
use utils::kisskh_subtitle;

use crate::http;

#[derive(Debug, Serialize)]
pub struct KisskhFetchResult {
    pub text: String,
    pub is_vtt: bool,
}

pub fn fetch_and_decrypt(url: &str, user_agent: &str, referer: &str) -> Result<KisskhFetchResult, String> {
    if url.trim().is_empty() {
        return Err("url required".into());
    }
    let mut headers = HashMap::new();
    headers.insert("User-Agent".to_string(), user_agent.to_string());
    headers.insert("Referer".to_string(), referer.to_string());
    headers.insert("Accept".to_string(), "*/*".to_string());

    let resp = http::fetch_with_retries("GET", url, &headers, None, None, false, 15, 0)?;
    if resp.status != 200 {
        return Err(format!("HTTP {}", resp.status));
    }

    let ext = url
        .split('?')
        .next()
        .and_then(|u| u.rsplit('.').next())
        .unwrap_or("")
        .to_lowercase();
    let text = if ext == "srt" {
        resp.body
    } else {
        kisskh_subtitle::decrypt_body(&resp.body, Some(url))
    };
    let is_vtt = url.to_lowercase().contains(".vtt") || text.trim_start().starts_with("WEBVTT");

    Ok(KisskhFetchResult { text, is_vtt })
}
