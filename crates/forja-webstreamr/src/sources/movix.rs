use super::{format_season_episode, movie_title, SourceEmbed};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct MovixResponse {
    current_episode: Option<MovixData>,
    tmdb_details: Option<TmdbDetails>,
    player_links: Option<Vec<PlayerLink>>,
    iframe_src: Option<String>,
}

#[derive(Debug, Deserialize)]
struct TmdbDetails {
    title: Option<String>,
}

#[derive(Debug, Deserialize)]
struct MovixData {
    player_links: Option<Vec<PlayerLink>>,
    iframe_src: Option<String>,
}

#[derive(Debug, Deserialize)]
struct PlayerLink {
    decoded_url: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct MovixParseOpts {
    pub referer: String,
    pub is_series: bool,
    pub year: Option<i32>,
    pub season: Option<i32>,
    pub episode: Option<i32>,
}

pub fn parse_json(body: &str, opts: &MovixParseOpts) -> Vec<SourceEmbed> {
    let json: MovixResponse = match serde_json::from_str(body) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };

    let (links, iframe_src) = if opts.is_series {
        let Some(ep) = json.current_episode else {
            return Vec::new();
        };
        (ep.player_links.unwrap_or_default(), ep.iframe_src)
    } else {
        (json.player_links.unwrap_or_default(), json.iframe_src)
    };
    if links.is_empty() {
        return Vec::new();
    }

    let tmdb_title = json
        .tmdb_details
        .and_then(|d| d.title)
        .unwrap_or_default();
    let title = if opts.is_series {
        let (Some(season), Some(episode)) = (opts.season, opts.episode) else {
            return Vec::new();
        };
        Some(format!("{tmdb_title} {}", format_season_episode(season, episode)))
    } else {
        opts.year.map(|y| movie_title(&tmdb_title, y))
    };
    let referer = iframe_src
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| opts.referer.clone());

    links
        .into_iter()
        .filter(|l| !l.decoded_url.is_empty())
        .map(|l| SourceEmbed {
            url: l.decoded_url,
            title: title.clone(),
            country_codes: vec!["fr".into()],
            referer: Some(referer.clone()),
            priority: None,
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_movie_links() {
        let body = r#"{
            "player_links":[{"decoded_url":"https://embed.example/a"}],
            "iframe_src":"https://movix.example/frame",
            "tmdb_details":{"title":"Film"}
        }"#;
        let opts = MovixParseOpts {
            referer: "https://api.movix.site".into(),
            is_series: false,
            year: Some(2020),
            season: None,
            episode: None,
        };
        let rows = parse_json(body, &opts);
        assert_eq!(rows[0].url, "https://embed.example/a");
        assert_eq!(rows[0].title.as_deref(), Some("Film (2020)"));
    }

    #[test]
    fn parses_series_links() {
        let body = r#"{
            "current_episode":{"player_links":[{"decoded_url":"https://embed.example/ep"}],"iframe_src":""},
            "tmdb_details":{"title":"Show"}
        }"#;
        let opts = MovixParseOpts {
            referer: "https://api.movix.site".into(),
            is_series: true,
            year: None,
            season: Some(2),
            episode: Some(3),
        };
        let rows = parse_json(body, &opts);
        assert_eq!(rows[0].title.as_deref(), Some("Show S02E03"));
    }
}
