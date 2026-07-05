use forja_utils::{episode_matcher, hls_parser, torrent_filter};
use serde::Deserialize;
use std::fs;
use std::path::PathBuf;

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

#[derive(Deserialize)]
struct EpisodeCase {
    file: String,
    season: i32,
    episode: i32,
    expected: bool,
}

#[derive(Deserialize)]
struct EpisodePickCase {
    files: Vec<String>,
    season: i32,
    episode: i32,
    expected_index: usize,
}

#[test]
fn episode_matcher_golden() {
    let raw = fs::read_to_string(fixture("episode_matcher.json")).unwrap();
    let cases: Vec<EpisodeCase> = serde_json::from_str(&raw).unwrap();
    assert!(cases.len() >= 5, "need multiple golden cases");
    for case in cases {
        assert_eq!(
            episode_matcher::matches(&case.file, case.season, case.episode),
            case.expected,
            "file={} s{}e{}",
            case.file,
            case.season,
            case.episode
        );
    }
}

#[test]
fn episode_matcher_pick_golden() {
    let raw = fs::read_to_string(fixture("episode_matcher_pick.json")).unwrap();
    let cases: Vec<EpisodePickCase> = serde_json::from_str(&raw).unwrap();
    for case in cases {
        let idx = episode_matcher::pick_episode_index(&case.files, case.season, case.episode)
            .expect("pick index");
        assert_eq!(
            idx,
            case.expected_index,
            "files={:?} s{}e{}",
            case.files,
            case.season,
            case.episode
        );
    }
}

#[derive(Deserialize)]
struct TorrentCase {
    title: String,
    season: Option<i32>,
    episode: Option<i32>,
    #[serde(default)]
    is_season_pack: bool,
    #[serde(default)]
    is_multi_season: bool,
}

#[test]
fn torrent_filter_golden() {
    let raw = fs::read_to_string(fixture("torrent_filter.json")).unwrap();
    let cases: Vec<TorrentCase> = serde_json::from_str(&raw).unwrap();
    for case in cases {
        let info = torrent_filter::parse_scene_info(&case.title);
        assert_eq!(info.season, case.season, "title={}", case.title);
        assert_eq!(info.episode, case.episode, "title={}", case.title);
        if case.is_season_pack {
            assert!(info.is_season_pack, "title={}", case.title);
        }
        if case.is_multi_season {
            assert!(info.is_multi_season, "title={}", case.title);
        }
    }
}

#[test]
fn hls_master_golden() {
    let body = fs::read_to_string(fixture("hls_master.m3u8")).unwrap();
    let qualities = hls_parser::parse_hls_master("https://cdn.example/master.m3u8", &body)
        .expect("master playlist");
    assert!(qualities.len() >= 3);
    assert!(qualities[0].is_auto);
    assert!(qualities.iter().any(|q| q.label == "1080p"));
    assert!(qualities
        .iter()
        .any(|q| q.url.contains("1080p/index.m3u8")));
}
