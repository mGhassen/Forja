use super::{movie_title, series_title, SourceEmbed, SourceRequest};
use crate::fetcher::{fetch_text, FetchConfig};
use crate::tmdb::{get_tmdb_name_and_year, MediaIds};
use crate::types::MediaType;
use scraper::{Html, Selector};

const BASE_URL: &str = "https://filmpalast.to";

const STREAMING_HOSTS: &[&str] = &[
    "voe", "dood", "streamtape", "veev", "vinovo", "vidhide", "dhtpre", "mixdrop",
    "supervideo", "uqload", "filelion", "lulustream", "fastream", "dropload", "savefiles",
    "streamembed", "vidara", "vidsonic",
];

fn base_url() -> String {
    utils::provider_runtime::webstreamr_base("filmpalast")
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| BASE_URL.to_string())
}

fn is_streaming_host(hostname: &str) -> bool {
    let h = hostname.to_lowercase();
    STREAMING_HOSTS.iter().any(|host| h.contains(host))
}

fn resolve_href(href: &str, base: &str) -> Option<String> {
    let full = if href.starts_with("//") {
        format!("https:{href}")
    } else {
        href.to_string()
    };
    if full.starts_with("http://") || full.starts_with("https://") {
        return Some(full);
    }
    let base = base.trim_end_matches('/');
    Some(format!(
        "{base}{}",
        if full.starts_with('/') {
            full
        } else {
            format!("/{full}")
        }
    ))
}

pub fn run(ids: &MediaIds, req: &SourceRequest, tmdb_token: Option<&str>) -> Vec<SourceEmbed> {
    let tmdb = match ids.tmdb_id {
        Some(t) if t > 0 => t,
        _ => return Vec::new(),
    };
    let is_tv = req.media_type == MediaType::Series;
    let season = if is_tv {
        ids.season.or(req.season)
    } else {
        None
    };
    let episode = if is_tv {
        ids.episode.or(req.episode)
    } else {
        None
    };

    let (name, year) = match get_tmdb_name_and_year(tmdb, season, Some("de"), tmdb_token) {
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

    let base = base_url();
    let Some(stream_page) = fetch_stream_page_url(&base, &name, year, season, episode) else {
        return Vec::new();
    };

    let title = if let (Some(s), Some(e)) = (season, episode) {
        series_title(&name, s, e)
    } else {
        movie_title(&name, year)
    };

    let Ok(html) = fetch_text(&stream_page, &FetchConfig::default()) else {
        return Vec::new();
    };
    let doc = Html::parse_document(&html);
    let block_sel = Selector::parse("ul.currentStreamLinks").unwrap();
    let host_sel = Selector::parse(".hostName").unwrap();
    let player_sel = Selector::parse("a[data-player-url]").unwrap();
    let href_sel = Selector::parse("a[href]").unwrap();

    let mut out = Vec::new();
    for block in doc.select(&block_sel) {
        let host_name = block
            .select(&host_sel)
            .next()
            .map(|el| el.text().collect::<String>().trim().to_string())
            .unwrap_or_default();

        for el in block.select(&player_sel) {
            if let Some(player_url) = el.value().attr("data-player-url") {
                if player_url.starts_with("http") {
                    out.push(SourceEmbed {
                        url: player_url.to_string(),
                        title: Some(format!("{host_name} - {title}")),
                        country_codes: vec!["de".into()],
                        referer: Some(stream_page.clone()),
                        priority: Some(1),
                        height: None,
                        bytes: None,
                    });
                }
            }
        }

        for el in block.select(&href_sel) {
            if el.value().attr("data-player-url").is_some() {
                continue;
            }
            let Some(href) = el.value().attr("href") else {
                continue;
            };
            if href == "#" || href.starts_with("javascript") || href.contains("filmpalast.to") {
                continue;
            }
            let Some(url) = resolve_href(href, &base) else {
                continue;
            };
            let Ok(parsed) = url::Url::parse(&url) else {
                continue;
            };
            let host = parsed.host_str().unwrap_or("");
            if !is_streaming_host(host) {
                continue;
            }
            out.push(SourceEmbed {
                url,
                title: Some(format!("{host_name} - {title}")),
                country_codes: vec!["de".into()],
                referer: Some(stream_page.clone()),
                priority: Some(1),
                height: None,
                bytes: None,
            });
        }
    }
    out
}

fn fetch_stream_page_url(
    base: &str,
    name: &str,
    year: i32,
    season: Option<i32>,
    episode: Option<i32>,
) -> Option<String> {
    let search_query = if let Some(s) = season {
        format!(
            "{name} S{:02}E{:02}",
            s,
            episode.unwrap_or(1)
        )
    } else {
        name.to_string()
    };
    let search_url = format!(
        "{}/search/title/{}",
        base.trim_end_matches('/'),
        url::form_urlencoded::byte_serialize(search_query.as_bytes()).collect::<String>()
    );
    let html = fetch_text(&search_url, &FetchConfig::default()).ok()?;
    let doc = Html::parse_document(&html);
    let sel = Selector::parse(r#"a[href*="/stream/"]"#).unwrap();

    let mut links: Vec<(String, String)> = Vec::new();
    for el in doc.select(&sel) {
        let Some(href) = el.value().attr("href") else {
            continue;
        };
        let title = el
            .value()
            .attr("title")
            .map(|s| s.to_string())
            .unwrap_or_else(|| el.text().collect::<String>().trim().to_string());
        links.push((href.to_string(), title));
    }
    if links.is_empty() {
        return None;
    }
    if season.is_none() {
        let year_s = year.to_string();
        if let Some((href, _)) = links.iter().find(|(_, t)| t.contains(&year_s)) {
            return resolve_href(href, base);
        }
    }
    resolve_href(&links[0].0, base)
}
