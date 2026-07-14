use super::{SourceEmbed, SourceRequest};
use crate::types::MediaType;

const BASE_URL: &str = "https://vsembed.su";

pub fn resolve(req: &SourceRequest) -> Vec<SourceEmbed> {
    let url = match (req.imdb_id.as_deref(), req.tmdb_id, &req.media_type) {
        (Some(imdb), _, MediaType::Movie) => format!("{BASE_URL}/embed/{imdb}/"),
        (Some(imdb), _, MediaType::Series) => {
            let season = req.season.unwrap_or(1);
            let episode = req.episode.unwrap_or(1);
            format!("{BASE_URL}/embed/{imdb}/{season}-{episode}/")
        }
        (_, Some(tmdb), MediaType::Movie) => {
            format!("{BASE_URL}/embed/movie?tmdb={tmdb}")
        }
        (_, Some(tmdb), MediaType::Series) => {
            let season = req.season.unwrap_or(1);
            let episode = req.episode.unwrap_or(1);
            format!("{BASE_URL}/embed/tv?tmdb={tmdb}&season={season}&episode={episode}")
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
