//! Pattern B Xtream Codes client — fetch + parse + normalize in Rust.

use crate::xtream::{
    merge_orphan_categories, parse_categories_rows, parse_section, parse_series_episodes_rows,
    parse_streams_rows, XtreamSection,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::time::Duration;

const UA: &str = "VLC/3.0.20 LibVLC/3.0.20";

#[derive(Debug, Deserialize)]
struct XtreamRequest {
    action: String,
    #[serde(default)]
    url: String,
    #[serde(default)]
    username: String,
    #[serde(default)]
    password: String,
    #[serde(default)]
    section: String,
    #[serde(default)]
    category_id: String,
    #[serde(default)]
    series_id: String,
    #[serde(default)]
    timeout_secs: u64,
    /// Host-side staged load: categories already fetched (for `merge`).
    #[serde(default)]
    categories: Vec<crate::xtream::ParsedCategory>,
    /// Host-side staged load: streams already fetched (for `merge`).
    #[serde(default)]
    streams: Vec<crate::xtream::XtreamStreamRow>,
}

/// Sync entry for tests / blocking callers.
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

/// Async entry for engine jobs (preferred — no nested runtime).
pub async fn request_json_async(request_json: &str) -> String {
    utils::engine_cancel::enter_job();
    match handle(request_json).await {
        Ok(v) => v.to_string(),
        Err(e) => json!({ "error": e }).to_string(),
    }
}

async fn handle(request_json: &str) -> Result<Value, String> {
    let req: XtreamRequest =
        serde_json::from_str(request_json).map_err(|e| format!("invalid request: {e}"))?;

    if req.action == "merge" {
        let cats = merge_orphan_categories(req.categories, &req.streams);
        return Ok(json!({
            "categories": cats,
            "streams": req.streams,
        }));
    }

    let base = req.url.trim_end_matches('/').to_string();
    if base.is_empty() {
        return Err("empty url".into());
    }
    let timeout = Duration::from_secs(if req.timeout_secs == 0 {
        15
    } else {
        req.timeout_secs.clamp(1, 180)
    });
    let user = urlencoding::encode(&req.username);
    let pass = urlencoding::encode(&req.password);
    let api = format!("{base}/player_api.php?username={user}&password={pass}");

    match req.action.as_str() {
        "login" => login(&api, timeout).await,
        "catalog" => catalog(&api, &req.section, timeout).await,
        "categories" => categories_only(&api, &req.section, timeout).await,
        "streams" => streams(&api, &req.section, &req.category_id, timeout).await,
        "series_episodes" => series_episodes(&api, &req.series_id, timeout).await,
        other => Err(format!("unknown action: {other}")),
    }
}

async fn login(api: &str, timeout: Duration) -> Result<Value, String> {
    let body = http_get(api, timeout).await?;
    let root: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    let info = root
        .get("user_info")
        .cloned()
        .unwrap_or_else(|| root.clone());
    let auth = info
        .get("auth")
        .map(|v| match v {
            Value::String(s) => s.clone(),
            Value::Number(n) => n.to_string(),
            _ => v.to_string().trim_matches('"').to_string(),
        })
        .unwrap_or_default();
    let status = info
        .get("status")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_ascii_lowercase();
    let ok = auth == "1" || status == "active" || root.get("user_info").is_some();
    if !ok {
        return Err("auth_failed".into());
    }
    Ok(json!({ "user_info": info }))
}

async fn catalog(api: &str, section: &str, timeout: Duration) -> Result<Value, String> {
    let section = parse_section(section).ok_or_else(|| "invalid_section".to_string())?;
    let (cat_action, stream_action) = match section {
        XtreamSection::Live => ("get_live_categories", "get_live_streams"),
        XtreamSection::Vod => ("get_vod_categories", "get_vod_streams"),
        XtreamSection::Series => ("get_series_categories", "get_series"),
    };
    let cats_url = format!("{api}&action={cat_action}");
    let streams_url = format!("{api}&action={stream_action}");
    let (cats_body, streams_body) = tokio::join!(
        http_get(&cats_url, timeout),
        http_get(&streams_url, timeout),
    );
    let cats = parse_categories_rows(&cats_body?).unwrap_or_default();
    let streams = parse_streams_rows(&streams_body?, section).unwrap_or_default();
    let cats = merge_orphan_categories(cats, &streams);
    Ok(json!({
        "categories": cats,
        "streams": streams,
    }))
}

async fn categories_only(api: &str, section: &str, timeout: Duration) -> Result<Value, String> {
    let section = parse_section(section).ok_or_else(|| "invalid_section".to_string())?;
    let cat_action = match section {
        XtreamSection::Live => "get_live_categories",
        XtreamSection::Vod => "get_vod_categories",
        XtreamSection::Series => "get_series_categories",
    };
    let body = http_get(&format!("{api}&action={cat_action}"), timeout).await?;
    let cats = parse_categories_rows(&body).unwrap_or_default();
    Ok(json!({ "categories": cats }))
}

async fn streams(
    api: &str,
    section: &str,
    category_id: &str,
    timeout: Duration,
) -> Result<Value, String> {
    let section = parse_section(section).ok_or_else(|| "invalid_section".to_string())?;
    let action = match section {
        XtreamSection::Live => "get_live_streams",
        XtreamSection::Vod => "get_vod_streams",
        XtreamSection::Series => "get_series",
    };
    let mut url = format!("{api}&action={action}");
    if !category_id.is_empty() {
        url.push_str("&category_id=");
        url.push_str(&urlencoding::encode(category_id));
    }
    let body = http_get(&url, timeout).await?;
    let rows = parse_streams_rows(&body, section).unwrap_or_default();
    Ok(json!({ "streams": rows }))
}

async fn series_episodes(api: &str, series_id: &str, timeout: Duration) -> Result<Value, String> {
    if series_id.is_empty() {
        return Ok(json!({ "episodes": [] }));
    }
    let url = format!(
        "{api}&action=get_series_info&series_id={}",
        urlencoding::encode(series_id)
    );
    let body = http_get(&url, timeout).await?;
    let rows = parse_series_episodes_rows(&body).unwrap_or_default();
    Ok(json!({ "episodes": rows }))
}

async fn http_get(url: &str, timeout: Duration) -> Result<String, String> {
    if utils::engine_cancel::is_requested() {
        return Err(utils::engine_cancel::cancelled_message().into());
    }
    let client = reqwest::Client::builder()
        .timeout(timeout)
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .map_err(|e| e.to_string())?;
    let resp = client
        .get(url)
        .header("User-Agent", UA)
        .header("Accept", "application/json,*/*")
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = resp.status().as_u16();
    if !(200..300).contains(&status) {
        return Err(format!("HTTP {status}"));
    }
    resp.text().await.map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::xtream::XtreamStreamRow;

    #[test]
    fn merge_orphans_empty_cats() {
        let streams = vec![XtreamStreamRow {
            stream_id: "1".into(),
            name: "A".into(),
            icon: String::new(),
            category_id: "110".into(),
            container_ext: "ts".into(),
            epg_channel_id: String::new(),
            kind: "live".into(),
        }];
        let cats = merge_orphan_categories(vec![], &streams);
        assert_eq!(cats.len(), 1);
        assert_eq!(cats[0].id, "110");
        assert_eq!(cats[0].name, "Channels");
    }

    #[test]
    fn reject_bad_action() {
        let out = request_json(
            r#"{"action":"nope","url":"http://x","username":"a","password":"b"}"#,
        );
        let v: Value = serde_json::from_str(&out).unwrap();
        assert!(v.get("error").is_some());
    }
}
