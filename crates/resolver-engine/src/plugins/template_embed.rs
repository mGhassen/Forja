use serde_json::json;

use crate::context::ResolverContext;
use crate::provider::{Provider, ProviderError, ProviderKind};
use crate::request::StreamRequest;
use crate::result::{HostResolveRequest, StreamResult};

macro_rules! template_provider {
    ($struct_name:ident, $id:literal) => {
        pub struct $struct_name;

        impl Provider for $struct_name {
            fn id(&self) -> &str {
                $id
            }

            fn kind(&self) -> ProviderKind {
                ProviderKind::HostRequired
            }

            fn resolve(
                &self,
                request: &StreamRequest,
                ctx: &ResolverContext,
            ) -> Result<StreamResult, ProviderError> {
                let is_tv = request.media_type == "tv";
                let embed_url = if is_tv {
                    stream_core::build_tv_url(
                        self.id(),
                        request.tmdb_id,
                        request.season,
                        request.episode,
                    )
                } else {
                    stream_core::build_movie_url(self.id(), request.tmdb_id)
                };
                let embed_url = embed_url.ok_or(ProviderError::NoStreams)?;
                let headers = ctx.headers.for_embed(self.id(), &embed_url);
                let payload = json!({
                    "embedUrl": embed_url,
                    "headers": headers,
                    "providerId": self.id(),
                });
                Err(ProviderError::HostRequired(HostResolveRequest {
                    provider_id: self.id().to_string(),
                    embed_url: Some(embed_url),
                    payload_json: payload.to_string(),
                }))
            }
        }
    };
}

template_provider!(VidlinkProvider, "vidlink");
template_provider!(VixsrcProvider, "vixsrc");
template_provider!(VidnestProvider, "vidnest");
template_provider!(VidzeeProvider, "vidzee");
template_provider!(VidrockProvider, "vidrock");
