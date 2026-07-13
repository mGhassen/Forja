use serde_json::json;

use crate::context::ResolverContext;
use crate::provider::{Provider, ProviderError, ProviderKind};
use crate::request::StreamRequest;
use crate::result::{HostResolveRequest, StreamResult};

/// Torrentio via Nuvio/Stremio host — resolves on host until dedicated Rust impl ships.
pub struct TorrentioProvider;

impl Provider for TorrentioProvider {
    fn id(&self) -> &str {
        "torrentio"
    }

    fn kind(&self) -> ProviderKind {
        ProviderKind::HostRequired
    }

    fn resolve(
        &self,
        request: &StreamRequest,
        _ctx: &ResolverContext,
    ) -> Result<StreamResult, ProviderError> {
        let payload = json!({
            "addon": "torrentio",
            "tmdbId": request.tmdb_id,
            "imdbId": request.imdb_id,
            "mediaType": request.media_type,
            "season": request.season,
            "episode": request.episode,
        });
        Err(ProviderError::HostRequired(HostResolveRequest {
            provider_id: self.id().to_string(),
            embed_url: None,
            payload_json: payload.to_string(),
        }))
    }
}
