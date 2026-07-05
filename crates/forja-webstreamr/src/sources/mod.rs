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
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub height: Option<i32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub bytes: Option<u64>,
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
    pub season: Option<i32>,
    pub episode: Option<i32>,
    pub country_codes: Option<Vec<String>>,
    pub is_series: Option<bool>,
    pub year: Option<i32>,
    pub base_url: Option<String>,
    pub body_kind: Option<String>,
}

fn parse_episode_html(
    html: &str,
    referer: &str,
    opts: &ParseHtmlOpts,
    parse: fn(&str, &str, i32, i32, Option<&str>) -> Vec<SourceEmbed>,
) -> Vec<SourceEmbed> {
    let (Some(season), Some(episode)) = (opts.season, opts.episode) else {
        return Vec::new();
    };
    parse(
        html,
        referer,
        season,
        episode,
        opts.title.as_deref(),
    )
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
        "mostraguarda" => mostraguarda::parse_html(html, &opts.referer),
        "eurostreaming" => parse_episode_html(html, &opts.referer, &opts, eurostreaming::parse_html),
        "cinehdplus" => parse_episode_html(html, &opts.referer, &opts, cinehdplus::parse_html),
        "streamkiste" => parse_episode_html(html, &opts.referer, &opts, streamkiste::parse_html),
        "frenchcloud" => frenchcloud::parse_html(html, &opts.referer),
        "cuevana" => cuevana::parse_html(html, &opts.referer, opts.title.as_deref()),
        "hdhub4u" => hdhub4u::parse_html(
            html,
            &opts.referer,
            opts.country_codes.as_deref().unwrap_or(&[]),
        ),
        "einschalten" => einschalten::parse_json(html, &opts.referer),
        "movix" => movix::parse_json(
            html,
            &movix::MovixParseOpts {
                referer: opts.referer.clone(),
                is_series: opts.is_series.unwrap_or(false),
                year: opts.year,
                season: opts.season,
                episode: opts.episode,
            },
        ),
        "frembed" => frembed::parse_json(
            html,
            &opts.referer,
            opts.is_series.unwrap_or(false),
            opts.season,
            opts.episode,
            opts.year,
        ),
        "kokoshka" if opts.body_kind.as_deref() == Some("dooplayer") => {
            kokoshka::parse_dooplayer_json(html, &opts.referer, opts.title.as_deref())
        }
        "kokoshka" => kokoshka::parse_page_html(
            html,
            opts.base_url.as_deref().unwrap_or(&opts.referer),
        ),
        "4khdhub" => fourkhdhub::parse_html(
            html,
            &opts.referer,
            opts.is_series.unwrap_or(false),
            opts.season,
            opts.episode,
        ),
        "vegamovies" => vegamovies::parse_nexdrive_html(
            html,
            &opts.referer,
            opts.episode,
            opts.title.as_deref(),
        ),
        _ => Vec::new(),
    }
}

mod cinehdplus;
mod cuevana;
mod einschalten;
mod eurostreaming;
mod fourkhdhub;
mod frenchcloud;
mod frembed;
mod hdhub4u;
mod homecine;
mod kinoger;
mod kokoshka;
mod megakino;
mod meinecloud;
mod mirrors;
mod movix;
mod mostraguarda;
mod rgshows;
mod streamkiste;
mod vegamovies;
mod verhdlink;
mod vidsrc;
mod vixsrc;

pub fn list_url_sources() -> &'static [&'static str] {
    &["vidsrc", "vixsrc", "rgshows"]
}

pub fn list_html_sources() -> &'static [&'static str] {
    &[
        "meinecloud",
        "verhdlink",
        "megakino",
        "homecine",
        "mostraguarda",
        "eurostreaming",
        "cinehdplus",
        "streamkiste",
        "frenchcloud",
        "cuevana",
        "hdhub4u",
        "einschalten",
        "movix",
        "frembed",
        "kokoshka",
        "4khdhub",
        "vegamovies",
    ]
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
