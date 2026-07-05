pub mod config;
pub mod extractors;
pub mod fetcher;
pub mod language;
pub mod resolver;
pub mod sources;
pub mod tmdb;
pub mod types;
pub mod utils;

pub use extractors::{
    build_embed_url, extract_embed_html, extract_from_html_chain, extract_hubcloud_links,
    extract_mfp_embed_html, extract_vidsrc_chain_json, list_html_extractors, list_mfp_extractors,
};
pub use config::{default_config, APP_NAME, Config};
pub use resolver::get_streams_json;
pub use sources::{
    extract_kinoger_episode_urls, list_url_sources, parse_source_html, resolve_source,
    SourceEmbed, SourceRequest,
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

pub fn extract_mfp_embed_html_json(
    extractor_id: &str,
    html: &str,
    page_url: &str,
    mfp_config_json: &str,
    extra_html: &str,
) -> String {
    match extractors::extract_mfp_embed_html(
        extractor_id,
        html,
        page_url,
        mfp_config_json,
        extra_html,
    ) {
        Some(result) => serde_json::to_string(&result).unwrap_or_else(|_| "{}".into()),
        None => serde_json::json!({ "error": "not_found" }).to_string(),
    }
}

pub fn resolve_source_json(source_id: &str, request_json: &str) -> String {
    sources::resolve_source_json(source_id, request_json)
}

pub fn extract_kinoger_episode_urls_json(
    html: &str,
    season_index: i32,
    episode_index: i32,
) -> String {
    sources::extract_kinoger_episode_urls_json(html, season_index, episode_index)
}

pub fn parse_webstreamr_source_html_json(
    source_id: &str,
    html: &str,
    opts_json: &str,
) -> String {
    sources::parse_source_html_json(source_id, html, opts_json)
}

