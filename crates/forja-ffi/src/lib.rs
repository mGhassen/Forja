mod c_api;

use forja_iptv_core::m3u;
use forja_iptv_core::pastesh;
use forja_scrapers::{dedup_by_infohash, parse_knaben_html, parse_tpb_html, parse_uindex_html};
use forja_stream_core::list_providers;
use forja_stremio_core::{build_resource_url, parse_manifest};
use forja_torrent::TorrentEngine;
use forja_utils::{
    episode_matcher, hls_parser, js_unpacker, kisskh_subtitle, torrent_filter,
};
use std::sync::{LazyLock, Mutex};

uniffi::include_scaffolding!("forja");

const VERSION: &str = env!("CARGO_PKG_VERSION");

static TORRENT: LazyLock<Mutex<TorrentEngine>> = LazyLock::new(|| Mutex::new(TorrentEngine::new()));

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
    forja_stream_core::build_movie_url(&provider_id, tmdb_id).unwrap_or_default()
}

fn build_tv_url(provider_id: String, tmdb_id: i64, season: i32, episode: i32) -> String {
    forja_stream_core::build_tv_url(&provider_id, tmdb_id, season, episode).unwrap_or_default()
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
    forja_iptv_core::xtream::decode_xtream_text(&text)
}

fn parse_xtream_categories_json(json: String) -> String {
    forja_iptv_core::xtream::parse_categories_json(&json)
}

fn parse_xtream_streams_json(json: String, section: String) -> String {
    forja_iptv_core::xtream::parse_streams_json(&json, &section)
}

fn parse_stremio_manifest_json(json: String) -> String {
    match parse_manifest(&json) {
        Ok(m) => serde_json::to_string(&m).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn build_stremio_resource_url(addon_url: String, resource_path: String) -> String {
    build_resource_url(&addon_url, &resource_path)
}

fn normalize_stremio_manifest_url(url: String) -> String {
    forja_stremio_core::normalize_manifest_url(&url)
}

fn split_stremio_addon_url_json(url: String) -> String {
    let parts = forja_stremio_core::split_addon_url(&url);
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
    let parsed: Vec<forja_scrapers::TorrentSearchResult> =
        serde_json::from_str(&results_json).unwrap_or_default();
    serde_json::to_string(&dedup_by_infohash(parsed)).unwrap_or_else(|_| "[]".into())
}

fn extract_embed_html_json(extractor_id: String, html: String, page_url: String) -> String {
    forja_webstreamr::extract_embed_html_json(&extractor_id, &html, &page_url)
}

fn extract_vidsrc_chain_json(outer_html: String, rcp_html: String, prorcp_html: String) -> String {
    forja_webstreamr::extract_vidsrc_chain_json(&outer_html, &rcp_html, &prorcp_html)
}

fn extract_hubcloud_links_json(html: String, page_url: String) -> String {
    forja_webstreamr::extract_hubcloud_links_json(&html, &page_url)
}

fn extract_mfp_embed_html_json(
    extractor_id: String,
    html: String,
    page_url: String,
    mfp_config_json: String,
    extra_html: String,
) -> String {
    forja_webstreamr::extract_mfp_embed_html_json(
        &extractor_id,
        &html,
        &page_url,
        &mfp_config_json,
        &extra_html,
    )
}

fn resolve_webstreamr_source_json(source_id: String, request_json: String) -> String {
    forja_webstreamr::resolve_source_json(&source_id, &request_json)
}

fn extract_kinoger_episode_urls_json(html: String, season_index: i32, episode_index: i32) -> String {
    forja_webstreamr::extract_kinoger_episode_urls_json(&html, season_index, episode_index)
}

fn torrent_start(magnet: String) -> bool {
    TORRENT
        .lock()
        .ok()
        .and_then(|mut e| e.start(&magnet).ok())
        .is_some()
}

fn torrent_stop() {
    if let Ok(mut e) = TORRENT.lock() {
        e.stop();
    }
}

fn torrent_is_running() -> bool {
    TORRENT
        .lock()
        .map(|e| e.is_running())
        .unwrap_or(false)
}
