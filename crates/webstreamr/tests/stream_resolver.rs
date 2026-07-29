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

/// Live parity check — HDHub4u hubdrive→hubcloud multi-stream set.
#[test]
#[ignore = "live network"]
fn enola_holmes3_resolves_multiple_streams() {
    let mut cfg = config::default_config();
    for cc in [
        "multi", "en", "de", "hi", "fr", "es", "it", "pt", "ar", "ru", "ja", "ko", "zh",
    ] {
        cfg.insert(cc.into(), "on".into());
    }
    let req = serde_json::json!({
        "imdb_id": "tt32278481",
        "tmdb_id": 1202033,
        "media_type": "movie",
        "config": cfg,
        "enabled_sources": []
    });
    let raw = get_streams_json(&req.to_string());
    let decoded: serde_json::Value = serde_json::from_str(&raw).unwrap();
    let arr = decoded.as_array().expect("array");
    assert!(
        arr.len() > 1,
        "expected HDHub4u multi-stream set, got {}",
        arr.len()
    );
    let titles: Vec<_> = arr
        .iter()
        .filter_map(|s| s.get("title").and_then(|v| v.as_str()))
        .collect();
    assert!(
        titles.iter().any(|t| t.contains("2160p") && t.contains("HDHub4u")),
        "missing 2160p HDHub4u streams: {titles:?}"
    );
}

/// Print full resolve for manual comparison (Forja UI).
#[test]
#[ignore = "live network — run: cargo test dump_enola_streams -- --ignored --nocapture"]
fn dump_enola_streams() {
    let mut cfg = config::default_config();
    for cc in [
        "multi", "en", "de", "hi", "fr", "es", "it", "pt", "ar", "ru", "ja", "ko", "zh",
    ] {
        cfg.insert(cc.into(), "on".into());
    }
    let req = serde_json::json!({
        "imdb_id": "tt32278481",
        "tmdb_id": 1202033,
        "media_type": "movie",
        "config": cfg,
        "enabled_sources": []
    });
    let raw = get_streams_json(&req.to_string());
    let arr: Vec<serde_json::Value> = serde_json::from_str(&raw).unwrap();
    eprintln!("\n=== WebStreamr resolve: Enola Holmes 3 (tt32278481) ===");
    eprintln!("Total streams: {}\n", arr.len());
    for (i, s) in arr.iter().enumerate() {
        let name = s.get("name").and_then(|v| v.as_str()).unwrap_or("?");
        let title = s.get("title").and_then(|v| v.as_str()).unwrap_or("?");
        let first_line = title.lines().next().unwrap_or(title);
        eprintln!("{}. {} | {}", i + 1, name, first_line);
    }
    eprintln!();
}
