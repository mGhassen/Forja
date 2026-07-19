use super::{movie_title, series_title, SourceEmbed, SourceRequest};
use crate::types::MediaType;

fn api_base() -> String {
    utils::provider_runtime::api_base("rgshowsApi")
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "https://api.rgshows.ru".to_string())
}

pub fn resolve(req: &SourceRequest) -> Vec<SourceEmbed> {
    let Some(tmdb_id) = req.tmdb_id else {
        return Vec::new();
    };
    let title = req.title.as_deref();
    let year = req.year;
    let api = api_base();
    let url = match req.media_type {
        MediaType::Movie => format!("{api}/main/movie/{tmdb_id}"),
        MediaType::Series => {
            let season = req.season.unwrap_or(1);
            let episode = req.episode.unwrap_or(1);
            format!("{api}/main/tv/{tmdb_id}/{season}/{episode}")
        }
    };
    let formatted_title = title.and_then(|name| match req.media_type {
        MediaType::Movie => year.map(|y| movie_title(name, y)),
        MediaType::Series => Some(series_title(
            name,
            req.season.unwrap_or(1),
            req.episode.unwrap_or(1),
        )),
    });
    vec![SourceEmbed {
        url,
        title: formatted_title,
        country_codes: vec!["multi".into()],
        referer: None,
        priority: Some(-1),
        height: None,
        bytes: None,
    }]
}
