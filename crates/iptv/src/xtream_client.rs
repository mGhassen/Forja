//! Pattern B Xtream Codes client — fetch + parse + normalize in Rust.

use crate::xtream::{
    absolutize_stream_rows, merge_orphan_categories, parse_categories_rows, parse_section,
    parse_series_episodes_rows, parse_streams_rows, XtreamSection,
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

fn xtream_auth_field(info: &Value, key: &str) -> String {
    info.get(key)
        .map(|v| match v {
            Value::String(s) => s.clone(),
            Value::Number(n) => n.to_string(),
            _ => v.to_string().trim_matches('"').to_string(),
        })
        .unwrap_or_default()
}

/// Xtream login is OK only when auth=1 or status=Active — not merely when user_info exists.
fn xtream_user_auth_ok(info: &Value) -> bool {
    let auth = xtream_auth_field(info, "auth");
    let status = xtream_auth_field(info, "status").to_ascii_lowercase();
    auth == "1" || status == "active"
}

/// Catalog endpoints sometimes return `{"user_info":{"auth":0}}` instead of arrays.
fn reject_xtream_auth_body(body: &str) -> Result<(), String> {
    let Ok(root) = serde_json::from_str::<Value>(body) else {
        return Ok(());
    };
    if root.is_array() {
        return Ok(());
    }
    let Some(info) = root.get("user_info") else {
        return Ok(());
    };
    if xtream_user_auth_ok(info) {
        return Ok(());
    }
    Err("auth_failed".into())
}

async fn login(api: &str, timeout: Duration) -> Result<Value, String> {
    let body = http_get(api, timeout).await?;
    let root: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    let info = root
        .get("user_info")
        .cloned()
        .unwrap_or_else(|| root.clone());
    let server = root.get("server_info").cloned();
    if !xtream_user_auth_ok(&info) {
        // Ok(…) so Dart gets status/message/server_info — not bare `{"error":"auth_failed"}`.
        let status = xtream_auth_field(&info, "status");
        let message = xtream_auth_field(&info, "message");
        let mut out = json!({
            "error": "auth_failed",
            "status": if status.is_empty() { "dead".to_string() } else { status },
            "user_info": info,
        });
        if !message.is_empty() {
            out["message"] = Value::String(message);
        }
        if let Some(s) = server {
            out["server_info"] = s;
        }
        return Ok(out);
    }
    let mut out = json!({ "user_info": info });
    if let Some(s) = server {
        out["server_info"] = s;
    }
    Ok(out)
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
    let cats_body = cats_body?;
    let streams_body = streams_body?;
    reject_xtream_auth_body(&cats_body)?;
    reject_xtream_auth_body(&streams_body)?;
    let cats = parse_categories_rows(&cats_body).map_err(|e| e.to_string())?;
    let streams = parse_streams_rows(&streams_body, section).map_err(|e| e.to_string())?;
    let streams = absolutize_stream_rows(&portal_base_from_api(api), streams);
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
    reject_xtream_auth_body(&body)?;
    let cats = parse_categories_rows(&body).map_err(|e| e.to_string())?;
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
    reject_xtream_auth_body(&body)?;
    let rows = parse_streams_rows(&body, section).map_err(|e| e.to_string())?;
    let rows = absolutize_stream_rows(&portal_base_from_api(api), rows);
    Ok(json!({ "streams": rows }))
}

fn portal_base_from_api(api: &str) -> String {
    if let Some(idx) = api.find("/player_api.php") {
        api[..idx].to_string()
    } else {
        api.trim_end_matches('/').to_string()
    }
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
        .map_err(format_transport_err)?;
    let status = resp.status().as_u16();
    if !(200..300).contains(&status) {
        return Err(format!("HTTP {status}"));
    }
    resp.text().await.map_err(format_transport_err)
}

/// User-facing transport errors — never echo the request URL (credentials in query).
fn format_transport_err(err: reqwest::Error) -> String {
    map_transport_message(&err.to_string(), err.is_timeout() || err.is_connect())
}

fn map_transport_message(raw: &str, force_unreachable: bool) -> String {
    const MSG: &str = "Could not reach portal — check URL or network";
    if force_unreachable {
        return MSG.into();
    }
    let lower = raw.to_ascii_lowercase();
    if lower.contains("error sending request")
        || lower.contains("timed out")
        || lower.contains("timeout")
        || lower.contains("connection")
        || lower.contains("dns")
        || lower.contains("name or service not known")
        || lower.contains("nodename nor servname")
        || lower.contains("network is unreachable")
        || lower.contains("certificate")
        || lower.contains("tls")
        || lower.contains("ssl")
        || raw.contains("://")
        || lower.contains("player_api")
    {
        return MSG.into();
    }
    raw.to_string()
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

    #[test]
    fn transport_mapper_hides_credential_urls() {
        let raw = "error sending request for url (http://x/player_api.php?username=a&password=b): dns error";
        let msg = map_transport_message(raw, false);
        assert_eq!(msg, "Could not reach portal — check URL or network");
        assert!(!msg.contains("password"));
        assert!(!msg.contains("://"));
    }

    #[test]
    fn transport_mapper_keeps_plain_errors() {
        assert_eq!(map_transport_message("invalid_section", false), "invalid_section");
    }

    #[test]
    fn auth_zero_user_info_is_not_ok() {
        let info: Value = json!({ "auth": 0 });
        assert!(!xtream_user_auth_ok(&info));
    }

    #[test]
    fn auth_one_user_info_is_ok() {
        let info: Value = json!({ "auth": 1 });
        assert!(xtream_user_auth_ok(&info));
    }

    #[test]
    fn active_status_is_ok_without_auth_one() {
        let info: Value = json!({ "auth": 0, "status": "Active" });
        assert!(xtream_user_auth_ok(&info));
    }

    #[test]
    fn reject_auth_object_from_catalog_body() {
        assert_eq!(
            reject_xtream_auth_body(r#"{"user_info":{"auth":0}}"#),
            Err("auth_failed".into())
        );
        assert!(reject_xtream_auth_body("[]").is_ok());
    }

    #[test]
    fn banned_status_is_not_ok() {
        let info: Value = json!({ "auth": 0, "status": "Banned" });
        assert!(!xtream_user_auth_ok(&info));
    }

    #[test]
    fn expired_status_is_not_ok() {
        let info: Value = json!({ "auth": 0, "status": "Expired" });
        assert!(!xtream_user_auth_ok(&info));
    }
}
