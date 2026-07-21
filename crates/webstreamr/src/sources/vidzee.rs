use super::{SourceEmbed, SourceRequest};
use crate::types::MediaType;

const BASE_URL: &str = "https://player.vidzee.wtf";

/// MBG en/multi servers only (Achilles / Drag).
const SERVERS: &[(&str, &str, &str)] = &[
    ("3", "Achilles", "US"),
    ("5", "Drag", "US"),
];

fn base_url() -> String {
    utils::provider_runtime::webstreamr_base("vidzee")
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| BASE_URL.to_string())
}

pub fn resolve(req: &SourceRequest) -> Vec<SourceEmbed> {
    let Some(tmdb) = req.tmdb_id else {
        return Vec::new();
    };
    let base = base_url().trim_end_matches('/').to_string();
    let path = match &req.media_type {
        MediaType::Movie => format!("{base}/v2/embed/movie/{tmdb}"),
        MediaType::Series => {
            let season = req.season.unwrap_or(1);
            let episode = req.episode.unwrap_or(1);
            format!("{base}/v2/embed/tv/{tmdb}/{season}/{episode}")
        }
    };
    SERVERS
        .iter()
        .map(|(sr, name, flag)| SourceEmbed {
            url: format!("{path}?sr={sr}"),
            title: Some(format!("{name} ({flag})")),
            country_codes: vec!["en".into()],
            referer: None,
            priority: None,
            height: None,
            bytes: None,
        })
        .collect()
}
