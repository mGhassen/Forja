use super::{SourceEmbed, SourceRequest};
use crate::types::MediaType;

const BASE_URL: &str = "https://vidsrc-embed.ru";

pub fn resolve(req: &SourceRequest) -> Vec<SourceEmbed> {
    let Some(content_id) = req
        .imdb_id
        .as_deref()
        .map(str::to_string)
        .or_else(|| req.tmdb_id.map(|id| id.to_string()))
    else {
        return Vec::new();
    };
    let url = match req.media_type {
        MediaType::Movie => format!("{BASE_URL}/embed/movie/{content_id}"),
        MediaType::Series => {
            let season = req.season.unwrap_or(1);
            let episode = req.episode.unwrap_or(1);
            format!("{BASE_URL}/embed/tv/{content_id}/{season}-{episode}")
        }
    };
    vec![SourceEmbed {
        url,
        title: None,
        country_codes: vec!["multi".into()],
        referer: None,
        priority: None,
    }]
}
