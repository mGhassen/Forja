mod bestsimilar;
mod http;

use serde::Deserialize;
use serde_json::json;

pub use bestsimilar::{
    autocomplete_url, details_url, find_best_hit, parse_autocomplete_json, parse_details_html,
    AutocompleteHit, Details, SimilarItem,
};

#[derive(Debug, Deserialize)]
struct CatalogRequest {
    action: String,
    #[serde(default)]
    query: String,
    #[serde(default)]
    id: i64,
    #[serde(default)]
    slug: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    year: Option<i32>,
    #[serde(default)]
    is_tv: bool,
}

pub fn catalog_json(request_json: &str) -> String {
    let req: CatalogRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    match req.action.as_str() {
        "autocomplete" => {
            let q = req.query.trim();
            if q.is_empty() {
                return json!({ "hits": [] }).to_string();
            }
            let url = autocomplete_url(q);
            let headers = http::autocomplete_headers();
            match http::fetch_html(&url, &headers, 8) {
                Ok(body) => {
                    let hits = parse_autocomplete_json(&body);
                    json!({ "hits": hits }).to_string()
                }
                Err(e) => json!({ "error": e }).to_string(),
            }
        }
        "details" => {
            if req.slug.is_empty() {
                return json!({ "error": "slug required" }).to_string();
            }
            if req.id <= 0 {
                return json!({ "error": "id required" }).to_string();
            }
            let url = details_url(&req.slug);
            let headers = http::default_html_headers();
            match http::fetch_html(&url, &headers, 15) {
                Ok(body) => {
                    let details = parse_details_html(req.id, &req.slug, &body);
                    json!({ "details": details }).to_string()
                }
                Err(e) => json!({ "error": e }).to_string(),
            }
        }
        "find_best" => {
            let q = req.title.trim();
            if q.is_empty() {
                return json!({ "hit": null }).to_string();
            }
            let url = autocomplete_url(q);
            let headers = http::autocomplete_headers();
            match http::fetch_html(&url, &headers, 8) {
                Ok(body) => {
                    let hits = parse_autocomplete_json(&body);
                    let hit = find_best_hit(&hits, q, req.year, req.is_tv);
                    json!({ "hit": hit }).to_string()
                }
                Err(e) => json!({ "error": e }).to_string(),
            }
        }
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unknown_action() {
        let raw = catalog_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }

    #[test]
    fn autocomplete_empty_query_returns_empty_hits() {
        let raw = catalog_json(r#"{"action":"autocomplete","query":""}"#);
        assert!(raw.contains(r#""hits":[]"#));
    }

    #[test]
    fn details_requires_slug_and_id() {
        let raw = catalog_json(r#"{"action":"details","id":1,"slug":""}"#);
        assert!(raw.contains("slug required"));

        let raw = catalog_json(r#"{"action":"details","id":0,"slug":"1-test"}"#);
        assert!(raw.contains("id required"));
    }
}
