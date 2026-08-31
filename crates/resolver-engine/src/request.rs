use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use stream::{DevicePlaybackCapabilities, SourceDomain};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ResolveSettings {
    #[serde(default)]
    pub enabled_provider_ids: Vec<String>,
    #[serde(default)]
    pub settings_order: Vec<String>,
    #[serde(default = "default_auto")]
    pub preferred: String,
    #[serde(default = "default_max_in_flight")]
    pub max_in_flight: u32,
    #[serde(default)]
    pub skip_host_on_tv: bool,
    #[serde(default)]
    pub blocklist_urls: Vec<String>,
    /// Legacy WebStreamr resolve knobs (ignored — provider archived).
    #[serde(default)]
    pub webstreamr_config: HashMap<String, String>,
    #[serde(default)]
    pub webstreamr_tmdb_access_token: String,
}

fn default_auto() -> String {
    "auto".into()
}

fn default_max_in_flight() -> u32 {
    2
}

impl Default for ResolveSettings {
    fn default() -> Self {
        Self {
            enabled_provider_ids: vec![],
            settings_order: vec![],
            preferred: default_auto(),
            max_in_flight: default_max_in_flight(),
            skip_host_on_tv: false,
            blocklist_urls: vec![],
            webstreamr_config: HashMap::new(),
            webstreamr_tmdb_access_token: String::new(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct StreamRequest {
    pub domain: SourceDomain,
    #[serde(default)]
    pub tmdb_id: i64,
    #[serde(default)]
    pub imdb_id: String,
    #[serde(default)]
    pub title: String,
    #[serde(default)]
    pub year: Option<i32>,
    #[serde(default)]
    pub season: i32,
    #[serde(default)]
    pub episode: i32,
    #[serde(default)]
    pub media_type: String,
    #[serde(default)]
    pub device: DevicePlaybackCapabilities,
    #[serde(default)]
    pub settings: ResolveSettings,
    #[serde(default)]
    pub providers_json: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct HostResolveResult {
    pub provider_id: String,
    pub sources_json: String,
    #[serde(default)]
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ContinueRequest {
    pub session_id: String,
    pub host_results: Vec<HostResolveResult>,
}
