use serde_json::json;

use crate::context::ResolverContext;
use crate::provider::{Provider, ProviderError, ProviderKind};
use crate::request::StreamRequest;
use crate::result::{HostResolveRequest, StreamResult};

pub struct Service111477Provider;

impl Provider for Service111477Provider {
    fn id(&self) -> &str {
        "service111477"
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
            "title": request.title,
            "year": request.year,
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
