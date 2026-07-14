use serde::{Deserialize, Serialize};
use stream::PlayableSource;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct StreamResult {
    pub provider_id: String,
    pub sources: Vec<PlayableSource>,
    #[serde(default)]
    pub latency_ms: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum ResolvePhase {
    AwaitingHost,
    Complete,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct HostResolveRequest {
    pub provider_id: String,
    #[serde(default)]
    pub embed_url: Option<String>,
    #[serde(default)]
    pub payload_json: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ResolveProgressEvent {
    pub provider_id: String,
    pub status: String,
    #[serde(default)]
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ResolveResponse {
    pub phase: ResolvePhase,
    #[serde(default)]
    pub session_id: String,
    #[serde(default)]
    pub winner: Option<PlayableSource>,
    #[serde(default)]
    pub sources: Vec<PlayableSource>,
    #[serde(default)]
    pub winner_provider_id: Option<String>,
    #[serde(default)]
    pub host_requests: Vec<HostResolveRequest>,
    #[serde(default)]
    pub progress: Vec<ResolveProgressEvent>,
    #[serde(default)]
    pub race_ms: u32,
    #[serde(default)]
    pub error: Option<String>,
}

impl ResolveResponse {
    pub fn failed(error: impl Into<String>) -> Self {
        Self {
            phase: ResolvePhase::Failed,
            error: Some(error.into()),
            ..Default::default()
        }
    }
}

impl Default for ResolveResponse {
    fn default() -> Self {
        Self {
            phase: ResolvePhase::Complete,
            session_id: String::new(),
            winner: None,
            sources: vec![],
            winner_provider_id: None,
            host_requests: vec![],
            progress: vec![],
            race_ms: 0,
            error: None,
        }
    }
}
