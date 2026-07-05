use forja_webstreamr::extract_embed_html;
use forja_webstreamr::extract_hubcloud_links;
use forja_webstreamr::extract_mfp_embed_html;
use forja_webstreamr::types::StreamFormat;
use std::fs;
use std::path::PathBuf;

const MFP_CONFIG: &str =
    r#"{"base_url":"mfp.example","password":"pw","headers":{"Referer":"https://ref.example/"}}"#;

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

#[test]
fn fsst_golden() {
    let html = fs::read_to_string(fixture("fsst.html")).unwrap();
    let r = extract_embed_html("fsst", &html, "https://fsst.example/v/1").unwrap();
    assert_eq!(r.url, "https://cdn.fsst.example/video.mp4");
    assert_eq!(r.format, StreamFormat::Mp4);
    assert_eq!(r.title.as_deref(), Some("Fsst Movie"));
    assert_eq!(r.height, Some(1080));
}

#[test]
fn vixsrc_golden() {
    let html = fs::read_to_string(fixture("vixsrc.html")).unwrap();
    let page_url = "https://vixsrc.example/embed/1";
    let r = extract_embed_html("vixsrc", &html, page_url).unwrap();
    assert!(r.url.contains("stream.vixsrc.example"));
    assert!(r.url.contains(".m3u8"));
    assert!(r.url.contains("token=abc123"));
    assert_eq!(r.format, StreamFormat::Hls);
}

#[test]
fn youtube_golden() {
    let html = fs::read_to_string(fixture("youtube.html")).unwrap();
    let page_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";
    let r = extract_embed_html("youtube", &html, page_url).unwrap();
    assert_eq!(r.yt_id.as_deref(), Some("dQw4w9WgXcQ"));
    assert_eq!(r.title.as_deref(), Some("YouTube Title"));
    assert_eq!(r.format, StreamFormat::Unknown);
}

#[test]
fn vidsrc_chain_golden() {
    use forja_webstreamr::extract_vidsrc_chain_json;
    let outer = fs::read_to_string(fixture("vidsrc_outer.html")).unwrap();
    let rcp = fs::read_to_string(fixture("vidsrc_rcp.html")).unwrap();
    let prorcp = fs::read_to_string(fixture("vidsrc_prorcp.html")).unwrap();
    let json = extract_vidsrc_chain_json(&outer, &rcp, &prorcp);
    assert!(json.contains("cloudnestra.com/hls/movie.m3u8"));
}

#[test]
fn filemoon_iframe_golden() {
    let html = fs::read_to_string(fixture("filemoon_iframe.html")).unwrap();
    let r = extract_embed_html("filemoon", &html, "https://filemoon.example/d/1").unwrap();
    assert_eq!(
        r.next_url.as_deref(),
        Some("https://cdn.filemoon.example/embed/real")
    );
}

#[test]
fn hubdrive_golden() {
    let html = fs::read_to_string(fixture("hubdrive.html")).unwrap();
    let r = extract_embed_html("hubdrive", &html, "https://hubdrive.example/x").unwrap();
    assert_eq!(
        r.next_url.as_deref(),
        Some("https://hubcloud.example/links/1")
    );
}

#[test]
fn rgshows_golden() {
    let body = fs::read_to_string(fixture("rgshows.json")).unwrap();
    let r = extract_embed_html("rgshows", &body, "https://rgshows.example/api").unwrap();
    assert_eq!(r.url, "https://cdn.rgshows.example/master.m3u8");
    assert_eq!(r.format, StreamFormat::Hls);
}

#[test]
fn hubcloud_redirect_golden() {
    let html = fs::read_to_string(fixture("hubcloud_redirect.html")).unwrap();
    let r = extract_embed_html("hubcloud", &html, "https://hubcloud.example/x").unwrap();
    assert_eq!(
        r.next_url.as_deref(),
        Some("https://hubcloud.example/links/abc123")
    );
}

#[test]
fn hubcloud_links_golden() {
    let html = fs::read_to_string(fixture("hubcloud_links.html")).unwrap();
    let rows = extract_hubcloud_links(&html, "https://hubcloud.example/origin");
    assert_eq!(rows.len(), 3);
    assert_eq!(rows[0].url, "https://fsl.example/stream/1");
    assert_eq!(rows[0].label.as_deref(), Some("HubCloud (FSL)"));
    assert_eq!(rows[0].meta_extractor_id.as_deref(), Some("hubcloud_fsl"));
    assert_eq!(rows[0].height, Some(1080));
    assert_eq!(rows[0].bytes, Some(2_684_354_560));
    assert_eq!(rows[1].url, "https://fslv2.example/stream/2");
    assert_eq!(rows[2].url, "https://pixel.example/api/file/abc?download=");
    assert_eq!(
        rows[2].request_headers.as_ref().and_then(|h| h.get("Referer")).map(String::as_str),
        Some("https://pixel.example/u/abc")
    );
}

#[test]
fn mixdrop_mfp_golden() {
    let html = fs::read_to_string(fixture("mixdrop.html")).unwrap();
    let page_url = "https://mixdrop.example/e/abc";
    let r = extract_mfp_embed_html("mixdrop", &html, page_url, MFP_CONFIG, "").unwrap();
    assert!(r.url.contains("host=Mixdrop"));
    assert!(r.url.contains("redirect_stream=true"));
    assert_eq!(r.title.as_deref(), Some("Mixdrop Title"));
    assert_eq!(r.bytes, Some(1_610_612_736));
    assert_eq!(r.format, StreamFormat::Mp4);
}

#[test]
fn streamtape_mfp_golden() {
    let html = fs::read_to_string(fixture("streamtape.html")).unwrap();
    let page_url = "https://streamtape.example/v/abc";
    let r = extract_mfp_embed_html("streamtape", &html, page_url, MFP_CONFIG, "").unwrap();
    assert!(r.url.contains("host=Streamtape"));
    assert_eq!(r.title.as_deref(), Some("Streamtape Title"));
    assert_eq!(r.bytes, Some(1_288_490_189));
}

#[test]
fn uqload_mfp_golden() {
    let html = fs::read_to_string(fixture("uqload.html")).unwrap();
    let page_url = "https://uqload.example/embed-xyz";
    let r = extract_mfp_embed_html("uqload", &html, page_url, MFP_CONFIG, "").unwrap();
    assert!(r.url.contains("host=Uqload"));
    assert_eq!(r.title.as_deref(), Some("Uqload Title"));
    assert_eq!(r.height, Some(1080));
}

#[test]
fn doodstream_mfp_golden() {
    let embed = fs::read_to_string(fixture("doodstream_embed.html")).unwrap();
    let download = fs::read_to_string(fixture("doodstream_download.html")).unwrap();
    let page_url = "http://dood.to/e/abc";
    let r = extract_mfp_embed_html("doodstream", &embed, page_url, MFP_CONFIG, &download).unwrap();
    assert!(r.url.contains("host=Doodstream"));
    assert_eq!(r.title.as_deref(), Some("Movie Name"));
    assert_eq!(r.bytes, Some(1_932_735_283));
}

#[test]
fn external_golden() {
    let r = extract_embed_html("external", "", "https://example.com/page").unwrap();
    assert_eq!(r.url, "https://example.com/page");
    assert!(r.is_external);
}
