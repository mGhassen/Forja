use serde_json::json;

use crate::context::ResolverContext;
use crate::provider::{Provider, ProviderError, ProviderKind};
use crate::request::StreamRequest;
use crate::result::{HostResolveRequest, StreamResult};

pub struct NuvioProvider;

impl Provider for NuvioProvider {
    fn id(&self) -> &str {
        "nuvio"
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
            "title": request.title,
            "dynamic": true,
        });
        Err(ProviderError::HostRequired(HostResolveRequest {
            provider_id: "nuvio".into(),
            embed_url: None,
            payload_json: payload.to_string(),
        }))
    }
}
