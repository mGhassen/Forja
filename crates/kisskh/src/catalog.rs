use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::http;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct KdramaCard {
    pub id: i32,
    pub title: String,
    pub cover: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
    #[serde(default)]
    pub episodes_count: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub r#type: Option<String>,
    /// KissKH `tmdbID` when the API embeds it (authoritative for Sources / enrich).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tmdb_id: Option<i32>,
    /// Synopsis from `/Drama/{id}` — list endpoints omit this.
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct KdramaEpisode {
    pub id: i32,
    pub number: f64,
    #[serde(default)]
    pub sub: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct KdramaDetails {
    pub id: i32,
    pub title: String,
    pub description: String,
    pub cover: String,
    pub release_date: String,
    pub country: String,
    pub status: String,
    pub r#type: String,
    pub episodes_count: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
    /// KissKH `tmdbID` when present on `/Drama/{id}`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tmdb_id: Option<i32>,
    #[serde(default)]
    pub episodes: Vec<KdramaEpisode>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct KdramaHomeFeed {
    #[serde(default)]
    pub spotlight: Vec<KdramaCard>,
    #[serde(default)]
    pub latest: Vec<KdramaCard>,
    #[serde(default)]
    pub most_viewed: Vec<KdramaCard>,
    #[serde(default)]
    pub trending: Vec<KdramaCard>,
    #[serde(default)]
    pub top_rated: Vec<KdramaCard>,
    #[serde(default)]
    pub upcoming: Vec<KdramaCard>,
    #[serde(default)]
    pub anime: Vec<KdramaCard>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct KdramaExplorePage {
    #[serde(default)]
    pub items: Vec<KdramaCard>,
    #[serde(default)]
    pub total: i32,
    #[serde(default)]
    pub page: i32,
    #[serde(default = "default_page_size")]
    pub page_size: i32,
}

fn default_page_size() -> i32 {
    40
}

pub fn year_from_release(release_date: &str) -> Option<String> {
    if release_date.len() >= 4 {
        let y = &release_date[..4];
        if y.chars().all(|c| c.is_ascii_digit()) {
            return Some(y.to_string());
        }
    }
    None
}

/// KissKH may send `tmdbID` / `tmdbId` as int or string.
fn parse_tmdb_id(obj: &serde_json::Map<String, Value>) -> Option<i32> {
    for key in ["tmdbID", "tmdbId", "tmdb_id"] {
        if let Some(v) = obj.get(key) {
            if let Some(n) = v.as_i64() {
                if n > 0 {
                    return Some(n as i32);
                }
            }
            if let Some(s) = v.as_str() {
                if let Ok(n) = s.trim().parse::<i32>() {
                    if n > 0 {
                        return Some(n);
                    }
                }
            }
        }
    }
    None
}

/// KissKH thumbnails often point at `media.themoviedb.org`, which 301s to
/// `image.tmdb.org` (same Let's Encrypt chain). Prefer the image CDN so covers
/// share Home's TMDB image path (Android ≤7.0 trusts ISRG via app roots).
pub fn normalize_cover_url(raw: &str) -> String {
    let t = raw.trim();
    if t.is_empty() {
        return String::new();
    }
    if let Some(rest) = t.strip_prefix("https://media.themoviedb.org") {
        return format!("https://image.tmdb.org{rest}");
    }
    if let Some(rest) = t.strip_prefix("http://media.themoviedb.org") {
        return format!("https://image.tmdb.org{rest}");
    }
    t.to_string()
}

pub fn parse_card_list(body: &str) -> Vec<KdramaCard> {
    let raw: Value = match serde_json::from_str(body) {
        Ok(v) => v,
        Err(_) => return vec![],
    };
    let items = match raw {
        Value::Array(arr) => arr,
        _ => return vec![],
    };

    let mut out = Vec::new();
    for it in items {
        let Some(obj) = it.as_object() else {
            continue;
        };
        let id = obj.get("id").and_then(|v| v.as_i64()).map(|v| v as i32);
        let title = obj
            .get("title")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .trim()
            .to_string();
        if id.is_none() || title.is_empty() {
            continue;
        }
        let release = obj
            .get("releaseDate")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let type_raw = obj
            .get("type")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .trim()
            .to_string();
        let label = obj
            .get("label")
            .and_then(|v| v.as_str())
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_string);
        out.push(KdramaCard {
            id: id.unwrap(),
            title,
            cover: normalize_cover_url(
                obj.get("thumbnail")
                    .and_then(|v| v.as_str())
                    .unwrap_or(""),
            ),
            label,
            episodes_count: obj
                .get("episodesCount")
                .and_then(|v| v.as_i64())
                .unwrap_or(0) as i32,
            year: year_from_release(&release),
            r#type: if type_raw.is_empty() {
                None
            } else {
                Some(type_raw)
            },
            tmdb_id: parse_tmdb_id(obj),
            description: String::new(),
        });
    }
    out
}

pub fn slugify(title: &str) -> String {
    static RE_QUOTES: std::sync::OnceLock<Regex> = std::sync::OnceLock::new();
    static RE_NON_ALNUM: std::sync::OnceLock<Regex> = std::sync::OnceLock::new();
    static RE_DASHES: std::sync::OnceLock<Regex> = std::sync::OnceLock::new();
    static RE_TRIM: std::sync::OnceLock<Regex> = std::sync::OnceLock::new();

    let quotes = RE_QUOTES.get_or_init(|| Regex::new(r"[''‘’`]").expect("quotes regex"));
    let non_alnum = RE_NON_ALNUM.get_or_init(|| Regex::new(r"[^a-z0-9]+").expect("non-alnum regex"));
    let dashes = RE_DASHES.get_or_init(|| Regex::new(r"-+").expect("dashes regex"));
    let trim = RE_TRIM.get_or_init(|| Regex::new(r"^-|-$").expect("trim regex"));

    let lower = title.to_lowercase();
    let s = quotes.replace_all(&lower, "");
    let s = non_alnum.replace_all(&s, "-");
    let s = dashes.replace_all(&s, "-");
    let s = trim.replace_all(&s, "");
    let out = s.to_string();
    if out.is_empty() {
        "drama".to_string()
    } else {
        out
    }
}

pub fn episode_page_url(
    drama_id: i32,
    title: &str,
    episode_id: i32,
    episode_number: f64,
) -> String {
    let slug = slugify(title);
    let ep_label = if episode_number.fract() == 0.0 {
        (episode_number as i64).to_string()
    } else {
        episode_number.to_string()
    };
    format!(
        "{}/Drama/{slug}/Episode-{ep_label}?id={drama_id}&ep={episode_id}&page=0&pageSize=100",
        http::current_base_url()
    )
}

pub fn match_resume_episode(
    episodes: &[KdramaEpisode],
    episode_number: f64,
    episode_id: Option<i32>,
) -> Option<KdramaEpisode> {
    if episodes.is_empty() {
        return None;
    }
    for e in episodes {
        if e.number == episode_number {
            return Some(e.clone());
        }
    }
    if let Some(id) = episode_id {
        if id > 0 {
            if let Some(found) = episodes.iter().find(|e| e.id == id) {
                return Some(found.clone());
            }
        }
    }
    episodes.first().cloned()
}

/// Cap concurrency — list hits share the same client IP as Episode extract
/// and helped trip KissKH "Too many request."
const HOME_CONCURRENCY: usize = 2;

fn fetch_home_paths(paths: &[&str]) -> Result<Vec<String>, String> {
    let mut results: Vec<String> = Vec::with_capacity(paths.len());
    let mut i = 0;
    while i < paths.len() {
        let end = (i + HOME_CONCURRENCY).min(paths.len());
        let chunk = &paths[i..end];
        let bodies: Result<Vec<String>, String> = std::thread::scope(|scope| {
            let handles: Vec<_> = chunk
                .iter()
                .map(|path| scope.spawn(|| http::get_api(path, true)))
                .collect();
            handles.into_iter().map(|h| h.join().unwrap()).collect()
        });
        results.extend(bodies?);
        i = end;
        if i < paths.len() {
            std::thread::sleep(std::time::Duration::from_millis(150));
        }
    }
    Ok(results)
}

/// Spotlight + Latest only — enough for hero first paint.
pub fn get_home_hero() -> Result<KdramaHomeFeed, String> {
    let paths = [
        "/DramaList/Show",
        "/DramaList/LastUpdate?ispc=false",
    ];
    let results = fetch_home_paths(&paths)?;
    Ok(KdramaHomeFeed {
        spotlight: parse_card_list(&results[0]),
        latest: parse_card_list(&results[1]),
        most_viewed: vec![],
        trending: vec![],
        top_rated: vec![],
        upcoming: vec![],
        anime: vec![],
    })
}

/// Remaining hub rails after hero has painted.
pub fn get_home_rails() -> Result<KdramaHomeFeed, String> {
    let paths = [
        "/DramaList/MostView",
        "/DramaList/MostSearch?ispc=false",
        "/DramaList/TopRating?ispc=false",
        "/DramaList/Upcoming?ispc=false",
        "/DramaList/Animate?ispc=false",
    ];
    let results = fetch_home_paths(&paths)?;
    Ok(KdramaHomeFeed {
        spotlight: vec![],
        latest: vec![],
        most_viewed: parse_card_list(&results[0]),
        trending: parse_card_list(&results[1]),
        top_rated: parse_card_list(&results[2]),
        upcoming: parse_card_list(&results[3]),
        anime: parse_card_list(&results[4]),
    })
}

pub fn get_home() -> Result<KdramaHomeFeed, String> {
    let hero = get_home_hero()?;
    let rails = get_home_rails()?;
    Ok(KdramaHomeFeed {
        spotlight: hero.spotlight,
        latest: hero.latest,
        most_viewed: rails.most_viewed,
        trending: rails.trending,
        top_rated: rails.top_rated,
        upcoming: rails.upcoming,
        anime: rails.anime,
    })
}

pub fn search(query: &str) -> Result<Vec<KdramaCard>, String> {
    let q = query.trim();
    if q.is_empty() {
        return Ok(vec![]);
    }
    let encoded = urlencoding::encode(q);
    let path = format!("/DramaList/Search?q={encoded}&type=0");
    let body = http::get_api(&path, false)?;
    Ok(parse_card_list(&body))
}

pub fn explore(
    page: i32,
    type_filter: i32,
    sub: i32,
    country: i32,
    status: i32,
    order: i32,
    page_size: i32,
) -> Result<KdramaExplorePage, String> {
    let path = format!(
        "/DramaList/List?page={page}&type={type_filter}&sub={sub}&country={country}&status={status}&order={order}&pageSize={page_size}"
    );
    let body = http::get_api(&path, true)?;
    let raw: Value = serde_json::from_str(&body).unwrap_or(Value::Null);
    let Some(obj) = raw.as_object() else {
        return Ok(KdramaExplorePage {
            items: vec![],
            total: 0,
            page: 1,
            page_size,
        });
    };
    let data = obj.get("data").cloned().unwrap_or(Value::Array(vec![]));
    let items = parse_card_list(&data.to_string());
    Ok(KdramaExplorePage {
        total: obj
            .get("totalCount")
            .and_then(|v| v.as_i64())
            .unwrap_or(items.len() as i64) as i32,
        page: obj
            .get("page")
            .and_then(|v| v.as_i64())
            .unwrap_or(page as i64) as i32,
        page_size: obj
            .get("pageSize")
            .and_then(|v| v.as_i64())
            .unwrap_or(page_size as i64) as i32,
        items,
    })
}

pub fn get_details(id: i32) -> Result<KdramaDetails, String> {
    let path = format!("/DramaList/Drama/{id}?isq=false");
    let body = http::get_api(&path, true)?;
    let raw: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    let obj = raw.as_object().ok_or_else(|| "details must be object".to_string())?;

    let mut eps = Vec::new();
    if let Some(episodes) = obj.get("episodes").and_then(|v| v.as_array()) {
        for e in episodes {
            let Some(ep) = e.as_object() else {
                continue;
            };
            let id = ep.get("id").and_then(|v| v.as_i64()).map(|v| v as i32);
            let number = ep.get("number").and_then(|v| v.as_f64());
            if id.is_none() || number.is_none() {
                continue;
            }
            eps.push(KdramaEpisode {
                id: id.unwrap(),
                number: number.unwrap(),
                sub: ep.get("sub").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
            });
        }
    }
    eps.sort_by(|a, b| {
        a.number
            .partial_cmp(&b.number)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let label = obj
        .get("label")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string);

    Ok(KdramaDetails {
        id: obj.get("id").and_then(|v| v.as_i64()).unwrap_or(id as i64) as i32,
        title: obj
            .get("title")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .trim()
            .to_string(),
        description: obj
            .get("description")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .trim()
            .to_string(),
        cover: normalize_cover_url(
            obj.get("thumbnail")
                .and_then(|v| v.as_str())
                .unwrap_or(""),
        ),
        release_date: obj
            .get("releaseDate")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string(),
        country: obj
            .get("country")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string(),
        status: obj
            .get("status")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string(),
        r#type: obj
            .get("type")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string(),
        episodes_count: obj
            .get("episodesCount")
            .and_then(|v| v.as_i64())
            .unwrap_or(eps.len() as i64) as i32,
        label,
        tmdb_id: parse_tmdb_id(obj),
        episodes: eps,
    })
}

fn merge_card_details(card: &KdramaCard, det: &KdramaDetails) -> KdramaCard {
    let description = if !card.description.is_empty() {
        card.description.clone()
    } else {
        det.description.clone()
    };
    KdramaCard {
        id: card.id,
        title: card.title.clone(),
        cover: card.cover.clone(),
        label: card.label.clone().or(det.label.clone()),
        episodes_count: if card.episodes_count > 0 {
            card.episodes_count
        } else {
            det.episodes_count
        },
        year: card
            .year
            .clone()
            .or(year_from_release(&det.release_date)),
        r#type: card.r#type.clone().or(if det.r#type.is_empty() {
            None
        } else {
            Some(det.r#type.clone())
        }),
        tmdb_id: card.tmdb_id.or(det.tmdb_id),
        description,
    }
}

/// Fill year/type (and description when details are fetched).
pub fn enrich_cards(cards: Vec<KdramaCard>) -> Vec<KdramaCard> {
    enrich_cards_where(cards, |c| c.year.is_none() || c.r#type.is_none())
}

/// Fill missing synopsis from `/Drama/{id}` (hero spotlight — small lists only).
pub fn enrich_card_descriptions(cards: Vec<KdramaCard>) -> Vec<KdramaCard> {
    enrich_cards_where(cards, |c| c.description.is_empty())
}

fn enrich_cards_where(
    cards: Vec<KdramaCard>,
    needs_fetch: impl Fn(&KdramaCard) -> bool,
) -> Vec<KdramaCard> {
    if cards.is_empty() {
        return cards;
    }
    let mut out = cards;
    // One detail at a time + longer pause — bulk fan-out burned the shared
    // KissKH IP budget before Play could open an Episode page.
    const CHUNK: usize = 1;
    let mut i = 0;
    while i < out.len() {
        let end = (i + CHUNK).min(out.len());
        let indices: Vec<usize> = (i..end).collect();
        let mut updates: Vec<(usize, KdramaCard)> = Vec::new();

        std::thread::scope(|scope| {
            let handles: Vec<_> = indices
                .iter()
                .filter_map(|&j| {
                    let c = &out[j];
                    if !needs_fetch(c) {
                        return None;
                    }
                    Some((j, scope.spawn(|| get_details(c.id))))
                })
                .collect();

            for (j, handle) in handles {
                if let Ok(Ok(det)) = handle.join() {
                    updates.push((j, merge_card_details(&out[j], &det)));
                }
            }
        });

        for (j, card) in updates {
            out[j] = card;
        }

        if end < out.len() {
            std::thread::sleep(std::time::Duration::from_millis(350));
        }
        i = end;
    }
    out
}

/// Hero carousel lists — fetch synopsis before bulk meta enrich hammers the API.
fn enrich_hero_lists(feed: &KdramaHomeFeed) -> (Vec<KdramaCard>, Vec<KdramaCard>, Vec<KdramaCard>) {
    let mut spotlight = feed.spotlight.clone();
    let mut latest = feed.latest.clone();
    let mut trending = feed.trending.clone();
    const HERO_CAP: usize = 8;
    if !spotlight.is_empty() {
        let n = spotlight.len().min(HERO_CAP);
        let head = enrich_card_descriptions(spotlight[..n].to_vec());
        spotlight = head.into_iter().chain(spotlight.into_iter().skip(n)).collect();
    } else if !latest.is_empty() {
        let n = latest.len().min(HERO_CAP);
        let head = enrich_card_descriptions(latest[..n].to_vec());
        latest = head.into_iter().chain(latest.into_iter().skip(n)).collect();
    } else if !trending.is_empty() {
        let n = trending.len().min(HERO_CAP);
        let head = enrich_card_descriptions(trending[..n].to_vec());
        trending = head.into_iter().chain(trending.into_iter().skip(n)).collect();
    }
    (spotlight, latest, trending)
}

pub fn enrich_home_feed(feed: KdramaHomeFeed) -> KdramaHomeFeed {
    // Hero synopsis only — do NOT fan out `/Drama/{id}` for every poster in
    // every row. That shared-IP storm rate-limited Episode extract before Play.
    let (hero_spotlight, hero_latest, hero_trending) = enrich_hero_lists(&feed);

    let merge_hero = |hero: Vec<KdramaCard>, fallback: Vec<KdramaCard>| -> Vec<KdramaCard> {
        if hero.is_empty() {
            fallback
        } else {
            hero
        }
    };

    KdramaHomeFeed {
        spotlight: merge_hero(hero_spotlight, feed.spotlight),
        latest: merge_hero(hero_latest, feed.latest),
        most_viewed: feed.most_viewed,
        trending: merge_hero(hero_trending, feed.trending),
        top_rated: feed.top_rated,
        upcoming: feed.upcoming,
        anime: feed.anime,
    }
}

pub fn ok_json<T: Serialize>(value: &T) -> String {
    serde_json::to_string(value).unwrap_or_else(|_| "{}".into())
}

pub fn error_json(message: &str) -> String {
    json!({ "error": message }).to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn year_from_release_parses_prefix() {
        assert_eq!(year_from_release("2024-01-01"), Some("2024".into()));
        assert_eq!(year_from_release("abc"), None);
    }

    #[test]
    fn normalize_cover_url_rewrites_media_tmdb_host() {
        assert_eq!(
            normalize_cover_url(
                "https://media.themoviedb.org/t/p/w1000_and_h563_face/abc.jpg"
            ),
            "https://image.tmdb.org/t/p/w1000_and_h563_face/abc.jpg"
        );
        assert_eq!(
            normalize_cover_url("https://serveproxy.com/?url=https://x/y.jpg"),
            "https://serveproxy.com/?url=https://x/y.jpg"
        );
        assert_eq!(normalize_cover_url(""), "");
    }

    #[test]
    fn parse_card_list_normalizes_media_tmdb_thumbnail() {
        let raw = r#"[{"id":1,"title":"A","thumbnail":"https://media.themoviedb.org/t/p/w500/x.jpg","releaseDate":"2020"}]"#;
        let cards = parse_card_list(raw);
        assert_eq!(cards[0].cover, "https://image.tmdb.org/t/p/w500/x.jpg");
    }

    #[test]
    fn parse_card_list_skips_invalid_rows() {
        let raw = r#"[
            {"id":1,"title":"A","thumbnail":"c","releaseDate":"2020","type":"TVSeries","tmdbID":215720},
            {"id":null,"title":"B"},
            {"title":"C"}
        ]"#;
        let cards = parse_card_list(raw);
        assert_eq!(cards.len(), 1);
        assert_eq!(cards[0].id, 1);
        assert_eq!(cards[0].year.as_deref(), Some("2020"));
        assert_eq!(cards[0].r#type.as_deref(), Some("TVSeries"));
        assert_eq!(cards[0].tmdb_id, Some(215720));
    }

    #[test]
    fn parse_tmdb_id_accepts_string() {
        let raw = r#"[{"id":1,"title":"A","thumbnail":"c","tmdbId":"1396"}]"#;
        let cards = parse_card_list(raw);
        assert_eq!(cards[0].tmdb_id, Some(1396));
    }

    #[test]
    fn slugify_normalizes_title() {
        assert_eq!(slugify("Hello World!"), "hello-world");
        assert_eq!(slugify("---"), "drama");
    }

    #[test]
    fn episode_page_url_builds_path() {
        let url = episode_page_url(9, "My Drama", 42, 3.0);
        assert!(url.contains("/Drama/my-drama/Episode-3?"));
        assert!(url.contains("id=9"));
        assert!(url.contains("ep=42"));
    }

    #[test]
    fn match_resume_episode_prefers_number() {
        let eps = vec![
            KdramaEpisode {
                id: 1,
                number: 1.0,
                sub: 0,
            },
            KdramaEpisode {
                id: 2,
                number: 2.0,
                sub: 0,
            },
        ];
        let found = match_resume_episode(&eps, 2.0, Some(99));
        assert_eq!(found.map(|e| e.id), Some(2));
    }

    #[test]
    fn parse_card_list_handles_empty_array() {
        assert!(parse_card_list("[]").is_empty());
        assert!(parse_card_list("not-json").is_empty());
    }
}
