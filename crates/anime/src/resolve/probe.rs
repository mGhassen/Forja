use std::collections::HashMap;

use crate::http;

/// Known anti-scraper / interstitial ad CDNs injected into anime HLS.
const AD_HOST_NEEDLES: &[&str] = &[
    "ibyteimg.com",
    "byteimg.com",
    "p16-ad-",
    "ad-site-i18n",
];

pub fn probe_stream_url(url: &str, headers: &HashMap<String, String>) -> bool {
    let url = url.trim();
    if url.is_empty() {
        return false;
    }

    if url.contains(".m3u8") {
        return probe_hls_playable(url, headers);
    }

    if let Ok(resp) = http::fetch_with_retries("HEAD", url, headers, None, None, false, 8, 0) {
        if (200..400).contains(&resp.status) {
            return true;
        }
    }

    let mut get_headers = headers.clone();
    get_headers.insert("Range".into(), "bytes=0-0".into());
    if let Ok(resp) = http::fetch_with_retries("GET", url, &get_headers, None, None, false, 8, 0) {
        return resp.status == 200 || resp.status == 206;
    }

    false
}

/// Master `#EXTM3U` alone is not enough — nekostream/vivibebe currently serve
/// valid masters whose media segments are PNG ads (ibyteimg). Probe the first
/// media URI after resolving one variant.
fn probe_hls_playable(url: &str, headers: &HashMap<String, String>) -> bool {
    let Ok(master) = http::fetch_with_retries("GET", url, headers, None, None, false, 8, 0) else {
        return false;
    };
    if master.status != 200 || !master.body.contains("#EXTM3U") {
        return false;
    }

    let media_playlist_url = first_media_playlist_url(url, &master.body).unwrap_or_else(|| url.to_string());
    let body = if media_playlist_url == url {
        master.body
    } else {
        let Ok(media) =
            http::fetch_with_retries("GET", &media_playlist_url, headers, None, None, false, 8, 0)
        else {
            return false;
        };
        if media.status != 200 || !media.body.contains("#EXTM3U") {
            return false;
        }
        media.body
    };

    let segs = media_segment_urls(&media_playlist_url, &body);
    if segs.is_empty() {
        // Master-only / event playlist with no segments yet — treat as openable.
        return !body.contains("#EXT-X-STREAM-INF");
    }

    let sample: Vec<&str> = segs.iter().take(4).map(|s| s.as_str()).collect();
    let mut checked = 0u32;
    let mut poisoned = 0u32;
    for seg in sample {
        // Always fetch — ibyteimg / nekostream hosts often wrap real MPEG-TS in PNG.
        match classify_segment_payload(seg, headers) {
            SegmentKind::Ad => {
                checked += 1;
                poisoned += 1;
            }
            SegmentKind::Video => {
                checked += 1;
            }
            SegmentKind::Unknown => {
                // Network blip — don't count against the stream.
            }
        }
    }

    if checked == 0 {
        // Could not sample — keep prior behavior (master looked fine).
        return true;
    }
    // Majority (or all) of sampled segments are ads/images → not playable.
    poisoned * 2 < checked
}

fn first_media_playlist_url(master_url: &str, body: &str) -> Option<String> {
    let lines: Vec<&str> = body.lines().collect();
    for i in 0..lines.len() {
        let line = lines[i].trim();
        if !line.starts_with("#EXT-X-STREAM-INF") {
            continue;
        }
        let next = lines.get(i + 1)?.trim();
        if next.is_empty() || next.starts_with('#') {
            continue;
        }
        return Some(resolve_playlist_uri(master_url, next));
    }
    None
}

fn media_segment_urls(playlist_url: &str, body: &str) -> Vec<String> {
    body.lines()
        .map(|l| l.trim())
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(|l| resolve_playlist_uri(playlist_url, l))
        .collect()
}

fn resolve_playlist_uri(base: &str, uri: &str) -> String {
    if uri.starts_with("http://") || uri.starts_with("https://") {
        return uri.to_string();
    }
    if uri.starts_with('/') {
        // Absolute path on same origin.
        if let Some(scheme_end) = base.find("://") {
            let rest = &base[scheme_end + 3..];
            if let Some(path_start) = rest.find('/') {
                return format!("{}{}", &base[..scheme_end + 3 + path_start], uri);
            }
            return format!("{base}{uri}");
        }
    }
    if let Some(slash) = base.rfind('/') {
        format!("{}{}", &base[..=slash], uri.trim_start_matches('/'))
    } else {
        uri.to_string()
    }
}

fn looks_like_ad_host(url: &str) -> bool {
    let host = url
        .strip_prefix("https://")
        .or_else(|| url.strip_prefix("http://"))
        .and_then(|rest| rest.split('/').next())
        .unwrap_or("")
        .to_ascii_lowercase();
    AD_HOST_NEEDLES.iter().any(|n| host.contains(n) || url.to_ascii_lowercase().contains(n))
}

enum SegmentKind {
    Video,
    Ad,
    Unknown,
}

/// Megaplay / nekostream wrap MPEG-TS in a PNG shell (ibyteimg). Probe must
/// fetch enough bytes to see TS after the wrapper — not treat as a pure ad.
fn png_wraps_mpeg_ts(bytes: &[u8]) -> bool {
    if bytes.len() < 16 || bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x47
    {
        return false;
    }
    if let Some(iend) = bytes.windows(4).position(|w| w == b"IEND") {
        let start = iend + 8;
        if start < bytes.len() {
            for p in start..bytes.len().saturating_sub(188) {
                if bytes[p] == 0x47 && bytes[p + 188] == 0x47 {
                    return true;
                }
            }
            if bytes[start..].iter().any(|&b| b == 0x47) {
                return true;
            }
        }
    }
    bytes.len() > 252 + 188 && bytes[252] == 0x47 && bytes[252 + 188] == 0x47
}

fn classify_segment_payload(url: &str, headers: &HashMap<String, String>) -> SegmentKind {
    // Need ≥ ~440 bytes to detect Megaplay's 252-byte PNG → TS wrap.
    let mut hdrs = headers.clone();
    hdrs.insert("Range".into(), "bytes=0-1023".into());
    let Ok(resp) = http::fetch_with_retries("GET", url, &hdrs, None, None, true, 8, 0) else {
        return SegmentKind::Unknown;
    };
    if !(resp.status == 200 || resp.status == 206) {
        return SegmentKind::Unknown;
    }

    use base64::Engine;
    let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(resp.body_base64.as_bytes())
    else {
        return SegmentKind::Unknown;
    };

    // PNG-wrapped TS (ibyteimg / nekostream redirect) is playable via hls-proxy strip.
    if png_wraps_mpeg_ts(&bytes) {
        return SegmentKind::Video;
    }

    if looks_like_ad_host(&resp.final_url) || looks_like_ad_host(url) {
        return SegmentKind::Ad;
    }
    let ct = resp
        .headers
        .get("content-type")
        .map(|s| s.to_ascii_lowercase())
        .unwrap_or_default();
    if ct.starts_with("image/") {
        return SegmentKind::Ad;
    }
    if bytes.len() >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47
    {
        return SegmentKind::Ad;
    }
    if bytes.len() >= 3 && &bytes[0..3] == b"GIF" {
        return SegmentKind::Ad;
    }
    if bytes.len() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8 {
        return SegmentKind::Ad;
    }
    // MPEG-TS sync / fMP4 / WebVTT-ish — accept as video-ish.
    if !bytes.is_empty() && (bytes[0] == 0x47 || bytes.windows(4).any(|w| w == b"ftyp")) {
        return SegmentKind::Video;
    }
    if ct.contains("video") || ct.contains("mpegurl") || ct.contains("mp2t") || ct.contains("octet-stream")
    {
        return SegmentKind::Video;
    }
    SegmentKind::Unknown
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_url_not_reachable() {
        assert!(!probe_stream_url("", &HashMap::new()));
    }

    #[test]
    fn ad_host_detection() {
        assert!(looks_like_ad_host(
            "https://p16-ad-sg.ibyteimg.com/obj/ad-site-i18n/abc"
        ));
        assert!(!looks_like_ad_host(
            "https://9hjkrt.nekostream.site/segment/abc"
        ));
    }

    #[test]
    fn resolve_relative_segment() {
        let u = resolve_playlist_uri(
            "https://cdn.example/a/b/master.m3u8",
            "index-f1.m3u8",
        );
        assert_eq!(u, "https://cdn.example/a/b/index-f1.m3u8");
    }

    #[test]
    fn first_variant_from_master() {
        let body = r#"#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
index-f1.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000
index-f2.m3u8
"#;
        let u = first_media_playlist_url("https://cdn.example/x/master.m3u8", body).unwrap();
        assert_eq!(u, "https://cdn.example/x/index-f1.m3u8");
    }

    #[test]
    fn png_wrap_offset_252_detected() {
        let mut raw = vec![0x89, 0x50, 0x4E, 0x47];
        raw.extend(std::iter::repeat_n(0u8, 248));
        raw.push(0x47);
        raw.extend(std::iter::repeat_n(0u8, 187));
        raw.push(0x47);
        assert!(png_wraps_mpeg_ts(&raw));
    }

    #[test]
    fn pure_png_without_ts_not_wrapped() {
        let raw = vec![0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];
        assert!(!png_wraps_mpeg_ts(&raw));
    }

    #[test]
    #[ignore = "network — Megaplay PNG-wrapped nekostream HLS"]
    fn nekostream_png_wrap_live_accepted() {
        let url = "https://9hjkrt.nekostream.site/da9658912633e263254722493c6607b5/9aa1bc822e7ba3204431b520c369929e/master.m3u8";
        let mut h = HashMap::new();
        h.insert("User-Agent".into(), "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36".into());
        h.insert("Referer".into(), "https://megaplay.buzz/".into());
        h.insert("Origin".into(), "https://megaplay.buzz".into());
        assert!(
            probe_stream_url(url, &h),
            "PNG-wrapped MPEG-TS must pass probe (play via hls-proxy strip)"
        );
    }
}
