use serde::Deserialize;
use serde_json::json;
use urlencoding::encode;

use crate::http::{default_headers, fetch_html, BASE_URL};
use crate::parse::{
    parse_chapter_images, parse_chapters, parse_search_results, parse_series_detail,
};

const PAGE_SIZE: i32 = 32;

#[derive(Debug, Deserialize)]
struct CatalogRequest {
    action: String,
    #[serde(default = "default_page")]
    page: i32,
    #[serde(default)]
    query: String,
    #[serde(default)]
    tag: String,
    #[serde(default)]
    allow_adult: bool,
    #[serde(default)]
    series_id: String,
    #[serde(default)]
    chapter_id: String,
}

fn default_page() -> i32 {
    1
}

fn browse_url(page: i32, tag: Option<&str>, allow_adult: bool) -> String {
    let offset = (page - 1).max(0) * PAGE_SIZE;
    let adult = if allow_adult { "Any" } else { "False" };
    let mut url = format!(
        "{BASE_URL}/search/data?text=&display_mode=Full+Display&sort=Popularity&order=Descending&official=Any&adult={adult}&offset={offset}"
    );
    if let Some(t) = tag.filter(|s| !s.is_empty()) {
        url.push_str(&format!("&included_tag={}", encode(t)));
    }
    url
}

fn search_url(query: &str, page: i32, allow_adult: bool) -> String {
    let offset = (page - 1).max(0) * PAGE_SIZE;
    let adult = if allow_adult { "Any" } else { "False" };
    format!(
        "{BASE_URL}/search/data?text={}&display_mode=Full+Display&sort=Best+Match&order=Descending&official=Any&adult={adult}&offset={offset}",
        encode(query)
    )
}

pub fn catalog_json(request_json: &str) -> String {
    let req: CatalogRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    let headers = default_headers();
    let result = match req.action.as_str() {
        "browse" => {
            let url = browse_url(
                req.page,
                if req.tag.is_empty() {
                    None
                } else {
                    Some(req.tag.as_str())
                },
                req.allow_adult,
            );
            fetch_html(&url, &headers, 15).map(|html| {
                json!({ "items": parse_search_results(&html) })
            })
        }
        "search" => {
            if req.query.trim().is_empty() {
                Ok(json!({ "items": [] }))
            } else {
                let url = search_url(&req.query, req.page, req.allow_adult);
                fetch_html(&url, &headers, 15).map(|html| {
                    json!({ "items": parse_search_results(&html) })
                })
            }
        }
        "details" => {
            if req.series_id.is_empty() {
                return json!({ "error": "series_id required" }).to_string();
            }
            let url = format!("{BASE_URL}/series/{}", req.series_id);
            fetch_html(&url, &headers, 15).map(|html| {
                json!({ "details": parse_series_detail(&html, &req.series_id) })
            })
        }
        "chapters" => {
            if req.series_id.is_empty() {
                return json!({ "error": "series_id required" }).to_string();
            }
            let url = format!("{BASE_URL}/series/{}/full-chapter-list", req.series_id);
            fetch_html(&url, &headers, 15).map(|html| {
                json!({ "chapters": parse_chapters(&html) })
            })
        }
        "chapter_images" => {
            if req.chapter_id.is_empty() {
                return json!({ "error": "chapter_id required" }).to_string();
            }
            let url = format!(
                "{BASE_URL}/chapters/{}/images?is_prev=False&current_page=1&reading_style=long_strip",
                req.chapter_id
            );
            fetch_html(&url, &headers, 15).map(|html| {
                json!({ "images": parse_chapter_images(&html) })
            })
        }
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
        let raw = catalog_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }
}
