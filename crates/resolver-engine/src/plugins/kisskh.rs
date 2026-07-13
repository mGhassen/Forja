use serde_json::json;

use crate::context::ResolverContext;
use crate::provider::{Provider, ProviderError, ProviderKind};
use crate::request::StreamRequest;
use crate::result::{HostResolveRequest, StreamResult};

pub struct KisskhProvider;

impl Provider for KisskhProvider {
    fn id(&self) -> &str {
        "kisskh"
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
            "season": request.season,
            "episode": request.episode,
            "domain": "asian_drama",
        });
        Err(ProviderError::HostRequired(HostResolveRequest {
            provider_id: self.id().to_string(),
            embed_url: None,
            payload_json: payload.to_string(),
        }))
    }
}
