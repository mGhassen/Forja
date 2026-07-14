use crate::context::ResolverContext;
use crate::host_template::resolve_host_template;
use crate::provider::{Provider, ProviderError, ProviderKind};
use crate::request::StreamRequest;
use crate::result::StreamResult;

pub struct VidnestProvider;

impl Provider for VidnestProvider {
    fn id(&self) -> &str {
        "vidnest"
    }

    fn kind(&self) -> ProviderKind {
        ProviderKind::HostRequired
    }

    fn resolve(
        &self,
        request: &StreamRequest,
        ctx: &ResolverContext,
    ) -> Result<StreamResult, ProviderError> {
        resolve_host_template(self.id(), request, ctx)
    }
}
