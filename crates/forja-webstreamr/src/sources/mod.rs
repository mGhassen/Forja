use crate::types::MediaType;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SourceRequest {
    pub tmdb_id: Option<i64>,
    pub imdb_id: Option<String>,
    pub media_type: MediaType,
    pub season: Option<i32>,
    pub episode: Option<i32>,
    pub title: Option<String>,
    pub year: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SourceEmbed {
    pub url: String,
    pub title: Option<String>,
    pub country_codes: Vec<String>,
    pub referer: Option<String>,
    pub priority: Option<i32>,
}

pub fn format_season_episode(season: i32, episode: i32) -> String {
    format!("S{season:02}E{episode:02}")
}

fn series_title(title: &str, season: i32, episode: i32) -> String {
    format!("{title} {}", format_season_episode(season, episode))
}

fn movie_title(title: &str, year: i32) -> String {
    format!("{title} ({year})")
}

pub fn resolve_source(source_id: &str, req: &SourceRequest) -> Vec<SourceEmbed> {
    match source_id {
        "vidsrc" => vidsrc::resolve(req),
        "vixsrc" => vixsrc::resolve(req),
        "rgshows" => rgshows::resolve(req),
        _ => Vec::new(),
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct ParseHtmlOpts {
    pub referer: String,
    pub title: Option<String>,
}

pub fn parse_source_html(source_id: &str, html: &str, opts_json: &str) -> Vec<SourceEmbed> {
    let opts: ParseHtmlOpts = match serde_json::from_str(opts_json) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };
    match source_id {
        "meinecloud" => meinecloud::parse_html(html, &opts.referer),
        "verhdlink" => verhdlink::parse_html(html, &opts.referer),
        "megakino" => megakino::parse_html(html, &opts.referer),
        "homecine" => homecine::parse_html(html, &opts.referer, opts.title.as_deref()),
        _ => Vec::new(),
    }
}

mod homecine;
mod kinoger;
mod megakino;
mod meinecloud;
mod rgshows;
mod verhdlink;
mod vidsrc;
mod vixsrc;

pub fn list_url_sources() -> &'static [&'static str] {
    &["vidsrc", "vixsrc", "rgshows"]
}

pub fn list_html_sources() -> &'static [&'static str] {
    &["meinecloud", "verhdlink", "megakino", "homecine"]
}

pub fn parse_source_html_json(source_id: &str, html: &str, opts_json: &str) -> String {
    serde_json::to_string(&parse_source_html(source_id, html, opts_json))
        .unwrap_or_else(|_| "[]".into())
}

pub fn extract_kinoger_episode_urls(
    html: &str,
    season_index: usize,
    episode_index: usize,
) -> Vec<String> {
    kinoger::extract_episode_urls(html, season_index, episode_index)
}

pub fn resolve_source_json(source_id: &str, request_json: &str) -> String {
    let req: SourceRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(_) => return "[]".into(),
    };
    serde_json::to_string(&resolve_source(source_id, &req)).unwrap_or_else(|_| "[]".into())
}

pub fn extract_kinoger_episode_urls_json(
    html: &str,
    season_index: i32,
    episode_index: i32,
) -> String {
    if season_index < 0 || episode_index < 0 {
        return "[]".into();
    }
    let urls = extract_kinoger_episode_urls(html, season_index as usize, episode_index as usize);
    serde_json::to_string(&urls).unwrap_or_else(|_| "[]".into())
}
