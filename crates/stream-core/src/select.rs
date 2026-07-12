use crate::normalize;
use crate::playable::{
    DevicePlaybackCapabilities, PlayableSource, RankSourcesRequest, RankSourcesResponse,
    VideoCodec,
};

/// Provider-tier bonus per rank step (lower effective rank = higher bonus).
pub const PROVIDER_BONUS_PER_RANK: f64 = 0.5;

fn device_supports_codec(device: &DevicePlaybackCapabilities, codec: VideoCodec) -> bool {
    match codec {
        VideoCodec::H264 | VideoCodec::Vp8 | VideoCodec::Mpeg4 | VideoCodec::Unknown => true,
        VideoCodec::H265 => device.hevc,
        VideoCodec::Av1 => device.av1,
        VideoCodec::Vp9 => device.vp9,
    }
}

fn quality_score(source: &PlayableSource, device: &DevicePlaybackCapabilities) -> f64 {
    let mut score = 0.0;

    let height = source
        .video
        .as_ref()
        .map(|v| v.height)
        .unwrap_or(1080);
    let codec = source
        .video
        .as_ref()
        .map(|v| v.codec)
        .unwrap_or(VideoCodec::Unknown);

    let max_h = device.effective_max_height();
    let effective_height = if height == 0 { 1080 } else { height };

    if effective_height <= max_h {
        score += (effective_height as f64 / max_h as f64) * 40.0;
    } else {
        score -= 30.0;
    }

    if device_supports_codec(device, codec) {
        score += 25.0;
        if codec == VideoCodec::H264 {
            score += if device.is_low_power { 15.0 } else { 5.0 };
        }
    } else {
        score -= 50.0;
    }

    if matches!(source.container, crate::playable::Container::Hls) {
        score += 5.0;
    }

    if let Some(ms) = source.latency_ms {
        if ms < 100 {
            score += 10.0;
        } else if ms < 300 {
            score += 5.0;
        } else if ms > 1000 {
            score -= 10.0;
        }
    }

    if codec == VideoCodec::H265 && device.is_low_power && !device.hevc {
        score -= 40.0;
    }

    score
}

fn provider_bonus(rank: u8) -> f64 {
    (255u32.saturating_sub(rank as u32)) as f64 * PROVIDER_BONUS_PER_RANK
}

pub fn rank_sources(request: RankSourcesRequest) -> RankSourcesResponse {
    let blocklist: std::collections::HashSet<&str> = request
        .blocklist
        .iter()
        .map(|s| s.as_str())
        .collect();

    let mut scored: Vec<PlayableSource> = request
        .sources
        .into_iter()
        .filter(|s| !s.url.trim().is_empty() && !blocklist.contains(s.url.as_str()))
        .map(|mut s| {
            let quality = quality_score(&s, &request.device);
            let bonus = provider_bonus(s.provider_rank);
            s.quality_score = Some(quality);
            s.provider_bonus = Some(bonus);
            s.score = Some(quality + bonus);
            s
        })
        .collect();

    scored.sort_by(|a, b| {
        let ra = a.provider_rank;
        let rb = b.provider_rank;
        if ra != rb {
            return ra.cmp(&rb);
        }
        let qa = a.quality_score.unwrap_or(0.0);
        let qb = b.quality_score.unwrap_or(0.0);
        qb.partial_cmp(&qa).unwrap_or(std::cmp::Ordering::Equal)
    });

    let mut seen = std::collections::HashSet::new();
    scored.retain(|s| seen.insert(s.url.clone()));

    RankSourcesResponse { sources: scored }
}

pub fn rank_sources_json(payload_json: &str) -> String {
    let request: RankSourcesRequest = match serde_json::from_str(payload_json) {
        Ok(r) => r,
        Err(e) => {
            return serde_json::json!({ "error": e.to_string() }).to_string();
        }
    };
    let response = rank_sources(request);
    serde_json::to_string(&response).unwrap_or_else(|e| {
        serde_json::json!({ "error": e.to_string() }).to_string()
    })
}

pub fn normalize_legacy_json(payload_json: &str) -> String {
    #[derive(serde::Deserialize)]
    struct LegacyItem {
        url: String,
        #[serde(default)]
        title: String,
        #[serde(rename = "type", default)]
        type_hint: String,
        #[serde(default)]
        headers: std::collections::HashMap<String, String>,
        #[serde(default)]
        provider_id: String,
        #[serde(default)]
        provider_rank: u8,
        #[serde(default)]
        baseline_rank: Option<u32>,
        #[serde(default)]
        effective_rank: Option<u32>,
    }
    #[derive(serde::Deserialize)]
    struct LegacyPayload {
        sources: Vec<LegacyItem>,
    }

    let payload: LegacyPayload = match serde_json::from_str(payload_json) {
        Ok(p) => p,
        Err(e) => return serde_json::json!({ "error": e.to_string() }).to_string(),
    };

    let sources: Vec<PlayableSource> = payload
        .sources
        .into_iter()
        .map(|item| {
            let mut source = normalize::from_legacy(
                &item.url,
                &if item.title.is_empty() {
                    "Unknown".into()
                } else {
                    item.title
                },
                &item.type_hint,
                item.headers,
                &item.provider_id,
                item.provider_rank,
            );
            source.baseline_rank = item.baseline_rank;
            source.effective_rank = item.effective_rank;
            source
        })
        .collect();

    serde_json::to_string(&sources).unwrap_or_else(|e| {
        serde_json::json!({ "error": e.to_string() }).to_string()
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::playable::{Container, DevicePlaybackCapabilities, PlayableSource, VideoTrack};

    fn sample(hevc: bool, height: u32, rank: u8) -> PlayableSource {
        PlayableSource {
            url: format!("https://cdn/{height}.m3u8"),
            title: format!("{height}p"),
            container: Container::Hls,
            video: Some(VideoTrack {
                codec: if hevc {
                    VideoCodec::H265
                } else {
                    VideoCodec::H264
                },
                width: 0,
                height,
                bitrate_kbps: None,
                hdr: Default::default(),
            }),
            provider_id: "test".into(),
            provider_rank: rank,
            ..Default::default()
        }
    }

    #[test]
    fn constrained_prefers_h264_1080_over_hevc_4k() {
        let device = DevicePlaybackCapabilities::constrained_default();
        let response = rank_sources(RankSourcesRequest {
            sources: vec![sample(true, 2160, 0), sample(false, 1080, 0)],
            device,
            blocklist: vec![],
        });
        assert_eq!(
            response.sources[0].video.as_ref().unwrap().codec,
            VideoCodec::H264
        );
        assert_eq!(response.sources[0].video.as_ref().unwrap().height, 1080);
    }

    #[test]
    fn blocklist_excludes_url() {
        let device = DevicePlaybackCapabilities::desktop_default();
        let response = rank_sources(RankSourcesRequest {
            sources: vec![sample(false, 1080, 0), sample(false, 720, 1)],
            device,
            blocklist: vec!["https://cdn/1080.m3u8".into()],
        });
        assert_eq!(response.sources.len(), 1);
        assert_eq!(response.sources[0].video.as_ref().unwrap().height, 720);
    }

    #[test]
    fn exposes_quality_and_provider_bonus() {
        let device = DevicePlaybackCapabilities::desktop_default();
        let response = rank_sources(RankSourcesRequest {
            sources: vec![sample(false, 1080, 0)],
            device,
            blocklist: vec![],
        });
        let source = &response.sources[0];
        assert!(source.quality_score.is_some());
        assert!(source.provider_bonus.is_some());
        assert_eq!(
            source.score.unwrap(),
            source.quality_score.unwrap() + source.provider_bonus.unwrap()
        );
    }

    #[test]
    fn provider_rank_tier_before_quality_within_tier() {
        let device = DevicePlaybackCapabilities::desktop_default();
        let response = rank_sources(RankSourcesRequest {
            sources: vec![sample(false, 720, 1), sample(false, 1080, 0)],
            device,
            blocklist: vec![],
        });
        assert_eq!(response.sources[0].provider_rank, 0);
        assert_eq!(response.sources[0].video.as_ref().unwrap().height, 1080);
    }
}
