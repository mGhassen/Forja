mod c_api;
mod engine_jobs;
#[cfg(feature = "lan-server")]
mod engine_lan;
#[cfg(feature = "local-proxy")]
mod engine_mega;
#[cfg(feature = "local-proxy")]
mod engine_proxy;
#[cfg(feature = "local-proxy")]
mod engine_seek111477;
#[cfg(feature = "torrent-engine")]
mod engine_torrent;

use iptv::m3u;
use iptv::pastesh;
use scrapers::{
    dedup_by_infohash, parse_knaben_html, parse_tpb_html, parse_uindex_html, search_request,
    SearchRequest,
};
use std::sync::LazyLock;
use stream::list_providers;
use stremio::{
    build_resource_url, fetch_get, fetch_get_with_headers, fetch_post_with_headers, parse_catalog,
    parse_manifest, parse_meta, parse_streams, parse_subtitles,
};
use tokio::runtime::Runtime;
use utils::{episode_matcher, hls_parser, js_unpacker, kisskh_subtitle, torrent_filter};

uniffi::include_scaffolding!("forja");

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[allow(dead_code)]
static RUNTIME: LazyLock<Runtime> = LazyLock::new(|| Runtime::new().expect("ffi tokio runtime"));

fn version() -> String {
    VERSION.to_string()
}

fn engine_cancel_pending() {
    engine_jobs::cancel_all();
}

/// Abort in-flight TMDB catalog HTTP (Home filter flips). Playback stays live.
fn engine_cancel_catalog() {
    utils::engine_cancel::request_catalog();
}

/// Abort Forja `EngineJsExtract` jobs only — keeps magnet / torrent resolve alive.
fn engine_cancel_jobs_of_kind(kind: u32) {
    engine_jobs::cancel_kind(kind);
}

fn engine_prepare_shutdown() {
    utils::engine_cancel::request_shutdown();
    engine_jobs::cancel_live_matches_fetch();
    engine_jobs::cancel_all();
}

fn engine_clear_shutdown() {
    utils::engine_cancel::clear_shutdown();
}

fn engine_submit_job(kind: u32, payload_json: String) -> u64 {
    engine_jobs::submit(kind, payload_json)
}

fn engine_take_job_result(job_id: u64) -> Option<String> {
    engine_jobs::take_result(job_id)
}

fn add(a: i64, b: i64) -> i64 {
    a + b
}

fn episode_matches(filename: String, season: i32, episode: i32) -> bool {
    episode_matcher::matches(&filename, season, episode)
}

fn pick_episode_index_json(files_json: String, season: i32, episode: i32) -> i32 {
    #[derive(serde::Deserialize)]
    struct Entry {
        name: String,
        #[serde(default)]
        size: u64,
    }
    let entries: Vec<Entry> = serde_json::from_str(&files_json).unwrap_or_default();
    let sized: Vec<(String, u64)> = entries.into_iter().map(|e| (e.name, e.size)).collect();
    episode_matcher::pick_episode_index_sized(&sized, season, episode)
        .map(|i| i as i32)
        .unwrap_or(-1)
}

fn pick_largest_video_index_json(files_json: String) -> i32 {
    #[derive(serde::Deserialize)]
    struct Entry {
        name: String,
        #[serde(default)]
        size: u64,
    }
    let entries: Vec<Entry> = serde_json::from_str(&files_json).unwrap_or_default();
    let sized: Vec<(String, u64)> = entries.into_iter().map(|e| (e.name, e.size)).collect();
    episode_matcher::pick_largest_video_index_sized(&sized)
        .map(|i| i as i32)
        .unwrap_or(-1)
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

fn set_provider_runtime_overlay(json: String) -> String {
    match utils::provider_runtime::set_overlay_json(&json) {
        Ok(()) => String::new(),
        Err(e) => e,
    }
}

fn build_movie_url(provider_id: String, tmdb_id: i64) -> String {
    stream::build_movie_url(&provider_id, tmdb_id).unwrap_or_default()
}

fn build_tv_url(provider_id: String, tmdb_id: i64, season: i32, episode: i32) -> String {
    stream::build_tv_url(&provider_id, tmdb_id, season, episode).unwrap_or_default()
}

fn list_providers_json() -> String {
    serde_json::to_string(&list_providers()).unwrap_or_else(|_| "[]".into())
}

fn playback_rank_sources_json(payload_json: String) -> String {
    stream::rank_sources_json(&payload_json)
}

fn playback_normalize_legacy_json(payload_json: String) -> String {
    stream::normalize_legacy_json(&payload_json)
}

fn playback_order_providers_json(payload_json: String) -> String {
    use stream::{order_providers, OrderProvidersRequest};

    let mut request: OrderProvidersRequest = match serde_json::from_str(&payload_json) {
        Ok(r) => r,
        Err(e) => return serde_json::json!({ "error": e.to_string() }).to_string(),
    };
    if request.reliability.is_empty() {
        request.reliability = resolver_engine::ProviderHealthStore::global().all_provider_totals();
    }
    let response = order_providers(request);
    serde_json::to_string(&response)
        .unwrap_or_else(|e| serde_json::json!({ "error": e.to_string() }).to_string())
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

fn openssl_aes_decrypt_json(b64: String, passphrase: String) -> String {
    utils::openssl_crypt::decrypt_openssl_salted_b64_json(&b64, &passphrase)
}

fn decode_xtream_text(text: String) -> String {
    iptv::xtream::decode_xtream_text(&text)
}

fn iptv_portal_share_encode(url: String, username: String, password: String) -> String {
    iptv::portal_share::encode_token(&url, &username, &password)
}

fn iptv_portal_share_decode(token: String) -> String {
    iptv::portal_share::decode_token_json(&token)
}

fn parse_xtream_categories_json(json: String) -> String {
    iptv::xtream::parse_categories_json(&json)
}

fn parse_xtream_streams_json(json: String, section: String) -> String {
    iptv::xtream::parse_streams_json(&json, &section)
}

fn parse_xtream_series_episodes_json(json: String) -> String {
    iptv::xtream::parse_series_episodes_json(&json)
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
    utils::engine_cancel::enter_job();
    match fetch_get(&url, timeout_secs) {
        Ok(resp) => serde_json::to_string(&resp).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn http_get_json(url: String, timeout_secs: u64, headers_json: String) -> String {
    utils::engine_cancel::enter_job();
    let headers: std::collections::HashMap<String, String> =
        serde_json::from_str(&headers_json).unwrap_or_default();
    match fetch_get_with_headers(&url, timeout_secs, &headers) {
        Ok(resp) => serde_json::to_string(&resp).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn http_post_json(url: String, timeout_secs: u64, headers_json: String, body: String) -> String {
    utils::engine_cancel::enter_job();
    let headers: std::collections::HashMap<String, String> =
        serde_json::from_str(&headers_json).unwrap_or_default();
    match fetch_post_with_headers(&url, timeout_secs, &headers, &body) {
        Ok(resp) => serde_json::to_string(&resp).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e.to_string() }).to_string(),
    }
}

fn iptv_probe_stream_json(url: String, timeout_secs: u64) -> String {
    utils::engine_cancel::enter_job();
    iptv::stream_probe::probe_stream_alive_json(&url, timeout_secs)
}

fn live_matches_fetch_json(request_json: String) -> String {
    utils::engine_cancel::enter_job();
    live_matches::fetch_json(&request_json)
}

fn iptv_reddit_catalog_json(request_json: String) -> String {
    utils::engine_cancel::enter_job();
    iptv::reddit_catalog::catalog_json(&request_json)
}

fn tmdb_get_json(resource_path: String, timeout_secs: u64) -> String {
    utils::engine_cancel::enter_job();
    tmdb::get_json(&resource_path, timeout_secs)
}

fn anime_request_json(request_json: String) -> String {
    utils::engine_cancel::enter_job();
    anime::request_json(&request_json)
}

fn indexer_request_json(request_json: String) -> String {
    utils::engine_cancel::enter_job();
    indexer::request_json(&request_json)
}

fn debrid_request_json(request_json: String) -> String {
    utils::engine_cancel::enter_job();
    debrid::request_json(&request_json)
}

fn metadata_request_json(request_json: String) -> String {
    utils::engine_cancel::enter_job();
    anime::metadata_request_json(&request_json)
}

fn subtitle_request_json(request_json: String) -> String {
    utils::engine_cancel::enter_job();
    anime::subtitle_request_json(&request_json)
}

fn build_stremio_resource_url(addon_url: String, resource_path: String) -> String {
    build_resource_url(&addon_url, &resource_path)
}

fn normalize_stremio_manifest_url(url: String) -> String {
    stremio::normalize_manifest_url(&url)
}

fn split_stremio_addon_url_json(url: String) -> String {
    let parts = stremio::split_addon_url(&url);
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

fn search_torrents_json(query: String) -> String {
    utils::engine_cancel::enter_job();
    let req = SearchRequest::parse(&query);
    let results = RUNTIME.block_on(search_request(&req));
    serde_json::to_string(&results).unwrap_or_else(|_| "[]".into())
}

fn filter_torrents_json(
    results_json: String,
    show_title: String,
    required_season: i32,
    required_episode: i32,
) -> String {
    let items: Vec<torrent_filter::TorrentRow> =
        serde_json::from_str(&results_json).unwrap_or_default();
    let season = if required_season >= 0 {
        Some(required_season)
    } else {
        None
    };
    let episode = if required_episode >= 0 {
        Some(required_episode)
    } else {
        None
    };
    let filtered = torrent_filter::filter_torrents(&items, &show_title, season, episode);
    serde_json::to_string(&filtered).unwrap_or_else(|_| "[]".into())
}

fn sort_torrents_json(results_json: String, preference: String) -> String {
    let mut items: Vec<torrent_filter::TorrentRow> =
        serde_json::from_str(&results_json).unwrap_or_default();
    torrent_filter::sort_torrents(&mut items, &preference);
    serde_json::to_string(&items).unwrap_or_else(|_| "[]".into())
}

fn is_video_file(file_name: String) -> bool {
    torrent_filter::is_video_file(&file_name)
}

fn torrent_start(magnet: String) -> bool {
    #[cfg(feature = "torrent-engine")]
    {
        engine_torrent::torrent_start(magnet)
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
        engine_torrent::torrent_is_running()
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        false
    }
}

fn torrent_status_json() -> String {
    #[cfg(feature = "torrent-engine")]
    {
        engine_torrent::torrent_status_json()
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        "null".into()
    }
}

fn torrent_engine_start(preferred_port: u32) -> i32 {
    #[cfg(feature = "torrent-engine")]
    {
        engine_torrent::torrent_engine_start(preferred_port.min(u16::MAX as u32) as u16)
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        let _ = preferred_port;
        -1
    }
}

fn torrent_engine_last_error() -> String {
    #[cfg(feature = "torrent-engine")]
    {
        engine_torrent::torrent_engine_last_error()
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        "torrent-engine feature disabled".into()
    }
}

fn torrent_engine_port() -> u32 {
    #[cfg(feature = "torrent-engine")]
    {
        engine_torrent::torrent_engine_port() as u32
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

fn torrent_set_disk_cache_bytes(bytes: u64) {
    #[cfg(feature = "torrent-engine")]
    engine_torrent::torrent_set_disk_cache_bytes(bytes);
    #[cfg(not(feature = "torrent-engine"))]
    {
        let _ = bytes;
    }
}

fn torrent_reclaim_disk_cache_json(target_bytes: u64) -> String {
    #[cfg(feature = "torrent-engine")]
    {
        engine_torrent::torrent_reclaim_disk_cache_json(target_bytes)
    }
    #[cfg(not(feature = "torrent-engine"))]
    {
        let _ = target_bytes;
        r#"{"error":"torrent_engine_unavailable"}"#.into()
    }
}

fn torrent_stream_json(magnet: String, season: i32, episode: i32, file_idx: i32) -> String {
    #[cfg(feature = "torrent-engine")]
    {
        engine_torrent::torrent_stream_json(magnet, season, episode, file_idx)
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
        engine_torrent::torrent_list_files_json(magnet)
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
        engine_proxy::proxy_start(&RUNTIME, preferred_port.min(u16::MAX as u32) as u16)
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
        engine_proxy::proxy_port() as u32
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        0
    }
}

fn proxy_register_route(token: String, upstream_url: String) -> bool {
    #[cfg(feature = "local-proxy")]
    {
        engine_proxy::proxy_register_route(&RUNTIME, token, upstream_url)
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        let _ = (token, upstream_url);
        false
    }
}

fn lan_server_start(bind_mode: u8, preferred_port: u32) -> i32 {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_server_start(
            &RUNTIME,
            bind_mode,
            preferred_port.min(u16::MAX as u32) as u16,
        )
    }
    #[cfg(not(feature = "lan-server"))]
    {
        let _ = (bind_mode, preferred_port);
        -1
    }
}

fn lan_server_last_error() -> String {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_server_last_error()
    }
    #[cfg(not(feature = "lan-server"))]
    {
        "lan-server feature disabled".into()
    }
}

fn lan_server_stop() {
    #[cfg(feature = "lan-server")]
    engine_lan::lan_server_stop(&RUNTIME);
}

fn lan_server_port() -> u32 {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_server_port() as u32
    }
    #[cfg(not(feature = "lan-server"))]
    {
        0
    }
}

fn lan_pairing_code_refresh() -> String {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_pairing_code_refresh()
    }
    #[cfg(not(feature = "lan-server"))]
    {
        String::new()
    }
}

fn lan_pairing_code() -> String {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_pairing_code()
    }
    #[cfg(not(feature = "lan-server"))]
    {
        String::new()
    }
}

fn lan_revoke_device(device_id: String) -> bool {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_revoke_device(device_id)
    }
    #[cfg(not(feature = "lan-server"))]
    {
        let _ = device_id;
        false
    }
}

fn lan_devices_json() -> String {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_devices_json()
    }
    #[cfg(not(feature = "lan-server"))]
    {
        "[]".into()
    }
}

fn lan_torrent_history_json() -> String {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_torrent_history_json()
    }
    #[cfg(not(feature = "lan-server"))]
    {
        "[]".into()
    }
}

fn lan_remove_torrent_history(info_hash: String) -> bool {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_remove_torrent_history(info_hash)
    }
    #[cfg(not(feature = "lan-server"))]
    {
        let _ = info_hash;
        false
    }
}

fn lan_clear_torrent_history() -> bool {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_clear_torrent_history()
    }
    #[cfg(not(feature = "lan-server"))]
    {
        false
    }
}

fn lan_browse_servers_json(timeout_ms: u64) -> String {
    #[cfg(feature = "lan-server")]
    {
        engine_lan::lan_browse_servers_json(timeout_ms)
    }
    #[cfg(not(feature = "lan-server"))]
    {
        let _ = timeout_ms;
        "[]".into()
    }
}

fn seek111477_start_json(json: String) -> String {
    #[cfg(feature = "local-proxy")]
    {
        engine_seek111477::seek111477_start(&RUNTIME, json)
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        let _ = json;
        r#"{"error":"local_proxy_unavailable"}"#.into()
    }
}

fn seek111477_stop() {
    #[cfg(feature = "local-proxy")]
    engine_seek111477::seek111477_stop(&RUNTIME);
}

fn seek111477_port() -> u32 {
    #[cfg(feature = "local-proxy")]
    {
        engine_seek111477::seek111477_port() as u32
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        0
    }
}

fn seek111477_is_running() -> bool {
    #[cfg(feature = "local-proxy")]
    {
        engine_seek111477::seek111477_is_running()
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        false
    }
}

fn seek111477_purge_cache_json(cache_dir: String) -> String {
    #[cfg(feature = "local-proxy")]
    {
        engine_seek111477::seek111477_purge_cache(&RUNTIME, cache_dir)
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        let _ = cache_dir;
        r#"{"error":"local_proxy_unavailable"}"#.into()
    }
}

fn site111477_index_request_json(json: String) -> String {
    #[cfg(feature = "local-proxy")]
    {
        proxy::index111477::request_json_blocking(&json)
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        let _ = json;
        r#"{"error":"local_proxy_unavailable"}"#.into()
    }
}

fn mega_resolve_json(embed_url: String) -> String {
    #[cfg(feature = "local-proxy")]
    {
        engine_mega::mega_resolve_json(&RUNTIME, embed_url)
    }
    #[cfg(not(feature = "local-proxy"))]
    {
        let _ = embed_url;
        r#"{"url":null,"size":null,"error":"local_proxy_unavailable"}"#.into()
    }
}

fn provider_health_json(payload_json: String) -> String {
    resolver_engine::provider_health_json(&payload_json)
}

fn storage_open(path: String) -> String {
    match storage::open(&path) {
        Ok(()) => r#"{"ok":true}"#.into(),
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}

fn storage_get_json(key: String) -> String {
    match storage::get(&key) {
        Some(v) => serde_json::to_string(&v).unwrap_or_else(|_| "null".into()),
        None => "null".into(),
    }
}

fn storage_set_json(key: String, value_json: String) -> String {
    let value: serde_json::Value = match serde_json::from_str(&value_json) {
        Ok(v) => v,
        Err(e) => return serde_json::json!({ "error": e.to_string() }).to_string(),
    };
    match storage::set(&key, value) {
        Ok(()) => r#"{"ok":true}"#.into(),
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}
