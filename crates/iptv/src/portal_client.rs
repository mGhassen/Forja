//! Unified IPTV portal request — dispatches by `platform` (xtream | m3u | stalker).

use serde_json::Value;

/// Async entry for engine jobs.
pub async fn request_json_async(request_json: &str) -> String {
    utils::engine_cancel::enter_job();
    let platform = extract_platform(request_json);
    match platform.as_str() {
        "m3u" => crate::m3u_client::request_json_async(request_json).await,
        "stalker" => crate::stalker_client::request_json_async(request_json).await,
        _ => crate::xtream_client::request_json_async(request_json).await,
    }
}

fn extract_platform(request_json: &str) -> String {
    let Ok(v) = serde_json::from_str::<Value>(request_json) else {
        return "xtream".into();
    };
    v.get("platform")
        .and_then(|p| p.as_str())
        .unwrap_or("xtream")
        .to_ascii_lowercase()
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn defaults_xtream() {
        assert_eq!(extract_platform(r#"{"action":"login"}"#), "xtream");
    }

    #[test]
    fn reads_m3u() {
        assert_eq!(
            extract_platform(r#"{"platform":"m3u","action":"login"}"#),
            "m3u"
        );
    }

    #[test]
    fn unknown_platform_still_parses() {
        let out = request_json_async_sync(r#"{"platform":"nope","action":"nope"}"#);
        let v: Value = serde_json::from_str(&out).unwrap();
        // xtream client rejects unknown action
        assert!(v.get("error").is_some());
    }

    fn request_json_async_sync(s: &str) -> String {
        // Sync path for unit test without nesting runtimes awkwardly.
        match tokio::runtime::Runtime::new() {
            Ok(rt) => rt.block_on(request_json_async(s)),
            Err(e) => json!({ "error": e.to_string() }).to_string(),
        }
    }
}
