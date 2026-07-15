mod allanime;
pub(crate) mod common;
mod animerealms;
mod hentaini;
mod miruro;
mod watchhentai;

use crate::resolve::{anikoto, direct_embed, probe};
use serde::Deserialize;
use serde_json::json;

#[derive(Debug, Deserialize)]
struct ExtractorRequest {
    action: String,
    #[serde(default)]
    title_candidates: Vec<String>,
    #[serde(default)]
    episode: i32,
    #[serde(default)]
    episode_number: i32,
    #[serde(default)]
    category: String,
    #[serde(default)]
    provider: String,
    #[serde(default)]
    anilist_id: i64,
    #[serde(default)]
    webview_body: String,
    #[serde(default)]
    webview_x_obfuscated: String,
    /// Which Miruro pipe the [webview_body] belongs to: `episodes` or `sources`.
    #[serde(default)]
    webview_pipe_path: String,
    #[serde(default)]
    pipe_body: String,
    #[serde(default)]
    x_obfuscated: String,
    #[serde(default)]
    title_english: String,
    #[serde(default)]
    title_romaji: String,
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
}

pub fn extractor_json(request_json: &str) -> String {
    let req: ExtractorRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    let episode = if req.episode_number > 0 {
        req.episode_number
    } else {
        req.episode
    };

    let webview_body = if !req.webview_body.is_empty() {
        Some(req.webview_body.as_str())
    } else if !req.pipe_body.is_empty() {
        Some(req.pipe_body.as_str())
    } else {
        None
    };
    let webview_x_obf = if !req.webview_x_obfuscated.is_empty() {
        Some(req.webview_x_obfuscated.as_str())
    } else if !req.x_obfuscated.is_empty() {
        Some(req.x_obfuscated.as_str())
    } else {
        None
    };
    let webview_pipe_path = if !req.webview_pipe_path.is_empty() {
        Some(req.webview_pipe_path.as_str())
    } else if webview_body.is_some() {
        // Legacy callers only fetched the episodes pipe.
        Some("episodes")
    } else {
        None
    };

    let result = match req.action.as_str() {
        "allanime_search" => allanime::allanime_search(&req.title_candidates, &req.category),
        "allanime_sources" => allanime::allanime_sources(
            &req.title_candidates,
            episode,
            &req.category,
            &req.provider,
        ),
        "allanime_known_providers" => Ok(json!({ "providers": allanime::KNOWN_PROVIDERS })),
        "miruro_resolve" => miruro::miruro_resolve(
            req.anilist_id,
            episode,
            &req.category,
            &req.provider,
            webview_body,
            webview_x_obf,
            webview_pipe_path,
        ),
        "miruro_decode_pipe" => {
            let body = webview_body.unwrap_or("");
            miruro::decode_pipe_body(body, webview_x_obf).map(|v| json!({ "data": v }))
        }
        "miruro_encode_pipe" => {
            let payload = json!({
                "path": req.provider,
                "method": "GET",
                "query": {},
                "body": null,
                "version": "0.2.0",
            });
            Ok(json!({ "encoded": miruro::encode_pipe_request(&payload) }))
        }
        "miruro_known_providers" => Ok(json!({
            "providers": miruro::KNOWN_PROVIDERS,
            "upstream": miruro::UPSTREAM_SOURCES,
        })),
        "animerealms_streams" => {
            animerealms::animerealms_streams(req.anilist_id, episode, &req.provider)
        }
        "animerealms_known_providers" => {
            Ok(json!({ "providers": animerealms::DEFAULT_PROVIDERS }))
        }
        "hentaini_streams" => hentaini::hentaini_streams(&req.title_candidates, episode),
        "watchhentai_streams" => watchhentai::watchhentai_streams(&req.title_candidates, episode),
        "anikoto_resolve" => anikoto::anikoto_resolve(
            req.anilist_id,
            &req.title_english,
            &req.title_romaji,
            req.expected_episodes,
        )
        .map(|series| json!({ "series": series })),
        "direct_embed_extract" => direct_embed::direct_embed_extract(
            &req.embed_url,
            if req.referer.is_empty() {
                None
            } else {
                Some(req.referer.as_str())
            },
        )
        .map(|result| json!({ "result": result })),
        "probe_stream_url" => Ok(json!({
            "reachable": probe::probe_stream_url(&req.url, &req.headers),
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
        let raw = extractor_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }

    #[test]
    fn returns_known_providers() {
        let raw = extractor_json(r#"{"action":"allanime_known_providers"}"#);
        assert!(raw.contains("Default"));
        assert!(raw.contains("S-mp4"));
    }
}
