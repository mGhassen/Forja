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
template_provider!(VidfastProvider, "vidfast");
template_provider!(TwoEmbedProvider, "2embed");
template_provider!(SuperembedProvider, "superembed");
template_provider!(AutoembedProvider, "autoembed");
template_provider!(VidloveProvider, "vidlove");
template_provider!(VidsrcsbsProvider, "vidsrcsbs");
template_provider!(Movies111Provider, "111movies");
template_provider!(MoviesapiProvider, "moviesapi");
template_provider!(SmashystreamProvider, "smashystream");
template_provider!(PrimewireProvider, "primewire");

#[cfg(test)]
mod tests {
    use super::*;
    use stream_core::list_providers;

    #[test]
    fn every_stream_core_template_has_host_plugin() {
        let plugins: Vec<Box<dyn Provider>> = vec![
            Box::new(VidlinkProvider),
            Box::new(VixsrcProvider),
            Box::new(VidnestProvider),
            Box::new(VidzeeProvider),
            Box::new(VidrockProvider),
            Box::new(VidfastProvider),
            Box::new(TwoEmbedProvider),
            Box::new(SuperembedProvider),
            Box::new(AutoembedProvider),
            Box::new(VidloveProvider),
            Box::new(VidsrcsbsProvider),
            Box::new(Movies111Provider),
            Box::new(MoviesapiProvider),
            Box::new(SmashystreamProvider),
            Box::new(PrimewireProvider),
        ];
        let ids: std::collections::HashSet<&str> =
            plugins.iter().map(|p| p.id()).collect();
        for def in list_providers() {
            if !def.has_movie_template && !def.has_tv_template {
                continue;
            }
            assert!(
                ids.contains(def.id.as_str()),
                "missing HostRequired plugin for template provider {}",
                def.id
            );
            let plugin = plugins.iter().find(|p| p.id() == def.id).unwrap();
            assert_eq!(plugin.kind(), ProviderKind::HostRequired);
        }
    }

    #[test]
    fn vidfast_movie_returns_host_required_with_embed() {
        let ctx = ResolverContext::default();
        let request = StreamRequest {
            domain: stream_core::SourceDomain::Movies,
            tmdb_id: 550,
            imdb_id: String::new(),
            title: String::new(),
            year: None,
            season: 0,
            episode: 0,
            media_type: "movie".into(),
            device: stream_core::DevicePlaybackCapabilities::default(),
            settings: Default::default(),
            providers_json: String::new(),
        };
        let err = VidfastProvider
            .resolve(&request, &ctx)
            .expect_err("template must defer to host sniff");
        match err {
            ProviderError::HostRequired(req) => {
                assert_eq!(req.provider_id, "vidfast");
                assert_eq!(
                    req.embed_url.as_deref(),
                    Some("https://vidfast.vc/movie/550?autoPlay=true")
                );
                assert!(req.payload_json.contains("embedUrl"));
            }
            other => panic!("expected HostRequired, got {other}"),
        }
    }
}
