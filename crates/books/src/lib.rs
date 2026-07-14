mod http;
mod parse;

use serde::Deserialize;
use serde_json::json;
use urlencoding::encode;

pub use parse::{BookEditionDetails, BookResult, DownloadLink};

use crate::http::{default_headers, fetch_html, BASE_URL};
use crate::parse::{parse_download_url, parse_edition_details, parse_search_results};

#[derive(Debug, Deserialize)]
struct CatalogRequest {
    action: String,
    #[serde(default)]
    query: String,
    #[serde(default)]
    edition_id: String,
    #[serde(default)]
    md5: String,
}

fn search_url(query: &str) -> String {
    format!(
        "{BASE_URL}/index.php?req={}&curtab=f",
        encode(query.trim())
    )
}

pub fn search(query: &str) -> Result<Vec<BookResult>, String> {
    if query.trim().is_empty() {
        return Ok(vec![]);
    }
    let headers = default_headers();
    let url = search_url(query);
    let html = fetch_html(&url, &headers, 15)?;
    Ok(parse_search_results(&html))
}

pub fn get_edition_details(edition_id: &str) -> Result<BookEditionDetails, String> {
    if edition_id.trim().is_empty() {
        return Err("edition_id required".into());
    }
    let headers = default_headers();
    let url = format!("{BASE_URL}/edition.php?id={}", edition_id.trim());
    let html = fetch_html(&url, &headers, 15)?;
    parse_edition_details(&html, edition_id.trim())
}

pub fn get_download_url(md5: &str) -> Result<String, String> {
    if md5.trim().is_empty() {
        return Err("md5 required".into());
    }
    let headers = default_headers();
    let url = format!("{BASE_URL}/ads.php?md5={}", md5.trim());
    let html = fetch_html(&url, &headers, 15)?;
    parse_download_url(&html)
}

pub fn resolve_download(edition_id: &str) -> Result<(BookEditionDetails, String), String> {
    let edition = get_edition_details(edition_id)?;
    let download_url = get_download_url(&edition.md5)?;
    Ok((edition, download_url))
}

pub fn books_catalog_json(request_json: &str) -> String {
    let req: CatalogRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    match req.action.as_str() {
        "search" => match search(&req.query) {
            Ok(results) => ok_json(&json!({ "results": results })),
            Err(e) => error_json(&e),
        },
        "edition" => match get_edition_details(&req.edition_id) {
            Ok(edition) => ok_json(&json!({ "edition": edition })),
            Err(e) => error_json(&e),
        },
        "download_url" => match get_download_url(&req.md5) {
            Ok(url) => ok_json(&json!({ "url": url })),
            Err(e) => error_json(&e),
        },
        "resolve" => match resolve_download(&req.edition_id) {
            Ok((edition, url)) => ok_json(&json!({
                "edition": edition,
                "downloadUrl": url,
            })),
            Err(e) => error_json(&e),
        },
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}

fn ok_json<T: serde::Serialize>(value: &T) -> String {
    serde_json::to_string(value).unwrap_or_else(|_| "{}".into())
}

fn error_json(message: &str) -> String {
    json!({ "error": message }).to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unknown_action() {
        let raw = books_catalog_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }

    #[test]
    fn rejects_invalid_json() {
        let raw = books_catalog_json("not-json");
        assert!(raw.contains("invalid request"));
    }

    #[test]
    fn edition_requires_id() {
        let raw = books_catalog_json(r#"{"action":"edition"}"#);
        assert!(raw.contains("edition_id required"));
    }

    #[test]
    fn download_url_requires_md5() {
        let raw = books_catalog_json(r#"{"action":"download_url"}"#);
        assert!(raw.contains("md5 required"));
    }
}
