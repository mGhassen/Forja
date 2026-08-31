use base64::Engine;
use serde::Serialize;
use serde_json::{json, Value};

use crate::fetch;

const FIREBASE_KEY: &str = "AIzaSyAq9_a8hU7sNkwUBJFmSlbmhepbu8bRgqw";
const BASE_URL: &str = "https://www.paper2audio.com";

#[derive(Debug, Serialize)]
pub struct P2aUploadResponse {
    pub run_id: String,
}

#[derive(Debug, Serialize)]
pub struct P2aStatusResponse {
    pub status: String,
    pub progress: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub download_url: Option<String>,
}

pub fn auth_token() -> Result<String, String> {
    let email = format!("{}@mailinator.com", pseudo_uuid());
    let body = json!({
        "email": email,
        "password": "TestPassword123!",
        "returnSecureToken": true,
    })
    .to_string();
    let mut headers = std::collections::HashMap::new();
    headers.insert("Content-Type".to_string(), "application/json".to_string());
    let url = format!(
        "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={FIREBASE_KEY}"
    );
    let (status, body) = fetch::post(&url, &headers, &body, 30)?;
    if status >= 400 {
        return Err(format!("auth failed: {} {}", status, body));
    }
    let data: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    data.get("idToken")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .ok_or_else(|| "auth: missing idToken".into())
}

pub fn upload(file_name: &str, voice_id: &str, epub_bytes: &[u8]) -> Result<P2aUploadResponse, String> {
    let token = auth_token()?;
    let query = format!(
        "fileName={}&link=&client=web&summarizationMethod=ultimate&context=&sendEmailToUser=false&appendix=false&primaryVoice={}&secondaryVoice=am_echo&tertiaryVoice=af_alloy",
        urlencoding::encode(file_name),
        urlencoding::encode(voice_id)
    );
    let upload_url = format!("{BASE_URL}/v2/summarize?{query}");
    let mut headers = std::collections::HashMap::new();
    headers.insert("Authorization".to_string(), format!("Bearer {token}"));
    headers.insert(
        "Content-Type".to_string(),
        "application/epub+zip".to_string(),
    );
    let resp = host_http::fetch_with_retries(
        "POST",
        &upload_url,
        &headers,
        None,
        Some(epub_bytes),
        false,
        120,
        0,
    )?;
    let status = resp.status;
    let body = resp.body;
    if status >= 400 {
        return Err(format!("upload failed: {} {}", status, body));
    }
    let data: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    let run_id = data
        .get("runId")
        .and_then(|v| v.as_str())
        .ok_or_else(|| "upload: missing runId".to_string())?
        .to_string();
    Ok(P2aUploadResponse { run_id })
}

pub fn upload_base64(file_name: &str, voice_id: &str, epub_base64: &str) -> Result<P2aUploadResponse, String> {
    if epub_base64.trim().is_empty() {
        return Err("epub_base64 required".into());
    }
    let bytes = base64::engine::general_purpose::STANDARD
        .decode(epub_base64)
        .map_err(|e| format!("invalid epub_base64: {e}"))?;
    upload(file_name, voice_id, &bytes)
}

pub fn check_status(run_id: &str) -> Result<P2aStatusResponse, String> {
    let payload = json!({ "runIds": [run_id] }).to_string();
    let mut headers = std::collections::HashMap::new();
    headers.insert("Content-Type".to_string(), "application/json".to_string());
    let (status, body) = fetch::post(
        &format!("{BASE_URL}/batchCheckStatus"),
        &headers,
        &payload,
        30,
    )?;
    if status >= 400 {
        return Err(format!("status failed: {}", status));
    }
    let data: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    let entry = data.get(run_id).ok_or_else(|| "status: missing run entry".to_string())?;
    let status = entry
        .get("status")
        .and_then(|v| v.as_str())
        .unwrap_or("pending")
        .to_string();
    let progress = normalize_progress(entry.get("progress"));
    let download_url = entry
        .get("fullAudioFileUrl")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string());
    Ok(P2aStatusResponse {
        status,
        progress,
        download_url,
    })
}

fn normalize_progress(value: Option<&Value>) -> f64 {
    let Some(value) = value else {
        return 0.0;
    };
    let pv = match value {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.parse().ok(),
        _ => None,
    };
    let Some(pv) = pv else {
        return 0.0;
    };
    if pv > 1.0 {
        pv / 100.0
    } else {
        pv
    }
}

fn pseudo_uuid() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let micros = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_micros())
        .unwrap_or(0) as u64;
    let rnd = (micros ^ (micros >> 16)) as u32;
    let tail = micros.wrapping_mul(1_664_525).wrapping_add(1_013_904_223) as u32;
    let rnd_hex = format!("{rnd:08x}");
    let tail_hex = format!("{tail:08x}");
    format!(
        "{rnd_hex}-{}-4{}-a{}-{tail_hex}{rnd_hex}",
        &tail_hex[0..4],
        &tail_hex[4..7],
        &rnd_hex[0..3],
    )
    .chars()
    .take(36)
    .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_percent_progress() {
        assert!((normalize_progress(Some(&json!(55))) - 0.55).abs() < f64::EPSILON);
        assert!((normalize_progress(Some(&json!(0.4))) - 0.4).abs() < f64::EPSILON);
    }
}
