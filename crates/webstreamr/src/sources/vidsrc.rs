use super::{SourceEmbed, SourceRequest};
use crate::types::MediaType;

const BASE_URL: &str = "https://vsembed.su";

fn base_url() -> String {
    utils::provider_runtime::webstreamr_base("vidsrc")
        .or_else(|| utils::provider_runtime::api_base("vidsrcEmbed"))
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| BASE_URL.to_string())
}

pub fn resolve(req: &SourceRequest) -> Vec<SourceEmbed> {
    let base = base_url();
    let url = match (req.imdb_id.as_deref(), req.tmdb_id, &req.media_type) {
        (Some(imdb), _, MediaType::Movie) => format!("{base}/embed/{imdb}/"),
        (Some(imdb), _, MediaType::Series) => {
            let season = req.season.unwrap_or(1);
            let episode = req.episode.unwrap_or(1);
            format!("{base}/embed/{imdb}/{season}-{episode}/")
        }
        (_, Some(tmdb), MediaType::Movie) => {
            format!("{base}/embed/movie?tmdb={tmdb}")
        }
        (_, Some(tmdb), MediaType::Series) => {
            let season = req.season.unwrap_or(1);
            let episode = req.episode.unwrap_or(1);
            format!("{base}/embed/tv?tmdb={tmdb}&season={season}&episode={episode}")
        }
        _ => return Vec::new(),
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
