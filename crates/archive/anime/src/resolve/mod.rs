pub(crate) mod anikoto;
pub(crate) mod anikoto_site;
pub(crate) mod direct_embed;
pub(crate) mod probe;

use serde::Deserialize;
use serde_json::json;

pub use anikoto_site::anikoto_site_streams;
pub use direct_embed::direct_embed_extract;
pub use probe::probe_stream_url;

#[derive(Debug, Deserialize)]
struct ResolveRequest {
    action: String,
    #[serde(default)]
    anilist_id: i64,
    #[serde(default)]
    title_english: String,
    #[serde(default)]
    title_romaji: String,
    #[serde(default)]
    title_candidates: Vec<String>,
    #[serde(default)]
    media_format: String,
    #[serde(default)]
    expected_episodes: i32,
    #[serde(default)]
    embed_url: String,
    #[serde(default)]
    referer: String,
    #[serde(default)]
    url: String,
    #[serde(default)]
    headers: std::collections::HashMap<String, String>,
    #[serde(default)]
    slug: String,
    #[serde(default)]
    episode: i32,
    #[serde(default)]
    category: String,
}

pub fn resolve_json(request_json: &str) -> String {
    let req: ResolveRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    let result = match req.action.as_str() {
        "anikoto_resolve" => {
            let mut titles = req.title_candidates;
            if titles.is_empty() {
                for t in [&req.title_romaji, &req.title_english] {
                    let s = t.trim();
                    if !s.is_empty() {
                        titles.push(s.to_string());
                    }
                }
            }
            anikoto::anikoto_resolve(
                req.anilist_id,
                &titles,
                req.expected_episodes,
                &req.media_format,
            )
            .map(|series| json!({ "series": series }))
        }
        "anikoto_site_streams" => anikoto_site_streams(&req.slug, req.episode, &req.category)
            .map(|streams| json!({ "streams": streams })),
        "direct_embed_extract" => direct_embed_extract(
            &req.embed_url,
            if req.referer.is_empty() {
                None
            } else {
                Some(req.referer.as_str())
            },
        )
        .map(|result| json!({ "result": result })),
        "probe_stream_url" => Ok(json!({
            "reachable": probe_stream_url(&req.url, &req.headers),
        })),
        other => return json!({ "error": format!("unknown action: {other}") }).to_string(),
    };

    match result {
        Ok(v) => serde_json::to_string(&v).unwrap_or_else(|_| "{}".into()),
        Err(e) => json!({ "error": e }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unknown_action() {
        let raw = resolve_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }
}
