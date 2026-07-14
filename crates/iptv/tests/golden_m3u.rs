use iptv::m3u;
use std::fs;
use std::path::PathBuf;

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

#[test]
fn basic_playlist_golden() {
    let content = fs::read_to_string(fixture("basic.m3u")).unwrap();
    let channels = m3u::parse(&content).unwrap();
    assert_eq!(channels.len(), 1);
    assert_eq!(channels[0].name, "News HD");
    assert_eq!(channels[0].group, "News");
    assert_eq!(channels[0].tvg_id, "ch1");
    assert_eq!(channels[0].url, "http://stream.example/live");
}

#[test]
fn crlf_extgrp_golden() {
    let content = fs::read_to_string(fixture("crlf_extgrp.m3u")).unwrap();
    let channels = m3u::parse(&content).unwrap();
    assert_eq!(channels.len(), 2);
    assert_eq!(channels[0].name, "Sports One");
    assert_eq!(channels[0].group, "Sports");
    assert_eq!(channels[1].name, "Sports Two");
    assert_eq!(channels[1].group, "OverrideGroup");
    assert_eq!(channels[1].url, "https://stream.example/sports2");
}

#[test]
fn extgrp_before_extinf_documents_dart_behavior() {
    let content = fs::read_to_string(fixture("extgrp_before_extinf.m3u")).unwrap();
    let channels = m3u::parse(&content).unwrap();
    assert_eq!(channels.len(), 2);
    assert_eq!(channels[0].group, "FromExtgrp");
    // #EXTGRP before #EXTINF without group-title: EXTINF clears pending group in Dart too.
    assert_eq!(channels[1].group, "");
}

#[test]
fn rejects_empty_playlist() {
    let err = m3u::parse("").unwrap_err();
    assert!(err.to_string().contains("empty"));
}
