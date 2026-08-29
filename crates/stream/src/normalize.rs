use std::collections::HashMap;

use crate::playable::{
    Container, EmbedKind, PlayableSource, VideoCodec, VideoTrack,
};

pub fn infer_container(type_hint: &str, url: &str) -> Container {
    let t = type_hint.to_lowercase();
    let u = url.to_lowercase();
    if t == "hls" || u.contains(".m3u8") {
        return Container::Hls;
    }
    if t == "dash" || u.contains(".mpd") {
        return Container::Dash;
    }
    if t == "mkv" || u.contains(".mkv") {
        return Container::Mkv;
    }
    if u.contains(".webm") {
        return Container::Webm;
    }
    if t == "mp4" || u.contains(".mp4") {
        return Container::Mp4;
    }
    if t == "torrent" {
        return Container::Torrent;
    }
    Container::Unknown
}

pub fn infer_video_codec(url: &str, title: &str) -> VideoCodec {
    let combined = format!("{} {}", url.to_lowercase(), title.to_lowercase());
    if combined.contains("av1") || combined.contains("/av01/") {
        return VideoCodec::Av1;
    }
    if combined.contains("vp9") || combined.contains("/vp9/") {
        return VideoCodec::Vp9;
    }
    if combined.contains("vp8") {
        return VideoCodec::Vp8;
    }
    if combined.contains("h265")
        || combined.contains("hevc")
        || combined.contains("/h265/")
        || combined.contains("x265")
    {
        return VideoCodec::H265;
    }
    if combined.contains("h264")
        || combined.contains("/h264/")
        || combined.contains("x264")
        || combined.contains("avc")
    {
        return VideoCodec::H264;
    }
    VideoCodec::Unknown
}

pub fn infer_height(url: &str, title: &str) -> u32 {
    let combined = format!("{} {}", url, title);
    for token in ["2160", "4k", "4320", "1440", "1080", "720", "480", "360"] {
        if combined.to_lowercase().contains(token) {
            return match token {
                "2160" | "4k" => 2160,
                "4320" => 4320,
                "1440" => 1440,
                "1080" => 1080,
                "720" => 720,
                "480" => 480,
                "360" => 360,
                _ => 0,
            };
        }
    }
    0
}

/// Raw a./p.111477 CDN file URLs need Forja's seek111477 localhost proxy.
/// Addon `workers.dev/d/…` URLs (st.111477) play direct — no proxy.
fn requires_seek_proxy(provider_id: &str, url: &str) -> bool {
    let _ = provider_id; // kept for call-site stability; host decides
    let lower = url.to_ascii_lowercase();
    let Some(rest) = lower.split("://").nth(1) else {
        return false;
    };
    let host = rest.split('/').next().unwrap_or("");
    let host = host.split('@').next_back().unwrap_or(host);
    let host = host.split(':').next().unwrap_or(host);
    host.contains("111477")
}

pub fn from_legacy(
    url: &str,
    title: &str,
    type_hint: &str,
    headers: HashMap<String, String>,
    provider_id: &str,
    provider_rank: u8,
) -> PlayableSource {
    let container = infer_container(type_hint, url);
    let codec = infer_video_codec(url, title);
    let height = infer_height(url, title);
    let embed_kind = if type_hint == "arabic_embed" {
        Some(EmbedKind::ArabicEmbed)
    } else {
        None
    };
    let requires_proxy = requires_seek_proxy(provider_id, url);

    PlayableSource {
        url: url.to_string(),
        title: title.to_string(),
        container,
        video: if height > 0 || codec != VideoCodec::Unknown {
            Some(VideoTrack {
                codec,
                width: 0,
                height,
                bitrate_kbps: None,
                hdr: Default::default(),
            })
        } else {
            None
        },
        audio: None,
        headers,
        subtitles: vec![],
        provider_id: provider_id.to_string(),
        provider_rank,
        latency_ms: None,
        requires_proxy,
        embed_kind,
        audio_url: None,
        score: None,
        baseline_rank: None,
        effective_rank: None,
        quality_score: None,
        provider_bonus: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn infers_hevc_from_url() {
        let s = from_legacy(
            "https://cdn/x/h265/1080.m3u8",
            "1080p",
            "hls",
            HashMap::new(),
            "videasy",
            0,
        );
        assert_eq!(s.video.as_ref().unwrap().codec, VideoCodec::H265);
        assert_eq!(s.video.as_ref().unwrap().height, 1080);
        assert_eq!(s.container, Container::Hls);
    }

    #[test]
    fn arabic_embed_flag() {
        let s = from_legacy(
            "https://embed.example/x",
            "Server 1",
            "arabic_embed",
            HashMap::new(),
            "arabic",
            1,
        );
        assert_eq!(s.embed_kind, Some(EmbedKind::ArabicEmbed));
    }

    #[test]
    fn seek_proxy_for_111477_host_only() {
        let by_id = from_legacy(
            "https://cdn.example/x.mkv",
            "1080p",
            "mkv",
            HashMap::new(),
            "engine:service111477",
            0,
        );
        assert!(!by_id.requires_proxy);

        let workers = from_legacy(
            "https://strem1o.example.workers.dev/d/abc",
            "1080p",
            "mkv",
            HashMap::new(),
            "service111477",
            0,
        );
        assert!(!workers.requires_proxy);

        let by_host = from_legacy(
            "https://a.111477.xyz/movies/x.mkv",
            "1080p",
            "mkv",
            HashMap::new(),
            "videasy",
            0,
        );
        assert!(by_host.requires_proxy);

        let plain = from_legacy(
            "https://cdn.example/x.m3u8",
            "1080p",
            "hls",
            HashMap::new(),
            "videasy",
            0,
        );
        assert!(!plain.requires_proxy);
    }
}
