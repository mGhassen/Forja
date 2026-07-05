pub mod extractors;
pub mod types;
pub mod utils;

pub use extractors::{
    build_embed_url, extract_embed_html, extract_from_html_chain, extract_hubcloud_links,
    extract_vidsrc_chain_json, list_html_extractors,
};

pub fn extract_embed_html_json(extractor_id: &str, html: &str, page_url: &str) -> String {
    match extract_embed_html(extractor_id, html, page_url) {
        Some(result) => serde_json::to_string(&result).unwrap_or_else(|_| "{}".into()),
        None => serde_json::json!({ "error": "not_found" }).to_string(),
    }
}

pub fn extract_hubcloud_links_json(html: &str, page_url: &str) -> String {
    let results = extract_hubcloud_links(html, page_url);
    serde_json::to_string(&results).unwrap_or_else(|_| "[]".into())
}
