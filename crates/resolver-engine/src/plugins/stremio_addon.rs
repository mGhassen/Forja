use serde_json::json;

use crate::context::ResolverContext;
use crate::provider::{Provider, ProviderError, ProviderKind};
use crate::request::StreamRequest;
use crate::result::{HostResolveRequest, StreamResult};

pub struct StremioAddonProvider;

impl Provider for StremioAddonProvider {
    fn id(&self) -> &str {
        "stremio_addon"
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
            "tmdbId": request.tmdb_id,
            "imdbId": request.imdb_id,
            "mediaType": request.media_type,
            "season": request.season,
            "episode": request.episode,
            "providersJson": request.providers_json,
        });
        Err(ProviderError::HostRequired(HostResolveRequest {
            provider_id: self.id().to_string(),
            embed_url: None,
            payload_json: payload.to_string(),
        }))
    }
}
