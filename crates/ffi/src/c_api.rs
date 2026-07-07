//! Stable C ABI for Dart `dart:ffi` bindings.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

fn to_c_string(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

unsafe fn from_c_str(ptr: *const c_char) -> String {
    if ptr.is_null() {
        return String::new();
    }
    CStr::from_ptr(ptr).to_string_lossy().into_owned()
}

#[no_mangle]
pub unsafe extern "C" fn ffi_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        let _ = CString::from_raw(ptr);
    }
}

#[no_mangle]
pub extern "C" fn ffi_version() -> *mut c_char {
    to_c_string(env!("CARGO_PKG_VERSION").to_string())
}

#[no_mangle]
pub extern "C" fn ffi_engine_cancel_pending() {
    crate::engine_cancel_pending();
}

#[no_mangle]
pub unsafe extern "C" fn ffi_engine_submit_job(kind: u32, payload_json: *const c_char) -> u64 {
    crate::engine_submit_job(kind, from_c_str(payload_json))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_engine_take_job_result(job_id: u64) -> *mut c_char {
    match crate::engine_take_job_result(job_id) {
        Some(s) => to_c_string(s),
        None => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn ffi_add(a: i64, b: i64) -> i64 {
    crate::add(a, b)
}

#[no_mangle]
pub unsafe extern "C" fn ffi_episode_matches(
    filename: *const c_char,
    season: i32,
    episode: i32,
) -> bool {
    crate::episode_matches(from_c_str(filename), season, episode)
}

#[no_mangle]
pub unsafe extern "C" fn ffi_pick_episode_index_json(
    files_json: *const c_char,
    season: i32,
    episode: i32,
) -> i32 {
    crate::pick_episode_index_json(from_c_str(files_json), season, episode)
}

#[no_mangle]
pub unsafe extern "C" fn ffi_pick_largest_video_index_json(
    files_json: *const c_char,
) -> i32 {
    crate::pick_largest_video_index_json(from_c_str(files_json))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_normalize_torrent_title(title: *const c_char) -> *mut c_char {
    to_c_string(crate::normalize_torrent_title(from_c_str(title)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_unpack_js(source: *const c_char) -> *mut c_char {
    to_c_string(crate::unpack_js(from_c_str(source)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_build_movie_url(
    provider_id: *const c_char,
    tmdb_id: i64,
) -> *mut c_char {
    to_c_string(crate::build_movie_url(from_c_str(provider_id), tmdb_id))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_build_tv_url(
    provider_id: *const c_char,
    tmdb_id: i64,
    season: i32,
    episode: i32,
) -> *mut c_char {
    to_c_string(crate::build_tv_url(
        from_c_str(provider_id),
        tmdb_id,
        season,
        episode,
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_list_providers_json() -> *mut c_char {
    to_c_string(crate::list_providers_json())
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_m3u_json(content: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_m3u_json(from_c_str(content)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_decrypt_paste_response(
    url_with_hash: *const c_char,
    raw_response: *const c_char,
) -> *mut c_char {
    to_c_string(crate::decrypt_paste_response(
        from_c_str(url_with_hash),
        from_c_str(raw_response),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_openssl_aes_decrypt_json(
    b64: *const c_char,
    passphrase: *const c_char,
) -> *mut c_char {
    to_c_string(crate::openssl_aes_decrypt_json(
        from_c_str(b64),
        from_c_str(passphrase),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_decode_xtream_text(text: *const c_char) -> *mut c_char {
    to_c_string(crate::decode_xtream_text(from_c_str(text)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_xtream_categories_json(json: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_xtream_categories_json(from_c_str(json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_xtream_streams_json(
    json: *const c_char,
    section: *const c_char,
) -> *mut c_char {
    to_c_string(crate::parse_xtream_streams_json(
        from_c_str(json),
        from_c_str(section),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_xtream_series_episodes_json(
    json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::parse_xtream_series_episodes_json(from_c_str(json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_scene_info_json(title: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_scene_info_json(from_c_str(title)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_hls_master_json(
    master_url: *const c_char,
    body: *const c_char,
) -> *mut c_char {
    to_c_string(crate::parse_hls_master_json(
        from_c_str(master_url),
        from_c_str(body),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_decrypt_kisskh_body(
    body: *const c_char,
    source_url: *const c_char,
) -> *mut c_char {
    let url = if source_url.is_null() {
        None
    } else {
        let s = from_c_str(source_url);
        if s.is_empty() { None } else { Some(s) }
    };
    to_c_string(crate::decrypt_kisskh_body(from_c_str(body), url))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_build_stremio_resource_url(
    addon_url: *const c_char,
    resource_path: *const c_char,
) -> *mut c_char {
    to_c_string(crate::build_stremio_resource_url(
        from_c_str(addon_url),
        from_c_str(resource_path),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_normalize_stremio_manifest_url(url: *const c_char) -> *mut c_char {
    to_c_string(crate::normalize_stremio_manifest_url(from_c_str(url)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_split_stremio_addon_url_json(url: *const c_char) -> *mut c_char {
    to_c_string(crate::split_stremio_addon_url_json(from_c_str(url)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_stremio_manifest_json(json: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_stremio_manifest_json(from_c_str(json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_stremio_streams_json(json: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_stremio_streams_json(from_c_str(json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_stremio_subtitles_json(json: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_stremio_subtitles_json(from_c_str(json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_stremio_catalog_json(json: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_stremio_catalog_json(from_c_str(json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_stremio_meta_json(json: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_stremio_meta_json(from_c_str(json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_stremio_http_get_json(
    url: *const c_char,
    timeout_secs: u64,
) -> *mut c_char {
    to_c_string(crate::stremio_http_get_json(from_c_str(url), timeout_secs))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_http_get_json(
    url: *const c_char,
    timeout_secs: u64,
    headers_json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::http_get_json(
        from_c_str(url),
        timeout_secs,
        from_c_str(headers_json),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_http_post_json(
    url: *const c_char,
    timeout_secs: u64,
    headers_json: *const c_char,
    body: *const c_char,
) -> *mut c_char {
    to_c_string(crate::http_post_json(
        from_c_str(url),
        timeout_secs,
        from_c_str(headers_json),
        from_c_str(body),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_iptv_probe_stream_json(
    url: *const c_char,
    timeout_secs: u64,
) -> *mut c_char {
    to_c_string(crate::iptv_probe_stream_json(
        from_c_str(url),
        timeout_secs,
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_tmdb_get_json(
    resource_path: *const c_char,
    timeout_secs: u64,
) -> *mut c_char {
    to_c_string(crate::tmdb_get_json(
        from_c_str(resource_path),
        timeout_secs,
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_trakt_request_json(
    request_json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::trakt_request_json(from_c_str(request_json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_jellyfin_request_json(
    request_json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::jellyfin_request_json(from_c_str(request_json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_anilist_query_json(
    query: *const c_char,
    variables_json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::anilist_query_json(
        from_c_str(query),
        from_c_str(variables_json),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_manga_fetch_html(
    url: *const c_char,
    headers_json: *const c_char,
    timeout_secs: u64,
) -> *mut c_char {
    to_c_string(crate::manga_fetch_html(
        from_c_str(url),
        from_c_str(headers_json),
        timeout_secs,
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_anime_request_json(
    request_json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::anime_request_json(from_c_str(request_json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_knaben_html_json(html: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_knaben_html_json(from_c_str(html)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_tpb_html_json(html: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_tpb_html_json(from_c_str(html)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_uindex_html_json(html: *const c_char) -> *mut c_char {
    to_c_string(crate::parse_uindex_html_json(from_c_str(html)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_dedup_torrents_json(results_json: *const c_char) -> *mut c_char {
    to_c_string(crate::dedup_torrents_json(from_c_str(results_json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_search_torrents_json(query: *const c_char) -> *mut c_char {
    to_c_string(crate::search_torrents_json(from_c_str(query)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_filter_torrents_json(
    results_json: *const c_char,
    show_title: *const c_char,
    required_season: i32,
    required_episode: i32,
) -> *mut c_char {
    to_c_string(crate::filter_torrents_json(
        from_c_str(results_json),
        from_c_str(show_title),
        required_season,
        required_episode,
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_sort_torrents_json(
    results_json: *const c_char,
    preference: *const c_char,
) -> *mut c_char {
    to_c_string(crate::sort_torrents_json(
        from_c_str(results_json),
        from_c_str(preference),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_is_video_file(file_name: *const c_char) -> bool {
    crate::is_video_file(from_c_str(file_name))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_extract_embed_html_json(
    extractor_id: *const c_char,
    html: *const c_char,
    page_url: *const c_char,
) -> *mut c_char {
    to_c_string(crate::extract_embed_html_json(
        from_c_str(extractor_id),
        from_c_str(html),
        from_c_str(page_url),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_extract_vidsrc_chain_json(
    outer_html: *const c_char,
    rcp_html: *const c_char,
    prorcp_html: *const c_char,
) -> *mut c_char {
    to_c_string(crate::extract_vidsrc_chain_json(
        from_c_str(outer_html),
        from_c_str(rcp_html),
        from_c_str(prorcp_html),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_resolve_vidsrc_embed_json(
    request_json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::resolve_vidsrc_embed_json(from_c_str(request_json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_extract_hubcloud_links_json(
    html: *const c_char,
    page_url: *const c_char,
) -> *mut c_char {
    to_c_string(crate::extract_hubcloud_links_json(
        from_c_str(html),
        from_c_str(page_url),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_extract_mfp_embed_html_json(
    extractor_id: *const c_char,
    html: *const c_char,
    page_url: *const c_char,
    mfp_config_json: *const c_char,
    extra_html: *const c_char,
) -> *mut c_char {
    to_c_string(crate::extract_mfp_embed_html_json(
        from_c_str(extractor_id),
        from_c_str(html),
        from_c_str(page_url),
        from_c_str(mfp_config_json),
        from_c_str(extra_html),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_resolve_webstreamr_source_json(
    source_id: *const c_char,
    request_json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::resolve_webstreamr_source_json(
        from_c_str(source_id),
        from_c_str(request_json),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_extract_kinoger_episode_urls_json(
    html: *const c_char,
    season_index: i32,
    episode_index: i32,
) -> *mut c_char {
    to_c_string(crate::extract_kinoger_episode_urls_json(
        from_c_str(html),
        season_index,
        episode_index,
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_parse_webstreamr_source_html_json(
    source_id: *const c_char,
    html: *const c_char,
    opts_json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::parse_webstreamr_source_html_json(
        from_c_str(source_id),
        from_c_str(html),
        from_c_str(opts_json),
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_webstreamr_get_streams_json(
    request_json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::webstreamr_get_streams_json(from_c_str(request_json)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_torrent_start(magnet: *const c_char) -> bool {
    crate::torrent_start(from_c_str(magnet))
}

#[no_mangle]
pub extern "C" fn ffi_torrent_stop() {
    crate::torrent_stop();
}

#[no_mangle]
pub extern "C" fn ffi_torrent_is_running() -> bool {
    crate::torrent_is_running()
}

#[no_mangle]
pub extern "C" fn ffi_torrent_status_json() -> *mut c_char {
    to_c_string(crate::torrent_status_json())
}

#[no_mangle]
pub extern "C" fn ffi_torrent_engine_start(preferred_port: u16) -> i32 {
    crate::torrent_engine_start(preferred_port as u32)
}

#[no_mangle]
pub extern "C" fn ffi_torrent_engine_last_error() -> *mut c_char {
    to_c_string(crate::torrent_engine_last_error())
}

#[no_mangle]
pub extern "C" fn ffi_torrent_engine_port() -> u16 {
    crate::torrent_engine_port().min(u16::MAX as u32) as u16
}

#[no_mangle]
pub extern "C" fn ffi_torrent_engine_stop() {
    crate::torrent_engine_stop();
}

#[no_mangle]
pub extern "C" fn ffi_torrent_set_peer_limit(limit: u32) {
    crate::torrent_set_peer_limit(limit);
}

#[no_mangle]
pub unsafe extern "C" fn ffi_torrent_stream_json(
    magnet: *const c_char,
    season: i32,
    episode: i32,
    file_idx: i32,
) -> *mut c_char {
    to_c_string(crate::torrent_stream_json(
        from_c_str(magnet),
        season,
        episode,
        file_idx,
    ))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_torrent_list_files_json(magnet: *const c_char) -> *mut c_char {
    to_c_string(crate::torrent_list_files_json(from_c_str(magnet)))
}

#[no_mangle]
pub extern "C" fn ffi_proxy_start(preferred_port: u16) -> i32 {
    crate::proxy_start(preferred_port as u32)
}

#[no_mangle]
pub extern "C" fn ffi_proxy_stop() {
    crate::proxy_stop();
}

#[no_mangle]
pub extern "C" fn ffi_proxy_port() -> u16 {
    crate::proxy_port().min(u16::MAX as u32) as u16
}

#[no_mangle]
pub unsafe extern "C" fn ffi_proxy_register_route(
    token: *const c_char,
    upstream_url: *const c_char,
) -> bool {
    crate::proxy_register_route(from_c_str(token), from_c_str(upstream_url))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_seek111477_start_json(json: *const c_char) -> *mut c_char {
    to_c_string(crate::seek111477_start_json(from_c_str(json)))
}

#[no_mangle]
pub extern "C" fn ffi_seek111477_stop() {
    crate::seek111477_stop();
}

#[no_mangle]
pub extern "C" fn ffi_seek111477_port() -> u32 {
    crate::seek111477_port()
}

#[no_mangle]
pub extern "C" fn ffi_seek111477_is_running() -> bool {
    crate::seek111477_is_running()
}

#[no_mangle]
pub unsafe extern "C" fn ffi_seek111477_purge_cache_json(cache_dir: *const c_char) -> *mut c_char {
    to_c_string(crate::seek111477_purge_cache_json(from_c_str(cache_dir)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_storage_open(path: *const c_char) -> *mut c_char {
    to_c_string(crate::storage_open(from_c_str(path)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_storage_get_json(key: *const c_char) -> *mut c_char {
    to_c_string(crate::storage_get_json(from_c_str(key)))
}

#[no_mangle]
pub unsafe extern "C" fn ffi_storage_set_json(
    key: *const c_char,
    value_json: *const c_char,
) -> *mut c_char {
    to_c_string(crate::storage_set_json(
        from_c_str(key),
        from_c_str(value_json),
    ))
}
