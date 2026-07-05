use forja_webstreamr::extract_embed_html;
use forja_webstreamr::types::StreamFormat;
use std::fs;
use std::path::PathBuf;

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

#[test]
fn streamembed_golden() {
    let html = fs::read_to_string(fixture("streamembed.html")).unwrap();
    let page_url = "https://bullstream.example/embed/xyz";
    let r = extract_embed_html("streamembed", &html, page_url).unwrap();
    assert_eq!(
        r.url,
        "https://bullstream.example/m3u8/abc123/deadbeef/master.txt?s=1&id=42&cache=ready"
    );
    assert_eq!(r.format, StreamFormat::Hls);
    assert_eq!(r.title.as_deref(), Some("Test Movie"));
    assert_eq!(r.height, Some(720));
}

#[test]
fn savefiles_golden() {
    let html = fs::read_to_string(fixture("savefiles.html")).unwrap();
    let r = extract_embed_html("savefiles", &html, "https://savefiles.example/v/1").unwrap();
    assert_eq!(r.url, "https://cdn.savefiles.example/playlist.m3u8");
    assert_eq!(r.title.as_deref(), Some("SaveFiles Title"));
    assert_eq!(r.height, Some(1080));
}

#[test]
fn dropload_golden() {
    let html = fs::read_to_string(fixture("dropload.html")).unwrap();
    let r = extract_embed_html("dropload", &html, "https://dropload.example/x").unwrap();
    assert_eq!(r.url, "https://cdn.dropload.example/master.m3u8");
    assert_eq!(r.title.as_deref(), Some("Dropload Title"));
    assert_eq!(r.height, Some(1080));
    assert_eq!(
        r.request_headers.as_ref().and_then(|h| h.get("Referer")).map(String::as_str),
        Some("https://dr0pstream.com/")
    );
}

#[test]
fn supervideo_golden() {
    let html = fs::read_to_string(fixture("supervideo.html")).unwrap();
    let r = extract_embed_html("supervideo", &html, "https://supervideo.cc/e/1").unwrap();
    assert_eq!(r.url, "https://cdn.supervideo.example/master.m3u8");
    assert_eq!(r.title.as_deref(), Some("SuperVideo Title"));
    assert_eq!(r.height, Some(1080));
}

#[test]
fn vidora_golden() {
    let html = fs::read_to_string(fixture("vidora.html")).unwrap();
    let page_url = "https://vidora.example/embed/1";
    let r = extract_embed_html("vidora", &html, page_url).unwrap();
    assert_eq!(r.url, "https://cdn.vidora.example/stream.m3u8");
    assert_eq!(r.title.as_deref(), Some("Vidora Title"));
    assert_eq!(
        r.request_headers.as_ref().and_then(|h| h.get("Origin")).map(String::as_str),
        Some("https://vidora.example")
    );
}

#[test]
fn unknown_extractor_returns_none() {
    assert!(extract_embed_html("mixdrop", "html", "https://x").is_none());
}
