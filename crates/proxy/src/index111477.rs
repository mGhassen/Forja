//! HTML directory index scrape + title match for a.111477.xyz.

use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::sync::LazyLock;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::json;
use tokio::time::sleep;

const BASE_URL: &str = "https://a.111477.xyz";
const CACHE_TTL_SECS: u64 = 24 * 3600;
const RATE_LIMIT_WAIT_MS: u64 = 7200;
const MAX_RATE_LIMIT_RETRIES: u32 = 6;

static ROW_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?i)<tr[^>]*data-entry="true"[^>]*data-name="([^"]*)"[^>]*data-url="([^"]*)"#,
    )
    .expect("row regex")
});
static SIZE_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)<td class="size" data-sort="(-?\d+)""#).expect("size regex")
});
static YEAR_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\((\d{4})\)\s*$").expect("year regex"));
static EXT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\.(mkv|mp4|avi|m4v|mov|webm)$").expect("ext regex")
});
static NON_ALNUM_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"[^a-z0-9]+").expect("non alnum"));
static WS_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\s+").expect("ws"));
static CF_1015_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\b(?:error\s*(?:code:?\s*)?1015)\b|you are being rate limited")
        .expect("cf regex")
});

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Site111477Match {
    pub file_url: String,
    pub file_name: String,
    pub size_bytes: i64,
}

#[derive(Debug, Clone)]
struct Entry {
    raw_name: String,
    url: String,
    is_dir: bool,
    size_bytes: i64,
    normalized_title: String,
    year: Option<String>,
}

#[derive(Debug, Deserialize)]
struct IndexRequest {
    action: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    show_title: String,
    #[serde(default)]
    year: Option<String>,
    #[serde(default)]
    season: Option<i32>,
    #[serde(default)]
    episode: Option<i32>,
    #[serde(default)]
    cache_dir: String,
}

pub fn request_json_blocking(request_json: &str) -> String {
    utils::engine_cancel::enter_job();
    let rt = tokio::runtime::Runtime::new().expect("index111477 runtime");
    rt.block_on(request_json_async(request_json))
}

async fn request_json_async(request_json: &str) -> String {
    let req: IndexRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };
    let cache_dir = if req.cache_dir.trim().is_empty() {
        None
    } else {
        Some(req.cache_dir.as_str())
    };

    let result = match req.action.as_str() {
        "find_movie_sources" => {
            find_movie_sources(&req.title, req.year.as_deref(), cache_dir).await
        }
        "find_episode_sources" => {
            let (Some(season), Some(episode)) = (req.season, req.episode) else {
                return json!({ "error": "season and episode required" }).to_string();
            };
            find_episode_sources(&req.show_title, season, episode, cache_dir).await
        }
        other => Err(format!("unknown action: {other}")),
    };

    match result {
        Ok(matches) => serde_json::to_string(&json!({ "matches": matches }))
            .unwrap_or_else(|_| "{}".into()),
        Err(e) => json!({ "error": e }).to_string(),
    }
}

async fn find_movie_sources(
    title: &str,
    year: Option<&str>,
    cache_dir: Option<&str>,
) -> Result<Vec<Site111477Match>, String> {
    let movies = load_or_fetch("movies", cache_dir).await?;
    let wanted_title = normalize(title);
    let wanted_year = year.filter(|y| !y.is_empty());

    let hit = movies
        .iter()
        .find(|e| {
            wanted_year.is_some_and(|y| {
                e.normalized_title == wanted_title && e.year.as_deref() == Some(y)
            })
        })
        .or_else(|| {
            movies.iter().find(|e| {
                if e.normalized_title != wanted_title {
                    return false;
                }
                match (wanted_year, e.year.as_deref()) {
                    (None, _) | (Some(""), _) => true,
                    (Some(w), Some(y)) => {
                        if let (Ok(wi), Ok(yi)) = (w.parse::<i32>(), y.parse::<i32>()) {
                            (wi - yi).abs() <= 1
                        } else {
                            false
                        }
                    }
                    _ => false,
                }
            })
        })
        .or_else(|| movies.iter().find(|e| e.normalized_title == wanted_title));

    let Some(hit) = hit else {
        return Ok(vec![]);
    };
    list_files_in_folder(&hit.url).await
}

async fn find_episode_sources(
    show_title: &str,
    season: i32,
    episode: i32,
    cache_dir: Option<&str>,
) -> Result<Vec<Site111477Match>, String> {
    let tvs = load_or_fetch("tvs", cache_dir).await?;
    let wanted = normalize(show_title);
    let mut folders: Vec<&Entry> = tvs
        .iter()
        .filter(|e| e.normalized_title == wanted)
        .collect();
    if folders.is_empty() {
        folders = tvs
            .iter()
            .filter(|e| e.normalized_title.starts_with(&wanted))
            .collect();
    }
    if folders.is_empty() {
        return Ok(vec![]);
    }

    let ep_tag = episode_tag(season, episode).to_lowercase();
    let mut out = Vec::new();
    for folder in folders {
        let season_href = format!("{}Season {season}/", folder.url);
        let season_url = normalize_url(&season_href);
        let files = match fetch_listing(&season_url).await {
            Ok(f) => f,
            Err(_) => continue,
        };
        for f in files {
            if f.is_dir || !f.raw_name.to_lowercase().contains(&ep_tag) {
                continue;
            }
            out.push(Site111477Match {
                file_url: absolute(&f.url),
                file_name: f.raw_name.clone(),
                size_bytes: f.size_bytes,
            });
        }
        if !out.is_empty() {
            break;
        }
    }
    sort_by_quality(&mut out);
    Ok(out)
}

async fn list_files_in_folder(folder_rel_url: &str) -> Result<Vec<Site111477Match>, String> {
    let url = absolute(folder_rel_url);
    let entries = fetch_listing(&url).await?;
    let mut out = Vec::new();
    for e in entries {
        if e.is_dir {
            continue;
        }
        out.push(Site111477Match {
            file_url: absolute(&e.url),
            file_name: e.raw_name,
            size_bytes: e.size_bytes,
        });
    }
    sort_by_quality(&mut out);
    Ok(out)
}

async fn load_or_fetch(kind: &str, cache_dir: Option<&str>) -> Result<Vec<Entry>, String> {
    let html = if let Some(dir) = cache_dir {
        let path = Path::new(dir).join(format!("{kind}.html"));
        if path.exists() {
            if let Ok(meta) = fs::metadata(&path) {
                if let Ok(modified) = meta.modified() {
                    if let Ok(elapsed) = modified.duration_since(UNIX_EPOCH) {
                        let now = SystemTime::now()
                            .duration_since(UNIX_EPOCH)
                            .unwrap_or_default()
                            .as_secs();
                        if now.saturating_sub(elapsed.as_secs()) < CACHE_TTL_SECS {
                            if let Ok(cached) = fs::read_to_string(&path) {
                                return Ok(parse_entries(&cached));
                            }
                        }
                    }
                }
            }
        }
        let fetched = fetch_html(&format!("{BASE_URL}/{kind}/")).await?;
        let _ = fs::create_dir_all(dir);
        let _ = fs::write(&path, &fetched);
        fetched
    } else {
        fetch_html(&format!("{BASE_URL}/{kind}/")).await?
    };
    Ok(parse_entries(&html))
}

async fn fetch_listing(url: &str) -> Result<Vec<Entry>, String> {
    let html = fetch_html(url).await?;
    Ok(parse_entries(&html))
}

async fn fetch_html(url: &str) -> Result<String, String> {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(60))
        .redirect(reqwest::redirect::Policy::limited(10))
        .build()
        .map_err(|e| e.to_string())?;

    let mut attempt = 0u32;
    loop {
        attempt += 1;
        let res = client
            .get(url)
            .header(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
                 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            )
            .header("Accept", "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8")
            .send()
            .await
            .map_err(|e| e.to_string())?;

        let status = res.status().as_u16();
        let body = res.text().await.map_err(|e| e.to_string())?;
        let is_limited = status == 429
            || (500..600).contains(&status)
            || (body.len() < 65536 && is_cloudflare_1015(&body));

        if !is_limited && (200..400).contains(&status) {
            return Ok(body);
        }
        if attempt > MAX_RATE_LIMIT_RETRIES {
            return Err(format!(
                "111477 fetch failed ({status}) after {attempt} tries: {url}"
            ));
        }
        sleep(Duration::from_millis(RATE_LIMIT_WAIT_MS)).await;
    }
}

fn is_cloudflare_1015(text: &str) -> bool {
    !text.is_empty() && CF_1015_RE.is_match(text)
}

fn parse_entries(html: &str) -> Vec<Entry> {
    let mut out = Vec::new();
    for caps in ROW_RE.captures_iter(html) {
        let name = decode_html(caps.get(1).map(|m| m.as_str()).unwrap_or(""));
        let url = decode_html(caps.get(2).map(|m| m.as_str()).unwrap_or(""));
        let end = caps.get(0).map(|m| m.end()).unwrap_or(0);
        let tail_end = (end + 800).min(html.len());
        let size = SIZE_RE
            .captures(&html[end..tail_end])
            .and_then(|c| c.get(1))
            .and_then(|m| m.as_str().parse::<i64>().ok())
            .unwrap_or(-1);
        out.push(Entry {
            raw_name: name.clone(),
            url: url.clone(),
            is_dir: url.ends_with('/'),
            size_bytes: size,
            normalized_title: normalize(&strip_year_and_ext(&name)),
            year: extract_year(&name),
        });
    }
    out
}

fn decode_html(s: &str) -> String {
    s.replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&#x27;", "'")
        .replace("&#x2F;", "/")
}

fn strip_diacritics(s: &str) -> String {
    static MAP: LazyLock<HashMap<char, &str>> = LazyLock::new(|| {
        let pairs: &[(&str, &str)] = &[
            ("á", "a"), ("à", "a"), ("ä", "a"), ("â", "a"), ("ã", "a"), ("å", "a"), ("ā", "a"),
            ("Á", "a"), ("À", "a"), ("Ä", "a"), ("Â", "a"), ("Ã", "a"), ("Å", "a"), ("Ā", "a"),
            ("é", "e"), ("è", "e"), ("ë", "e"), ("ê", "e"), ("ē", "e"), ("ę", "e"),
            ("É", "e"), ("È", "e"), ("Ë", "e"), ("Ê", "e"), ("Ē", "e"),
            ("í", "i"), ("ì", "i"), ("ï", "i"), ("î", "i"), ("ī", "i"),
            ("Í", "i"), ("Ì", "i"), ("Ï", "i"), ("Î", "i"), ("Ī", "i"),
            ("ó", "o"), ("ò", "o"), ("ö", "o"), ("ô", "o"), ("õ", "o"), ("ø", "o"), ("ō", "o"),
            ("Ó", "o"), ("Ò", "o"), ("Ö", "o"), ("Ô", "o"), ("Õ", "o"), ("Ø", "o"), ("Ō", "o"),
            ("ú", "u"), ("ù", "u"), ("ü", "u"), ("û", "u"), ("ū", "u"),
            ("Ú", "u"), ("Ù", "u"), ("Ü", "u"), ("Û", "u"), ("Ū", "u"),
            ("ý", "y"), ("ÿ", "y"), ("ñ", "n"), ("Ñ", "n"), ("ç", "c"), ("Ç", "c"),
            ("ß", "ss"), ("æ", "ae"), ("Æ", "ae"), ("œ", "oe"), ("Œ", "oe"),
        ];
        pairs.iter().flat_map(|(k, v)| k.chars().map(move |c| (c, *v))).collect()
    });
    let mut out = String::new();
    for ch in s.chars() {
        if let Some(rep) = MAP.get(&ch) {
            out.push_str(rep);
        } else {
            out.push(ch);
        }
    }
    out
}

fn normalize(input: &str) -> String {
    let mut s = strip_diacritics(input).to_lowercase();
    s = s.replace('&', " and ");
    s = s.replace(['\'', '\u{2018}', '\u{2019}', '\u{02BC}', '\u{201B}', '`'], "");
    let s = NON_ALNUM_RE.replace_all(&s, " ").to_string();
    WS_RE.replace_all(s.trim(), " ").to_string()
}

fn extract_year(name: &str) -> Option<String> {
    YEAR_RE
        .captures(name.trim())
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().to_string())
}

fn strip_year_and_ext(name: &str) -> String {
    let mut s = YEAR_RE.replace(name.trim(), "").to_string();
    s = EXT_RE.replace(&s, "").to_string();
    s.trim().to_string()
}

fn episode_tag(season: i32, episode: i32) -> String {
    format!("S{season:02}E{episode:02}")
}

fn quality_score(name: &str) -> i32 {
    let n = name.to_lowercase();
    if n.contains("2160p") || n.contains("4k") {
        4
    } else if n.contains("1080p") {
        3
    } else if n.contains("720p") {
        2
    } else if n.contains("480p") {
        1
    } else {
        0
    }
}

fn sort_by_quality(list: &mut [Site111477Match]) {
    list.sort_by(|a, b| {
        let qa = quality_score(&a.file_name);
        let qb = quality_score(&b.file_name);
        qb.cmp(&qa).then(b.size_bytes.cmp(&a.size_bytes))
    });
}

fn absolute(maybe_relative: &str) -> String {
    if maybe_relative.starts_with("http") {
        maybe_relative.to_string()
    } else {
        format!("{BASE_URL}{maybe_relative}")
    }
}

fn normalize_url(href: &str) -> String {
    absolute(href)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_collapses_titles() {
        assert_eq!(normalize("Spider-Man: No Way Home"), "spider man no way home");
        assert_eq!(normalize("Tom & Jerry"), "tom and jerry");
    }

    #[test]
    fn rejects_unknown_action() {
        let raw = request_json_blocking(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }
}
