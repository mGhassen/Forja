//! Chrome TLS-impersonated HTTP for hosts that JA3-block plain reqwest (e.g. Dailymotion CDN).

use std::collections::HashMap;
use std::time::Duration;

use serde_json::{json, Value};
use wreq::Client;
use wreq_util::Emulation;

use utils::engine_cancel::cancellation_token;

fn fetch_error(url: &str, msg: impl ToString) -> String {
    json!({
        "ok": false,
        "status": 0,
        "statusText": msg.to_string(),
        "url": url,
        "body": "",
        "headers": {}
    })
    .to_string()
}

fn cancelled_json(url: &str) -> String {
    json!({
        "ok": false,
        "status": 0,
        "statusText": "cancelled",
        "url": url,
        "body": "",
        "headers": {}
    })
    .to_string()
}

/// Same JSON envelope as [`super::extract`]'s `__native_fetch`, but with Chrome TLS/HTTP2 fingerprint.
pub async fn chrome_fetch(
    url: String,
    method: String,
    headers_json: String,
    body: String,
) -> String {
    if cancellation_token().is_cancelled() {
        return cancelled_json(&url);
    }
    let headers: HashMap<String, String> =
        serde_json::from_str(&headers_json).unwrap_or_default();
    let client = match Client::builder()
        .emulation(Emulation::Chrome137)
        .timeout(Duration::from_secs(25))
        .redirect(wreq::redirect::Policy::limited(8))
        .build()
    {
        Ok(c) => c,
        Err(e) => return fetch_error(&url, e),
    };

    let mut req = match method.to_uppercase().as_str() {
        "POST" => client.post(&url),
        "PUT" => client.put(&url),
        "PATCH" => client.patch(&url),
        "DELETE" => client.delete(&url),
        _ => client.get(&url),
    };
    for (k, v) in &headers {
        req = req.header(k.as_str(), v.as_str());
    }
    if !body.is_empty() && method.to_uppercase() != "GET" {
        req = req.body(body);
    }

    let token = cancellation_token();
    let resp = tokio::select! {
        r = req.send() => match r {
            Ok(r) => r,
            Err(e) => return fetch_error(&url, e),
        },
        _ = token.cancelled() => return cancelled_json(&url),
    };

    let status = resp.status().as_u16();
    let final_url = resp.uri().to_string();
    let mut hdrs = serde_json::Map::new();
    for (k, v) in resp.headers().iter() {
        if let Ok(s) = v.to_str() {
            hdrs.insert(k.to_string(), Value::String(s.to_string()));
        }
    }
    let text = tokio::select! {
        t = resp.text() => match t {
            Ok(t) => t,
            Err(e) => return fetch_error(&url, e),
        },
        _ = token.cancelled() => return cancelled_json(&url),
    };
    json!({
        "ok": (200..300).contains(&status),
        "status": status,
        "statusText": "",
        "url": final_url,
        "body": text,
        "headers": hdrs
    })
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn chrome_fetch_dailymotion_master_ok() {
        let meta = chrome_fetch(
            "https://www.dailymotion.com/player/metadata/video/xb1gvle?app=com.dailymotion.neon"
                .into(),
            "GET".into(),
            r#"{"Referer":"https://www.dailymotion.com/","User-Agent":"Mozilla/5.0"}"#.into(),
            String::new(),
        )
        .await;
        let meta: Value = serde_json::from_str(&meta).unwrap();
        assert!(meta["ok"].as_bool().unwrap_or(false), "{meta}");
        let master = meta["body"]
            .as_str()
            .and_then(|b| serde_json::from_str::<Value>(b).ok())
            .and_then(|m| {
                m["qualities"]["auto"][0]["url"]
                    .as_str()
                    .map(|s| s.to_string())
            })
            .expect("master url");
        assert!(
            master.contains("cdndirector") || master.contains("m3u8"),
            "{master}"
        );
        let playlist = chrome_fetch(
            master,
            "GET".into(),
            r#"{"Referer":"https://www.dailymotion.com/"}"#.into(),
            String::new(),
        )
        .await;
        let playlist: Value = serde_json::from_str(&playlist).unwrap();
        assert!(playlist["ok"].as_bool().unwrap_or(false), "{playlist}");
        let body = playlist["body"].as_str().unwrap_or("");
        assert!(body.contains("#EXTM3U"), "{body}");
        assert!(body.contains("dmcdn.net") || body.contains(".m3u8"), "{body}");
    }
}
