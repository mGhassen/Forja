mod http;
mod jackett;
mod link_resolver;
mod prowlarr;
mod types;

use serde::Deserialize;
use serde_json::json;

pub use types::{
    format_size, normalize_base_url, ConnectionTest, ProwlarrTag, ResolvedLink, TorrentRow,
};

#[derive(Debug, Deserialize)]
struct IndexerRequest {
    action: String,
    #[serde(default)]
    base_url: String,
    #[serde(default)]
    api_key: String,
    #[serde(default)]
    query: String,
    #[serde(default)]
    url: String,
    #[serde(default)]
    indexer_ids: Vec<i32>,
    #[serde(default)]
    tag_ids: Vec<i32>,
}

pub fn request_json(request_json: &str) -> String {
    let req: IndexerRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    match req.action.as_str() {
        "jackett_search" => match jackett::search_blocking(&req.base_url, &req.api_key, &req.query) {
            Ok(results) => serde_json::to_string(&json!({ "results": results }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "jackett_test" => {
            let test = jackett::test_connection_blocking(&req.base_url, &req.api_key);
            serde_json::to_string(&test).unwrap_or_else(|_| "{}".into())
        }
        "prowlarr_search" => {
            let ids = if req.indexer_ids.is_empty() {
                None
            } else {
                Some(req.indexer_ids.as_slice())
            };
            match prowlarr::search_blocking(&req.base_url, &req.api_key, &req.query, ids) {
                Ok(results) => serde_json::to_string(&json!({ "results": results }))
                    .unwrap_or_else(|_| "{}".into()),
                Err(e) => json!({ "error": e }).to_string(),
            }
        }
        "prowlarr_test" => {
            let test = prowlarr::test_connection_blocking(&req.base_url, &req.api_key);
            serde_json::to_string(&test).unwrap_or_else(|_| "{}".into())
        }
        "prowlarr_tags" => match prowlarr::fetch_tags_blocking(&req.base_url, &req.api_key) {
            Ok(tags) => serde_json::to_string(&json!({ "tags": tags }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "prowlarr_resolve_tags" => {
            match prowlarr::resolve_tag_indexer_ids_blocking(
                &req.base_url,
                &req.api_key,
                &req.tag_ids,
            ) {
                Ok(ids) => serde_json::to_string(&json!({ "indexer_ids": ids }))
                    .unwrap_or_else(|_| "{}".into()),
                Err(e) => json!({ "error": e }).to_string(),
            }
        }
        "resolve_link" => match link_resolver::resolve_blocking(&req.url) {
            Ok(link) => serde_json::to_string(&link).unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unknown_action() {
        let raw = request_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }

    #[test]
    fn rejects_invalid_json() {
        let raw = request_json("{");
        assert!(raw.contains("invalid request"));
    }
}
