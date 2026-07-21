use super::{SourceEmbed, SourceRequest};
use crate::types::MediaType;

/// MBG WebStreamr VidSrc source host (not VSEmbed / vsembed.su).
const BASE_URL: &str = "https://vidsrcme.ru";

fn base_url() -> String {
    utils::provider_runtime::webstreamr_base("vidsrc")
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| BASE_URL.to_string())
}

/// MBG shape: `/embed/movie/{id}` · `/embed/tv/{id}/{season}-{episode}` (IMDb preferred).
pub fn resolve(req: &SourceRequest) -> Vec<SourceEmbed> {
    let base = base_url().trim_end_matches('/').to_string();
    let id = req
        .imdb_id
        .as_deref()
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .or_else(|| req.tmdb_id.map(|t| t.to_string()));
    let Some(id) = id else {
        return Vec::new();
    };

    let url = match &req.media_type {
        MediaType::Movie => format!("{base}/embed/movie/{id}"),
        MediaType::Series => {
            let season = req.season.unwrap_or(1);
            let episode = req.episode.unwrap_or(1);
            format!("{base}/embed/tv/{id}/{season}-{episode}")
        }
    };
    vec![SourceEmbed {
        url,
        title: None,
        country_codes: vec!["multi".into()],
        referer: None,
        priority: None,
        height: None,
        bytes: None,
    }]
}
