use forja_iptv_core::xtream;
use std::fs;
use std::path::PathBuf;

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

#[test]
fn xtream_categories_golden() {
    let json = fs::read_to_string(fixture("xtream_categories.json")).unwrap();
    let rows = xtream::parse_categories_rows(&json).unwrap();
    assert_eq!(rows.len(), 2);
    assert_eq!(rows[0].id, "1");
    assert_eq!(rows[0].name, "Sports");
}

#[test]
fn xtream_live_streams_golden() {
    let json = fs::read_to_string(fixture("xtream_live_streams.json")).unwrap();
    let rows = xtream::parse_streams_rows(&json, xtream::XtreamSection::Live).unwrap();
    assert_eq!(rows[0].stream_id, "42");
    assert_eq!(rows[0].name, "News HD");
    assert_eq!(rows[0].container_ext, "ts");
}
