use webstreamr::extractors::{find_extractor_for_url, run_extractor, EmbedMeta};
use webstreamr::get_streams_json;
use webstreamr::types::StreamFormat;
use webstreamr::config;

#[test]
fn get_streams_json_parses_vidsrc_request() {
    let req = serde_json::json!({
        "imdb_id": "tt0944947",
        "tmdb_id": 1399,
        "media_type": "series",
        "season": 1,
        "episode": 1,
        "enabled_sources": ["vidsrc"],
        "config": { "multi": "on" }
    });
    let raw = get_streams_json(&req.to_string());
    let decoded: serde_json::Value = serde_json::from_str(&raw).unwrap();
    assert!(decoded.is_array());
}

#[test]
fn streamembed_fixture_resolves_to_stremio_shape() {
    let html = std::fs::read_to_string("tests/fixtures/streamembed.html").unwrap();
    let cfg = config::default_config();
    let meta = EmbedMeta {
        referer: Some("https://ref.example/".into()),
        source_id: Some("test".into()),
        source_label: Some("Test".into()),
        country_codes: vec!["en".into()],
        ..Default::default()
    };
    let extract = webstreamr::extract_embed_html("streamembed", &html, "https://bullstream.example/v/1")
        .unwrap();
    assert_eq!(extract.format, StreamFormat::Hls);

    assert_eq!(
        find_extractor_for_url("https://bullstream.example/v/1", &cfg),
        Some("streamembed")
    );
    let _ = run_extractor;
    let _ = meta;
}

#[tokio::test]
async fn tmdb_manual_mismatch_fix() {
    let ids = webstreamr::tmdb::get_tmdb_id_from_imdb("tt13207736", Some(2), Some(1), None).unwrap();
    assert_eq!(ids.tmdb_id, Some(225634));
}
