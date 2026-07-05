mod c_api;
#[cfg(feature = "torrent-engine")]
mod engine_torrent;
#[cfg(feature = "local-proxy")]
mod engine_proxy;

use iptv_core::m3u;
use iptv_core::pastesh;
use scrapers::{dedup_by_infohash, parse_knaben_html, parse_tpb_html, parse_uindex_html};
use stream_core::list_providers;
use stremio_core::{
    build_resource_url, fetch_get, parse_catalog, parse_manifest, parse_meta, parse_streams,
    parse_subtitles,
};
use utils::{
    episode_matcher, hls_parser, js_unpacker, kisskh_subtitle, torrent_filter,
};
use std::sync::LazyLock;
use tokio::runtime::Runtime;

uniffi::include_scaffolding!("forja");

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[allow(dead_code)]
static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("ffi tokio runtime"));

fn version() -> String {
    VERSION.to_string()
}

fn add(a: i64, b: i64) -> i64 {
    a + b
}

fn episode_matches(filename: String, season: i32, episode: i32) -> bool {
    episode_matcher::matches(&filename, season, episode)
}

fn normalize_torrent_title(title: String) -> String {
    torrent_filter::normalize_title(&title)
}

fn parse_scene_info_json(title: String) -> String {
    serde_json::to_string(&torrent_filter::parse_scene_info(&title)).unwrap_or_else(|_| "{}".into())
}

fn unpack_js(source: String) -> String {
    js_unpacker::unpack(&source).unwrap_or_default()
}

fn parse_hls_master_json(master_url: String, body: String) -> String {
    match hls_parser::parse_hls_master(&master_url, &body) {
        Some(q) => serde_json::to_string(&q).unwrap_or_else(|_| "[]".into()),
        None => "[]".into(),
    }
}

fn decrypt_kisskh_body(body: String, source_url: Option<String>) -> String {
    kisskh_subtitle::decrypt_body(&body, source_url.as_deref())
}

fn build_movie_url(provider_id: String, tmdb_id: i64) -> String {
    stream_core::build_movie_url(&provider_id, tmdb_id).unwrap_or_default()
}

fn build_tv_url(provider_id: String, tmdb_id: i64, season: i32, episode: i32) -> String {
    stream_core::build_tv_url(&provider_id, tmdb_id, season, episode).unwrap_or_default()
}

fn list_providers_json() -> String {
    serde_json::to_string(&list_providers()).unwrap_or_else(|_| "[]".into())
}

fn parse_m3u_json(content: String) -> String {
    match m3u::parse(&content) {
        Ok(channels) => serde_json::to_string(&channels).unwrap_or_else(|_| "[]".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn decrypt_paste_response(url_with_hash: String, raw_response: String) -> String {
    pastesh::decrypt_from_paste_response(&url_with_hash, &raw_response).unwrap_or_default()
}

fn decode_xtream_text(text: String) -> String {
    iptv_core::xtream::decode_xtream_text(&text)
}

fn parse_xtream_categories_json(json: String) -> String {
    iptv_core::xtream::parse_categories_json(&json)
}

fn parse_xtream_streams_json(json: String, section: String) -> String {
    iptv_core::xtream::parse_streams_json(&json, &section)
}

fn parse_xtream_series_episodes_json(json: String) -> String {
    iptv_core::xtream::parse_series_episodes_json(&json)
}

fn parse_stremio_manifest_json(json: String) -> String {
    match parse_manifest(&json) {
        Ok(m) => serde_json::to_string(&m).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn parse_stremio_streams_json(json: String) -> String {
    match parse_streams(&json) {
        Ok(v) => serde_json::to_string(&v).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn parse_stremio_subtitles_json(json: String) -> String {
    match parse_subtitles(&json) {
        Ok(v) => serde_json::to_string(&v).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn parse_stremio_catalog_json(json: String) -> String {
    match parse_catalog(&json) {
        Ok(v) => serde_json::to_string(&v).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn parse_stremio_meta_json(json: String) -> String {
    match parse_meta(&json) {
        Ok(v) => serde_json::to_string(&v).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn stremio_http_get_json(url: String, timeout_secs: u64) -> String {
    match fetch_get(&url, timeout_secs) {
        Ok(resp) => serde_json::to_string(&resp).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn build_stremio_resource_url(addon_url: String, resource_path: String) -> String {
    build_resource_url(&addon_url, &resource_path)
}

fn normalize_stremio_manifest_url(url: String) -> String {
    stremio_core::normalize_manifest_url(&url)
}

fn split_stremio_addon_url_json(url: String) -> String {
    let parts = stremio_core::split_addon_url(&url);
    serde_json::to_string(&parts).unwrap_or_else(|_| "{}".into())
}

fn parse_knaben_html_json(html: String) -> String {
    serde_json::to_string(&parse_knaben_html(&html)).unwrap_or_else(|_| "[]".into())
}

fn parse_tpb_html_json(html: String) -> String {
    serde_json::to_string(&parse_tpb_html(&html, "ThePirateBay")).unwrap_or_else(|_| "[]".into())
}

fn parse_uindex_html_json(html: String) -> String {
    serde_json::to_string(&parse_uindex_html(&html)).unwrap_or_else(|_| "[]".into())
}

fn dedup_torrents_json(results_json: String) -> String {
    let parsed: Vec<scrapers::TorrentSearchResult> =
        serde_json::from_str(&results_json).unwrap_or_default();
    serde_json::to_string(&dedup_by_infohash(parsed)).unwrap_or_else(|_| "[]".into())
}

fn extract_embed_html_json(extractor_id: String, html: String, page_url: String) -> String {
    webstreamr::extract_embed_html_json(&extractor_id, &html, &page_url)
}

fn extract_vidsrc_chain_json(outer_html: String, rcp_html: String, prorcp_html: String) -> String {
    webstreamr::extract_vidsrc_chain_json(&outer_html, &rcp_html, &prorcp_html)
}

fn extract_hubcloud_links_json(html: String, page_url: String) -> String {
    webstreamr::extract_hubcloud_links_json(&html, &page_url)
}

fn extract_mfp_embed_html_json(
    extractor_id: String,
    html: String,
    page_url: String,
    mfp_config_json: String,
    extra_html: String,
) -> String {
    webstreamr::extract_mfp_embed_html_json(
        &extractor_id,
        &html,
        &page_url,
        &mfp_config_json,
        &extra_html,
    )
}

fn resolve_webstreamr_source_json(source_id: String, request_json: String) -> String {
    webstreamr::resolve_source_json(&source_id, &request_json)
}

fn extract_kinoger_episode_urls_json(html: String, season_index: i32, episode_index: i32) -> String {
    webstreamr::extract_kinoger_episode_urls_json(&html, season_index, episode_index)
}

fn parse_webstreamr_source_html_json(source_id: String, html: String, opts_json: String) -> String {
    webstreamr::parse_webstreamr_source_html_json(&source_id, &html, &opts_json)
}

fn torrent_start(magnet: String) -> bool {
    #[cfg(feature = "torrent-engine")]
    {
        return engine_torrent::torrent_start(magnet);
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        let _ = magnet;
        false
    }
}

fn torrent_stop() {
    #[cfg(feature = "torrent-engine")]
    engine_torrent::torrent_stop();
}

fn torrent_is_running() -> bool {
    #[cfg(feature = "torrent-engine")]
    {
        return engine_torrent::torrent_is_running();
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        false
    }
}

fn torrent_status_json() -> String {
    #[cfg(feature = "torrent-engine")]
    {
        return engine_torrent::torrent_status_json();
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        "null".into()
    }
}

fn torrent_engine_start(preferred_port: u32) -> i32 {
    #[cfg(feature = "torrent-engine")]
    {
        return engine_torrent::torrent_engine_start(preferred_port.min(u16::MAX as u32) as u16);
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        let _ = preferred_port;
        -1
    }
}

fn torrent_engine_port() -> u32 {
    #[cfg(feature = "torrent-engine")]
    {
        return engine_torrent::torrent_engine_port() as u32;
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        0
    }
}

fn torrent_engine_stop() {
    #[cfg(feature = "torrent-engine")]
    engine_torrent::torrent_engine_stop();
}

fn torrent_set_peer_limit(limit: u32) {
    #[cfg(feature = "torrent-engine")]
    engine_torrent::torrent_set_peer_limit(limit);
    #[cfg(not(feature = "torrent-engine"))]
    {
        let _ = limit;
    }
}

fn torrent_stream_json(magnet: String, season: i32, episode: i32, file_idx: i32) -> String {
    #[cfg(feature = "torrent-engine")]
    {
        return engine_torrent::torrent_stream_json(magnet, season, episode, file_idx);
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        let _ = (magnet, season, episode, file_idx);
        r#"{"error":"torrent_engine_unavailable"}"#.into()
    }
}

fn torrent_list_files_json(magnet: String) -> String {
    #[cfg(feature = "torrent-engine")]
    {
        return engine_torrent::torrent_list_files_json(magnet);
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        let _ = magnet;
        r#"{"error":"torrent_engine_unavailable"}"#.into()
    }
}

fn proxy_start(preferred_port: u32) -> i32 {
    #[cfg(feature = "local-proxy")]
    {
        return engine_proxy::proxy_start(
            &RUNTIME,
            preferred_port.min(u16::MAX as u32) as u16,
        );
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        let _ = preferred_port;
        -1
    }
}

fn proxy_stop() {
    #[cfg(feature = "local-proxy")]
    engine_proxy::proxy_stop();
}

fn proxy_port() -> u32 {
    #[cfg(feature = "local-proxy")]
    {
        return engine_proxy::proxy_port() as u32;
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        0
    }
}

fn proxy_register_route(token: String, upstream_url: String) -> bool {
    #[cfg(feature = "local-proxy")]
    {
        return engine_proxy::proxy_register_route(&RUNTIME, token, upstream_url);
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        let _ = (token, upstream_url);
        false
    }
}
