use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum Container {
    #[default]
    Unknown,
    Hls,
    Dash,
    Mp4,
    Mkv,
    Webm,
    Torrent,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum VideoCodec {
    #[default]
    Unknown,
    H264,
    H265,
    Vp9,
    Av1,
    Vp8,
    Mpeg4,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum AudioCodec {
    #[default]
    Unknown,
    Aac,
    Mp3,
    Ac3,
    Eac3,
    Opus,
    Flac,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum HdrFormat {
    #[default]
    None,
    Hdr10,
    Hlg,
    DolbyVision,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum EmbedKind {
    #[default]
    None,
    ArabicEmbed,
    LazyExtract,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct VideoTrack {
    pub codec: VideoCodec,
    pub width: u32,
    pub height: u32,
    pub bitrate_kbps: Option<u32>,
    pub hdr: HdrFormat,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct AudioTrack {
    pub codec: AudioCodec,
    pub channels: u8,
    pub language: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct SubtitleTrack {
    pub url: String,
    pub language: String,
    #[serde(default)]
    pub format: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct PlayableSource {
    pub url: String,
    pub title: String,
    pub container: Container,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub video: Option<VideoTrack>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub audio: Option<AudioTrack>,
    #[serde(default)]
    pub headers: HashMap<String, String>,
    #[serde(default)]
    pub subtitles: Vec<SubtitleTrack>,
    #[serde(default)]
    pub provider_id: String,
    #[serde(default)]
    pub provider_rank: u8,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub latency_ms: Option<u32>,
    #[serde(default)]
    pub requires_proxy: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub embed_kind: Option<EmbedKind>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub audio_url: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub score: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub baseline_rank: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub effective_rank: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub quality_score: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub provider_bonus: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct DevicePlaybackCapabilities {
    pub max_height: u32,
    pub hevc: bool,
    pub av1: bool,
    pub vp9: bool,
    pub hdr10: bool,
    pub dolby_vision: bool,
    pub is_low_power: bool,
    pub software_decode_allowed: bool,
    #[serde(default)]
    pub user_max_height: u32,
}

impl DevicePlaybackCapabilities {
    pub fn desktop_default() -> Self {
        Self {
            max_height: 2160,
            hevc: true,
            av1: true,
            vp9: true,
            hdr10: true,
            dolby_vision: true,
            is_low_power: false,
            software_decode_allowed: true,
            user_max_height: 0,
        }
    }

    pub fn constrained_default() -> Self {
        Self {
            max_height: 1080,
            hevc: false,
            av1: false,
            vp9: true,
            hdr10: false,
            dolby_vision: false,
            is_low_power: true,
            software_decode_allowed: false,
            user_max_height: 0,
        }
    }

    pub fn effective_max_height(&self) -> u32 {
        if self.user_max_height > 0 {
            self.user_max_height.min(self.max_height)
        } else {
            self.max_height
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct RankSourcesRequest {
    pub sources: Vec<PlayableSource>,
    #[serde(default)]
    pub device: DevicePlaybackCapabilities,
    #[serde(default)]
    pub blocklist: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RankSourcesResponse {
    pub sources: Vec<PlayableSource>,
}
