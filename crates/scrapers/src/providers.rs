//! Builtin torrent search providers.

use crate::TorrentSearchResult;
use regex::Regex;
use serde_json::Value;

pub const PROVIDER_IDS: &[&str] = &[
    "knaben",
    "pirate_bay",
    "uindex",
    "torrents_csv",
    "nyaa",
    "yts",
    "solid_torrents",
    "therarbg",
    "torrentio",
];

pub fn display_name(id: &str) -> &'static str {
    match id {
        "knaben" => "Knaben",
        "pirate_bay" => "ThePirateBay",
        "uindex" => "UIndex",
        "torrents_csv" => "Torrents CSV",
        "nyaa" => "Nyaa",
        "yts" => "YTS",
        "solid_torrents" => "SolidTorrents",
        "therarbg" => "TheRARBG",
        "torrentio" => "Torrentio",
        _ => "Unknown",
    }
}

pub fn all_provider_ids() -> Vec<String> {
    PROVIDER_IDS.iter().map(|s| (*s).to_string()).collect()
}

#[derive(Debug, Clone, Default)]
pub struct SearchRequest {
    pub query: String,
    pub enabled: Vec<String>,
    pub imdb_id: Option<String>,
    pub season: Option<i32>,
    pub episode: Option<i32>,
}

impl SearchRequest {
    pub fn from_query(query: &str) -> Self {
        Self {
            query: query.to_string(),
            enabled: all_provider_ids(),
            imdb_id: None,
            season: None,
            episode: None,
        }
    }

    pub fn parse(input: &str) -> Self {
        let trimmed = input.trim();
        if !trimmed.starts_with('{') {
            return Self::from_query(trimmed);
        }
        let Ok(v) = serde_json::from_str::<Value>(trimmed) else {
            return Self::from_query(trimmed);
        };
        let query = v
            .get("query")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        let enabled = match v.get("enabled") {
            Some(Value::Array(arr)) => arr
                .iter()
                .filter_map(|x| x.as_str().map(|s| s.to_string()))
                .collect(),
            Some(Value::String(s)) => s
                .split(',')
                .map(|p| p.trim().to_string())
                .filter(|p| !p.is_empty())
                .collect(),
            _ => all_provider_ids(),
        };
        let imdb_id = v
            .get("imdb_id")
            .and_then(|x| x.as_str())
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());
        let season = v.get("season").and_then(|x| x.as_i64()).map(|n| n as i32);
        let episode = v.get("episode").and_then(|x| x.as_i64()).map(|n| n as i32);
        Self {
            query,
            enabled: if enabled.is_empty() {
                all_provider_ids()
            } else {
                enabled
            },
            imdb_id,
            season,
            episode,
        }
    }

    }

fn magnet_from_hash(hash: &str, name: &str) -> String {
    let h = hash.trim().to_lowercase();
    format!(
        "magnet:?xt=urn:btih:{}&dn={}",
        h,
        urlencoding::encode(name)
    )
}

fn format_bytes(bytes: u64) -> String {
    const KB: f64 = 1024.0;
    const MB: f64 = KB * 1024.0;
    const GB: f64 = MB * 1024.0;
    const TB: f64 = GB * 1024.0;
    let b = bytes as f64;
    if b >= TB {
        format!("{:.2} TB", b / TB)
    } else if b >= GB {
        format!("{:.2} GB", b / GB)
    } else if b >= MB {
        format!("{:.1} MB", b / MB)
    } else if b >= KB {
        format!("{:.0} KB", b / KB)
    } else {
        format!("{bytes} B")
    }
}

fn json_i64(v: &Value) -> Option<i64> {
    v.as_i64()
        .or_else(|| v.as_u64().map(|n| n as i64))
        .or_else(|| v.as_f64().map(|n| n as i64))
        .or_else(|| v.as_str()?.parse().ok())
}

fn json_u64(v: &Value) -> Option<u64> {
    v.as_u64()
        .or_else(|| v.as_i64().map(|n| n.max(0) as u64))
        .or_else(|| v.as_f64().map(|n| n.max(0.0) as u64))
        .or_else(|| v.as_str()?.parse().ok())
}

async fn fetch_text(client: &reqwest::Client, url: &str) -> Result<String, String> {
    utils::engine_cancel::with_cancel(async {
        let resp = client
            .get(url)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        if !resp.status().is_success() {
            return Err(format!("HTTP {}", resp.status()));
        }
        resp.text().await.map_err(|e| e.to_string())
    })
    .await
}

async fn fetch_json(client: &reqwest::Client, url: &str) -> Result<Value, String> {
    let text = fetch_text(client, url).await?;
    serde_json::from_str(&text).map_err(|e| e.to_string())
}

/// Jina Reader wraps origin JSON in `{"code":200,"data":{"content":"..."}}`.
fn unwrap_jina(v: Value) -> Value {
    if let Some(content) = v
        .pointer("/data/content")
        .and_then(|c| c.as_str())
    {
        if let Ok(inner) = serde_json::from_str::<Value>(content) {
            return inner;
        }
    }
    v
}

async fn fetch_json_maybe_jina(client: &reqwest::Client, url: &str) -> Result<Value, String> {
    Ok(unwrap_jina(fetch_json(client, url).await?))
}

// ── Knaben (HTML mirror kept for parity; API as primary) ─────────────────────

pub async fn search_knaben_api(
    client: &reqwest::Client,
    query: &str,
) -> Vec<TorrentSearchResult> {
    let body = serde_json::json!({
        "query": query,
        "search_field": "title",
        "size": 100,
        "hide_unsafe": true,
        "hide_xxx": false,
        "from": 0,
    });
    let resp = match utils::engine_cancel::with_cancel(async {
        client
            .post("https://api.knaben.org/v1")
            .json(&body)
            .send()
            .await
            .map_err(|e| e.to_string())
    })
    .await
    {
        Ok(r) => r,
        Err(_) => return Vec::new(),
    };
    if !resp.status().is_success() {
        return Vec::new();
    }
    let Ok(v) = resp.json::<Value>().await else {
        return Vec::new();
    };
    let Some(hits) = v.get("hits").and_then(|h| h.as_array()) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for hit in hits {
        let name = hit
            .get("title")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        let hash = hit
            .get("hash")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        if name.is_empty() || hash.is_empty() {
            continue;
        }
        let size = hit
            .get("bytes")
            .and_then(json_u64)
            .map(format_bytes)
            .unwrap_or_else(|| "Unknown".into());
        let seeders = hit
            .get("seeders")
            .and_then(json_i64)
            .map(|n| n.to_string())
            .unwrap_or_else(|| "0".into());
        out.push(TorrentSearchResult {
            name: name.clone(),
            magnet: magnet_from_hash(&hash, &name),
            seeders,
            size,
            source: display_name("knaben").into(),
        });
    }
    out
}

// ── Pirate Bay (apibay) ──────────────────────────────────────────────────────

pub async fn search_pirate_bay(
    client: &reqwest::Client,
    query: &str,
) -> Vec<TorrentSearchResult> {
    let encoded = urlencoding::encode(query);
    let url = format!("https://apibay.org/q.php?q={encoded}");
    let Ok(v) = fetch_json(client, &url).await else {
        return Vec::new();
    };
    let Some(arr) = v.as_array() else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for item in arr {
        let name = item
            .get("name")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        if name.is_empty() || name == "No results returned" {
            continue;
        }
        let hash = item
            .get("info_hash")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        if hash.is_empty() {
            continue;
        }
        let size = item
            .get("size")
            .and_then(json_u64)
            .map(format_bytes)
            .unwrap_or_else(|| "Unknown".into());
        let seeders = item
            .get("seeders")
            .and_then(json_i64)
            .map(|n| n.to_string())
            .unwrap_or_else(|| "0".into());
        out.push(TorrentSearchResult {
            name: name.clone(),
            magnet: magnet_from_hash(&hash, &name),
            seeders,
            size,
            source: display_name("pirate_bay").into(),
        });
    }
    out
}

// ── Torrents CSV ─────────────────────────────────────────────────────────────

pub async fn search_torrents_csv(
    client: &reqwest::Client,
    query: &str,
) -> Vec<TorrentSearchResult> {
    let encoded = urlencoding::encode(query);
    let url = format!("https://torrents-csv.com/service/search?q={encoded}");
    let Ok(v) = fetch_json(client, &url).await else {
        return Vec::new();
    };
    let Some(arr) = v.get("torrents").and_then(|t| t.as_array()) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for item in arr.iter().take(100) {
        let name = item
            .get("name")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        let hash = item
            .get("infohash")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        if name.is_empty() || hash.is_empty() {
            continue;
        }
        let size = item
            .get("size_bytes")
            .and_then(json_u64)
            .map(format_bytes)
            .unwrap_or_else(|| "Unknown".into());
        let seeders = item
            .get("seeders")
            .and_then(json_i64)
            .map(|n| n.to_string())
            .unwrap_or_else(|| "0".into());
        out.push(TorrentSearchResult {
            name: name.clone(),
            magnet: magnet_from_hash(&hash, &name),
            seeders,
            size,
            source: display_name("torrents_csv").into(),
        });
    }
    out
}

// ── Nyaa (RSS) ───────────────────────────────────────────────────────────────

pub async fn search_nyaa(client: &reqwest::Client, query: &str) -> Vec<TorrentSearchResult> {
    let encoded = urlencoding::encode(query);
    let url = format!("https://nyaa.si/?page=rss&q={encoded}");
    let Ok(xml) = fetch_text(client, &url).await else {
        return Vec::new();
    };
    parse_nyaa_rss(&xml)
}

fn parse_nyaa_rss(xml: &str) -> Vec<TorrentSearchResult> {
    let item_re = Regex::new(r"(?s)<item>(.*?)</item>").unwrap();
    let title_re = Regex::new(r"(?s)<title>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>").unwrap();
    let hash_re = Regex::new(r"(?is)<nyaa:infoHash>(.*?)</nyaa:infoHash>").unwrap();
    let size_re = Regex::new(r"(?is)<nyaa:size>(.*?)</nyaa:size>").unwrap();
    let seed_re = Regex::new(r"(?is)<nyaa:seeders>(.*?)</nyaa:seeders>").unwrap();
    let mut out = Vec::new();
    for cap in item_re.captures_iter(xml) {
        let block = cap.get(1).map(|m| m.as_str()).unwrap_or("");
        let name = title_re
            .captures(block)
            .and_then(|c| c.get(1))
            .map(|m| html_unescape(m.as_str().trim()))
            .unwrap_or_default();
        let hash = hash_re
            .captures(block)
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().trim().to_string())
            .unwrap_or_default();
        if name.is_empty() || hash.is_empty() {
            continue;
        }
        let size = size_re
            .captures(block)
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().trim().to_string())
            .unwrap_or_else(|| "Unknown".into());
        let seeders = seed_re
            .captures(block)
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().trim().to_string())
            .unwrap_or_else(|| "0".into());
        out.push(TorrentSearchResult {
            name: name.clone(),
            magnet: magnet_from_hash(&hash, &name),
            seeders,
            size,
            source: display_name("nyaa").into(),
        });
    }
    out
}

fn html_unescape(s: &str) -> String {
    s.replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
}

// ── YTS ──────────────────────────────────────────────────────────────────────

pub async fn search_yts(client: &reqwest::Client, query: &str) -> Vec<TorrentSearchResult> {
    let encoded = urlencoding::encode(query);
    let direct = format!(
        "https://yts.mx/api/v2/list_movies.json?query_term={encoded}&limit=50"
    );
    let jina = format!(
        "https://r.jina.ai/http://yts.mx/api/v2/list_movies.json?query_term={encoded}&limit=50"
    );
    let v = match fetch_json(client, &direct).await {
        Ok(v) => v,
        Err(_) => match fetch_json_maybe_jina(client, &jina).await {
            Ok(v) => v,
            Err(_) => return Vec::new(),
        },
    };
    parse_yts_movies(&v)
}

fn parse_yts_movies(v: &Value) -> Vec<TorrentSearchResult> {
    let Some(movies) = v.pointer("/data/movies").and_then(|m| m.as_array()) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for movie in movies {
        let title = movie
            .get("title_long")
            .or_else(|| movie.get("title"))
            .and_then(|x| x.as_str())
            .unwrap_or("Unknown");
        let Some(torrents) = movie.get("torrents").and_then(|t| t.as_array()) else {
            continue;
        };
        for t in torrents {
            let hash = t
                .get("hash")
                .and_then(|x| x.as_str())
                .unwrap_or("")
                .to_string();
            if hash.is_empty() {
                continue;
            }
            let quality = t.get("quality").and_then(|x| x.as_str()).unwrap_or("");
            let typ = t.get("type").and_then(|x| x.as_str()).unwrap_or("");
            let name = format!("{title} [{quality} {typ}]")
                .trim()
                .to_string();
            let size = t
                .get("size_bytes")
                .and_then(json_u64)
                .map(format_bytes)
                .or_else(|| {
                    t.get("size")
                        .and_then(|x| x.as_str())
                        .map(|s| s.to_string())
                })
                .unwrap_or_else(|| "Unknown".into());
            let seeders = t
                .get("seeds")
                .and_then(json_i64)
                .map(|n| n.to_string())
                .unwrap_or_else(|| "0".into());
            out.push(TorrentSearchResult {
                name: name.clone(),
                magnet: magnet_from_hash(&hash, &name),
                seeders,
                size,
                source: display_name("yts").into(),
            });
        }
    }
    out
}

// ── SolidTorrents ────────────────────────────────────────────────────────────

pub async fn search_solid_torrents(
    client: &reqwest::Client,
    query: &str,
) -> Vec<TorrentSearchResult> {
    let encoded = urlencoding::encode(query);
    let direct = format!(
        "https://solidtorrents.to/api/v1/search?q={encoded}&limit=100&sort=seeders"
    );
    let jina = format!(
        "https://r.jina.ai/https://solidtorrents.to/api/v1/search?q={encoded}&limit=100&sort=seeders"
    );
    let v = match fetch_json(client, &direct).await {
        Ok(v) => v,
        Err(_) => match fetch_json_maybe_jina(client, &jina).await {
            Ok(v) => v,
            Err(_) => return Vec::new(),
        },
    };
    let Some(results) = v.get("results").and_then(|r| r.as_array()) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for item in results {
        let name = item
            .get("title")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        let hash = item
            .get("infohash")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        if name.is_empty() || hash.is_empty() {
            continue;
        }
        let size = item
            .get("size")
            .and_then(json_u64)
            .map(format_bytes)
            .unwrap_or_else(|| "Unknown".into());
        let seeders = item
            .get("seeders")
            .and_then(json_i64)
            .map(|n| n.to_string())
            .unwrap_or_else(|| "0".into());
        out.push(TorrentSearchResult {
            name: name.clone(),
            magnet: magnet_from_hash(&hash, &name),
            seeders,
            size,
            source: display_name("solid_torrents").into(),
        });
    }
    out
}

// ── TheRARBG (codetabs proxy) ────────────────────────────────────────────────

pub async fn search_therarbg(
    client: &reqwest::Client,
    query: &str,
) -> Vec<TorrentSearchResult> {
    let encoded = urlencoding::encode(query);
    let quest = format!("https://therarbg.to/get-posts/keywords:{encoded}:format:json/?page=1");
    let url = format!(
        "https://api.codetabs.com/v1/proxy?quest={}",
        urlencoding::encode(&quest)
    );
    let Ok(v) = fetch_json(client, &url).await else {
        return Vec::new();
    };
    let Some(results) = v.get("results").and_then(|r| r.as_array()) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for item in results {
        let name = item
            .get("n")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        let hash = item
            .get("h")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        if name.is_empty() || hash.is_empty() {
            continue;
        }
        let size = item
            .get("s")
            .and_then(json_u64)
            .map(format_bytes)
            .unwrap_or_else(|| "Unknown".into());
        let seeders = item
            .get("se")
            .and_then(json_i64)
            .map(|n| n.to_string())
            .unwrap_or_else(|| "0".into());
        out.push(TorrentSearchResult {
            name: name.clone(),
            magnet: magnet_from_hash(&hash, &name),
            seeders,
            size,
            source: display_name("therarbg").into(),
        });
    }
    out
}

// ── Torrentio (IMDb) ─────────────────────────────────────────────────────────

pub async fn search_torrentio(
    client: &reqwest::Client,
    imdb_id: &str,
    season: Option<i32>,
    episode: Option<i32>,
) -> Vec<TorrentSearchResult> {
    let id = imdb_id.trim();
    if id.is_empty() {
        return Vec::new();
    }
    let url = match (season, episode) {
        (Some(s), Some(e)) if s > 0 && e > 0 => {
            format!("https://torrentio.strem.fun/stream/series/{id}:{s}:{e}.json")
        }
        _ => format!("https://torrentio.strem.fun/stream/movie/{id}.json"),
    };
    let Ok(v) = fetch_json(client, &url).await else {
        return Vec::new();
    };
    let Some(streams) = v.get("streams").and_then(|s| s.as_array()) else {
        return Vec::new();
    };
    let seed_re = Regex::new(r"👤\s*(\d+)").unwrap();
    let size_re = Regex::new(r"💾\s*([\d.]+)\s*(KB|MB|GB|TB)").unwrap();
    let mut out = Vec::new();
    for stream in streams {
        let hash = stream
            .get("infoHash")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        if hash.is_empty() {
            continue;
        }
        let raw_title = stream
            .get("title")
            .and_then(|x| x.as_str())
            .unwrap_or("Torrentio")
            .replace('\n', " ");
        let seeders = seed_re
            .captures(&raw_title)
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().to_string())
            .unwrap_or_else(|| "0".into());
        let size = size_re
            .captures(&raw_title)
            .map(|c| {
                format!(
                    "{} {}",
                    c.get(1).map(|m| m.as_str()).unwrap_or("?"),
                    c.get(2).map(|m| m.as_str()).unwrap_or("")
                )
            })
            .unwrap_or_else(|| "Unknown".into());
        out.push(TorrentSearchResult {
            name: raw_title.clone(),
            magnet: magnet_from_hash(&hash, &raw_title),
            seeders,
            size,
            source: display_name("torrentio").into(),
        });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_nested_json_query_like_engine_job() {
        let inner = r#"{"query":"ubuntu","enabled":["torrents_csv"]}"#;
        let payload = serde_json::json!({ "query": inner }).to_string();
        let v: serde_json::Value = serde_json::from_str(&payload).unwrap();
        let q = v.get("query").and_then(|x| x.as_str()).unwrap();
        let req = SearchRequest::parse(q);
        assert_eq!(req.query, "ubuntu");
        assert_eq!(req.enabled, vec!["torrents_csv".to_string()]);
    }

    #[test]
    fn parses_plain_query() {
        let r = SearchRequest::parse("matrix");
        assert_eq!(r.query, "matrix");
        assert!(r.enabled.contains(&"knaben".into()));
    }

    #[test]
    fn parses_json_request() {
        let r = SearchRequest::parse(
            r#"{"query":"matrix","enabled":["nyaa","yts"],"imdb_id":"tt0133093"}"#,
        );
        assert_eq!(r.query, "matrix");
        assert_eq!(r.enabled, vec!["nyaa", "yts"]);
        assert_eq!(r.imdb_id.as_deref(), Some("tt0133093"));
    }

    #[test]
    fn parses_nyaa_rss_item() {
        let xml = r#"<?xml version="1.0"?>
<rss><channel>
<item>
<title><![CDATA[Show S01E01]]></title>
<nyaa:infoHash>ABCDEF0123456789ABCDEF0123456789ABCDEF01</nyaa:infoHash>
<nyaa:size>1.4 GiB</nyaa:size>
<nyaa:seeders>42</nyaa:seeders>
</item>
</channel></rss>"#;
        let r = parse_nyaa_rss(xml);
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].source, "Nyaa");
        assert!(r[0].magnet.contains("btih:abcdef"));
        assert_eq!(r[0].seeders, "42");
    }
}
