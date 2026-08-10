use serde_json::json;

use crate::context::ResolverContext;
use crate::provider::{Provider, ProviderError, ProviderKind};
use crate::request::StreamRequest;
use crate::result::{HostResolveRequest, StreamResult};

/// VSEmbed (`vsembed.su`). Host fulfills: Rust HTML chain when it still works,
/// else WebView sniff of the live JS player (cloudorchestranova / vsdec).
pub struct VidsrcProvider;

impl Provider for VidsrcProvider {
    fn id(&self) -> &str {
        "vidsrc"
    }

    fn kind(&self) -> ProviderKind {
        ProviderKind::HostRequired
    }

    fn resolve(
        &self,
        request: &StreamRequest,
        _ctx: &ResolverContext,
    ) -> Result<StreamResult, ProviderError> {
        let is_tv = request.media_type == "tv";
        let payload = json!({
            "tmdbId": request.tmdb_id,
            "imdbId": request.imdb_id,
            "mediaType": request.media_type,
            "season": request.season,
            "episode": request.episode,
            "title": request.title,
            "isMovie": !is_tv,
        });
        Err(ProviderError::HostRequired(HostResolveRequest {
            provider_id: self.id().to_string(),
            embed_url: None,
            payload_json: payload.to_string(),
        }))
    }
}
