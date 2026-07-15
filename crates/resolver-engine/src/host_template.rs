//! Shared HostRequired resolve for `stream` template embed URLs.
//!
//! Each template provider under [`crate::plugins`] is a standalone file that
//! calls [`resolve_host_template`]. This module is not a provider.

use serde_json::json;

use crate::context::ResolverContext;
use crate::provider::ProviderError;
use crate::request::StreamRequest;
use crate::result::{HostResolveRequest, StreamResult};

/// Build the canonical embed URL and defer to Flutter WebView sniff.
pub fn resolve_host_template(
    provider_id: &str,
    request: &StreamRequest,
    ctx: &ResolverContext,
) -> Result<StreamResult, ProviderError> {
    let is_tv = request.media_type == "tv";
    let embed_url = if is_tv {
        stream::build_tv_url(
            provider_id,
            request.tmdb_id,
            request.season,
            request.episode,
        )
    } else {
        stream::build_movie_url(provider_id, request.tmdb_id)
    };
    let embed_url = embed_url.ok_or(ProviderError::NoStreams)?;
    let headers = ctx.headers.for_embed(provider_id, &embed_url);
    let payload = json!({
        "embedUrl": embed_url,
        "headers": headers,
        "providerId": provider_id,
    });
    Err(ProviderError::HostRequired(HostResolveRequest {
        provider_id: provider_id.to_string(),
        embed_url: Some(embed_url),
        payload_json: payload.to_string(),
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::provider::{Provider, ProviderKind};
    use stream::list_providers;

    #[test]
    fn every_stream_template_has_host_plugin() {
        let plugins: Vec<Box<dyn Provider>> = vec![
            Box::new(crate::plugins::vidlink::VidlinkProvider),
            Box::new(crate::plugins::vixsrc::VixsrcProvider),
            Box::new(crate::plugins::vidnest::VidnestProvider),
            Box::new(crate::plugins::vidzee::VidzeeProvider),
            Box::new(crate::plugins::vidrock::VidrockProvider),
            Box::new(crate::plugins::vidfast::VidfastProvider),
            Box::new(crate::plugins::two_embed::TwoEmbedProvider),
            Box::new(crate::plugins::autoembed::AutoembedProvider),
            Box::new(crate::plugins::vidlove::VidloveProvider),
            Box::new(crate::plugins::vidsrcsbs::VidsrcsbsProvider),
            Box::new(crate::plugins::vidsrcwin::VidsrcwinProvider),
            Box::new(crate::plugins::movies111::Movies111Provider),
            Box::new(crate::plugins::moviesapi::MoviesapiProvider),
        ];
        let ids: std::collections::HashSet<&str> = plugins.iter().map(|p| p.id()).collect();
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
            domain: stream::SourceDomain::Movies,
            tmdb_id: 550,
            imdb_id: String::new(),
            title: String::new(),
            year: None,
            season: 0,
            episode: 0,
            media_type: "movie".into(),
            device: stream::DevicePlaybackCapabilities::default(),
            settings: Default::default(),
            providers_json: String::new(),
        };
        let err = resolve_host_template("vidfast", &request, &ctx)
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
