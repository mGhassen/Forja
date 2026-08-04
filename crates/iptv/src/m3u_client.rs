//! M3U / M3U8 playlist catalog fetch — HTTP GET + parse → Xtream-shaped rows.

use crate::m3u::{self, M3uChannel};
use crate::xtream::{merge_orphan_categories, ParsedCategory, XtreamStreamRow};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::time::Duration;

const DEFAULT_UA: &str = "VLC/3.0.20 LibVLC/3.0.20";

#[derive(Debug, Deserialize)]
struct M3uRequest {
    action: String,
    #[serde(default)]
    url: String,
    #[serde(default)]
    user_agent: String,
    #[serde(default)]
    timeout_secs: u64,
}

pub fn request_json(request_json: &str) -> String {
    utils::engine_cancel::enter_job();
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        return handle.block_on(request_json_async(request_json));
    }
    match tokio::runtime::Runtime::new() {
        Ok(rt) => rt.block_on(request_json_async(request_json)),
        Err(e) => json!({ "error": e.to_string() }).to_string(),
    }
}

pub async fn request_json_async(request_json: &str) -> String {
    utils::engine_cancel::enter_job();
    match handle(request_json).await {
        Ok(v) => v.to_string(),
        Err(e) => json!({ "error": e }).to_string(),
    }
}

async fn handle(request_json: &str) -> Result<Value, String> {
    let req: M3uRequest =
        serde_json::from_str(request_json).map_err(|e| format!("invalid request: {e}"))?;
    let timeout = Duration::from_secs(if req.timeout_secs == 0 {
        30
    } else {
        req.timeout_secs.clamp(1, 180)
    });
    match req.action.as_str() {
        "login" => login(&req.url, &req.user_agent, timeout).await,
        "catalog" | "categories" | "streams" => {
            catalog(&req.url, &req.user_agent, timeout).await
        }
        other => Err(format!("unknown action: {other}")),
    }
}

async fn login(url: &str, ua: &str, timeout: Duration) -> Result<Value, String> {
    let channels = fetch_channels(url, ua, timeout).await?;
    if channels.is_empty() {
        return Err("no_channels".into());
    }
    Ok(json!({
        "user_info": {
            "username": "M3U",
            "auth": "1",
            "status": "Active",
            "exp_date": "",
            "max_connections": "1",
            "active_cons": "0",
            "channel_count": channels.len(),
        }
    }))
}

async fn catalog(url: &str, ua: &str, timeout: Duration) -> Result<Value, String> {
    let channels = fetch_channels(url, ua, timeout).await?;
    let (cats, streams) = channels_to_catalog(&channels);
    Ok(json!({
        "categories": cats,
        "streams": streams,
    }))
}

async fn fetch_channels(
    url: &str,
    ua: &str,
    timeout: Duration,
) -> Result<Vec<M3uChannel>, String> {
    let raw = url.trim();
    if raw.is_empty() {
        return Err("empty url".into());
    }
    if utils::engine_cancel::is_requested() {
        return Err(utils::engine_cancel::cancelled_message().into());
    }
    let agent = if ua.trim().is_empty() {
        DEFAULT_UA
    } else {
        ua.trim()
    };
    let client = reqwest::Client::builder()
        .timeout(timeout)
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .map_err(|e| e.to_string())?;
    let resp = client
        .get(raw)
        .header("User-Agent", agent)
        .header("Accept", "*/*")
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = resp.status().as_u16();
    if !(200..300).contains(&status) {
        return Err(format!("HTTP {status}"));
    }
    let body = resp.text().await.map_err(|e| e.to_string())?;
    m3u::parse(&body).map_err(|e| e.to_string())
}

fn channels_to_catalog(channels: &[M3uChannel]) -> (Vec<ParsedCategory>, Vec<XtreamStreamRow>) {
    let mut group_order: BTreeMap<String, String> = BTreeMap::new();
    let mut streams = Vec::with_capacity(channels.len());
    for (i, ch) in channels.iter().enumerate() {
        let group = if ch.group.trim().is_empty() {
            "Uncategorized".to_string()
        } else {
            ch.group.trim().to_string()
        };
        let cat_id = format!("g:{}", group.to_ascii_lowercase());
        group_order.entry(cat_id.clone()).or_insert(group);
        streams.push(XtreamStreamRow {
            // Encode playable URL as stream_id for M3U (no path build on host).
            stream_id: ch.url.clone(),
            name: if ch.name.is_empty() {
                format!("Channel {}", i + 1)
            } else {
                ch.name.clone()
            },
            icon: ch.logo.clone(),
            category_id: cat_id,
            container_ext: "ts".into(),
            epg_channel_id: ch.tvg_id.clone(),
            kind: "live".into(),
        });
    }
    let cats: Vec<ParsedCategory> = group_order
        .into_iter()
        .map(|(id, name)| ParsedCategory { id, name })
        .collect();
    let cats = merge_orphan_categories(cats, &streams);
    (cats, streams)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalog_from_channels() {
        let channels = vec![
            M3uChannel {
                name: "A".into(),
                url: "http://x/a".into(),
                logo: String::new(),
                group: "News".into(),
                tvg_id: String::new(),
                tvg_name: String::new(),
            },
            M3uChannel {
                name: "B".into(),
                url: "http://x/b".into(),
                logo: String::new(),
                group: "News".into(),
                tvg_id: String::new(),
                tvg_name: String::new(),
            },
        ];
        let (cats, streams) = channels_to_catalog(&channels);
        assert_eq!(cats.len(), 1);
        assert_eq!(streams.len(), 2);
        assert_eq!(streams[0].stream_id, "http://x/a");
    }
}
