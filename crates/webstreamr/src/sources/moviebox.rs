use super::{movie_title, series_title, SourceEmbed, SourceRequest};
use crate::fetcher::{fetch_text_post, FetchConfig};
use crate::tmdb::{get_tmdb_name_and_year, MediaIds};
use crate::types::MediaType;
use serde::Deserialize;
use std::collections::HashMap;

const API_BASE: &str = "https://h5-api.aoneroom.com";
const SEARCH_PATH: &str = "/wefeed-h5api-bff/subject/search";
const DOWNLOAD_PATH: &str = "/wefeed-h5api-bff/subject/download";
const REFERER: &str = "https://videodownloader.site/";

#[derive(Debug, Deserialize)]
struct SearchResponse {
    code: i64,
    data: Option<SearchData>,
}

#[derive(Debug, Deserialize)]
struct SearchData {
    items: Vec<SearchItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SearchItem {
    subject_id: String,
    title: Option<String>,
    detail_path: String,
    release_date: Option<String>,
    has_resource: Option<bool>,
    season: Option<i32>,
}

fn api_headers() -> HashMap<String, String> {
    HashMap::from([
        ("Accept".into(), "application/json".into()),
        ("Content-Type".into(), "application/json".into()),
        ("X-Client-Info".into(), r#"{"timezone":"UTC"}"#.into()),
        ("Referer".into(), REFERER.into()),
    ])
}

fn strip_season_suffix(title: &str) -> String {
    regex::Regex::new(r"\s+S\d+$")
        .unwrap()
        .replace(title, "")
        .to_string()
}

fn encode_component(s: &str) -> String {
    url::form_urlencoded::byte_serialize(s.as_bytes()).collect()
}

/// Build MovieBox download URL embeds (extractor fetches the JSON).
pub fn run(ids: &MediaIds, req: &SourceRequest, tmdb_token: Option<&str>) -> Vec<SourceEmbed> {
    let tmdb = match ids.tmdb_id {
        Some(t) if t > 0 => t,
        _ => return Vec::new(),
    };
    let is_tv = req.media_type == MediaType::Series;
    let season_opt = if is_tv {
        Some(ids.season.or(req.season).unwrap_or(1))
    } else {
        None
    };
    let (name, year) = match get_tmdb_name_and_year(tmdb, season_opt, None, tmdb_token) {
        Ok(ny) => (ny.name, ny.year),
        Err(_) => {
            let name = req.title.clone().unwrap_or_default();
            let year = req.year.unwrap_or(0);
            if name.is_empty() {
                return Vec::new();
            }
            (name, year)
        }
    };

    let subject_type = if is_tv { 2 } else { 1 };
    let season = season_opt.unwrap_or(0);
    let episode = if is_tv {
        ids.episode.or(req.episode).unwrap_or(1)
    } else {
        0
    };

    let Some((subject_id, detail_path)) = search(&name, year, subject_type, season) else {
        return Vec::new();
    };

    let title = if is_tv {
        series_title(&name, season, episode)
    } else {
        movie_title(&name, year)
    };

    vec![SourceEmbed {
        url: format!(
            "{API_BASE}{DOWNLOAD_PATH}?subjectId={}&se={}&ep={}&detailPath={}",
            subject_id,
            season,
            episode,
            encode_component(&detail_path)
        ),
        title: Some(title),
        country_codes: vec!["multi".into()],
        referer: Some(REFERER.into()),
        priority: Some(-1),
        height: None,
        bytes: None,
    }]
}

fn search(
    name: &str,
    year: i32,
    subject_type: i32,
    season: i32,
) -> Option<(String, String)> {
    let payload = serde_json::json!({
        "keyword": name,
        "page": 1,
        "perPage": 24,
        "subjectType": subject_type,
    });
    let mut cfg = FetchConfig::default();
    cfg.headers = api_headers();
    let url = format!("{API_BASE}{SEARCH_PATH}");
    let body = fetch_text_post(&url, &payload.to_string(), &cfg).ok()?;
    let resp: SearchResponse = serde_json::from_str(&body).ok()?;
    if resp.code != 0 {
        return None;
    }
    let items = resp.data?.items;
    if subject_type == 1 {
        match_movie(&items, name, year)
    } else {
        match_tv(&items, name, season)
    }
}

fn match_movie(items: &[SearchItem], name: &str, year: i32) -> Option<(String, String)> {
    let year_str = year.to_string();
    let name_l = name.to_lowercase();
    if let Some(item) = items.iter().find(|item| {
        let title_ok = item
            .title
            .as_deref()
            .map(|t| t.to_lowercase() == name_l)
            .unwrap_or(false);
        let year_ok = item
            .release_date
            .as_deref()
            .map(|d| d.starts_with(&year_str))
            .unwrap_or(true);
        title_ok && year_ok && item.has_resource.unwrap_or(false)
    }) {
        return Some((item.subject_id.clone(), item.detail_path.clone()));
    }
    items
        .iter()
        .find(|i| i.has_resource.unwrap_or(false))
        .map(|i| (i.subject_id.clone(), i.detail_path.clone()))
}

fn match_tv(items: &[SearchItem], name: &str, season: i32) -> Option<(String, String)> {
    let name_l = name.to_lowercase();
    let matching: Vec<&SearchItem> = items
        .iter()
        .filter(|item| {
            item.title
                .as_deref()
                .map(|t| strip_season_suffix(t).to_lowercase() == name_l)
                .unwrap_or(false)
        })
        .collect();
    let pool: Vec<&SearchItem> = if matching.is_empty() {
        items.iter().collect()
    } else {
        matching
    };
    if let Some(item) = pool
        .iter()
        .find(|i| i.season == Some(season) && i.has_resource.unwrap_or(false))
    {
        return Some((item.subject_id.clone(), item.detail_path.clone()));
    }
    pool.iter()
        .find(|i| i.has_resource.unwrap_or(false))
        .map(|i| (i.subject_id.clone(), i.detail_path.clone()))
}
