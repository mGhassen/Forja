use crate::providers::{self, SearchRequest};
use crate::{
    dedup_by_infohash, parse_knaben_html, parse_tpb_html, parse_uindex_html, TorrentSearchResult,
};
use std::time::Duration;

const USER_AGENT: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

const KNABEN_BASE: &str = "https://knaben.org";
const TPB_BASE: &str = "https://1.piratebays.to";
const UINDEX_BASE: &str = "https://uindex.org";
const TPB_MAX_PAGES: usize = 10;
const SCRAPER_TIMEOUT_SECS: u64 = 15;

fn parse_seeders(seeders: &str) -> i64 {
    let cleaned: String = seeders.chars().filter(|c| c.is_ascii_digit()).collect();
    cleaned.parse().unwrap_or(-1)
}

fn sort_by_seeders(mut results: Vec<TorrentSearchResult>) -> Vec<TorrentSearchResult> {
    results.sort_by(|a, b| parse_seeders(&b.seeders).cmp(&parse_seeders(&a.seeders)));
    results
}

async fn fetch_html(client: &reqwest::Client, url: &str) -> Result<String, String> {
    utils::engine_cancel::with_cancel(async {
        let resp = client
            .get(url)
            .header("User-Agent", USER_AGENT)
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

async fn search_knaben_html(client: &reqwest::Client, query: &str) -> Vec<TorrentSearchResult> {
    let encoded = urlencoding::encode(query);
    let url = format!("{KNABEN_BASE}/search/{encoded}/0/1/seeders");
    match fetch_html(client, &url).await {
        Ok(html) => parse_knaben_html(&html),
        Err(_) => Vec::new(),
    }
}

async fn search_uindex(client: &reqwest::Client, query: &str) -> Vec<TorrentSearchResult> {
    let encoded = urlencoding::encode(query);
    let url = format!("{UINDEX_BASE}/search.php?search={encoded}&c=0");
    match fetch_html(client, &url).await {
        Ok(html) => parse_uindex_html(&html),
        Err(_) => Vec::new(),
    }
}

/// Legacy HTML TPB mirror — kept as fallback if apibay fails inside providers.
#[allow(dead_code)]
async fn search_tpb_html(client: &reqwest::Client, query: &str) -> Vec<TorrentSearchResult> {
    let encoded = urlencoding::encode(query);
    let mut all = Vec::new();
    for page in 1..=TPB_MAX_PAGES {
        if utils::engine_cancel::is_requested() {
            break;
        }
        let url = if page == 1 {
            format!("{TPB_BASE}/s/?q={encoded}&video=on&category=0")
        } else {
            format!("{TPB_BASE}/s/page/{page}/?q={encoded}&video=on&category=0")
        };
        let html = match fetch_html(client, &url).await {
            Ok(h) => h,
            Err(_) => break,
        };
        let parsed = parse_tpb_html(&html, "ThePirateBay");
        if parsed.is_empty() {
            break;
        }
        all.extend(parsed);
    }
    all
}

fn is_enabled(enabled: &[String], id: &str) -> bool {
    enabled.iter().any(|e| e == id)
}

/// Search enabled providers in parallel, dedup by infohash (keep highest seeders), sort.
pub async fn search_all(query: &str) -> Vec<TorrentSearchResult> {
    search_request(&SearchRequest::from_query(query)).await
}

pub async fn search_request(req: &SearchRequest) -> Vec<TorrentSearchResult> {
    let query = req.query.trim();
    let imdb_only = req.imdb_id.is_some() && is_enabled(&req.enabled, "torrentio");
    if query.is_empty() && !imdb_only {
        return Vec::new();
    }

    let client = match reqwest::Client::builder()
        .timeout(Duration::from_secs(SCRAPER_TIMEOUT_SECS))
        .redirect(reqwest::redirect::Policy::limited(8))
        .user_agent(USER_AGENT)
        .build()
    {
        Ok(c) => c,
        Err(_) => return Vec::new(),
    };

    let enabled = &req.enabled;
    let (
        knaben_api,
        knaben_html,
        tpb,
        uindex,
        csv,
        nyaa,
        yts,
        solid,
        rarbg,
        torrentio,
    ) = tokio::join!(
        async {
            if is_enabled(enabled, "knaben") && !query.is_empty() {
                providers::search_knaben_api(&client, query).await
            } else {
                Vec::new()
            }
        },
        async {
            if is_enabled(enabled, "knaben") && !query.is_empty() {
                search_knaben_html(&client, query).await
            } else {
                Vec::new()
            }
        },
        async {
            if is_enabled(enabled, "pirate_bay") && !query.is_empty() {
                let api = providers::search_pirate_bay(&client, query).await;
                if api.is_empty() {
                    search_tpb_html(&client, query).await
                } else {
                    api
                }
            } else {
                Vec::new()
            }
        },
        async {
            if is_enabled(enabled, "uindex") && !query.is_empty() {
                search_uindex(&client, query).await
            } else {
                Vec::new()
            }
        },
        async {
            if is_enabled(enabled, "torrents_csv") && !query.is_empty() {
                providers::search_torrents_csv(&client, query).await
            } else {
                Vec::new()
            }
        },
        async {
            if is_enabled(enabled, "nyaa") && !query.is_empty() {
                providers::search_nyaa(&client, query).await
            } else {
                Vec::new()
            }
        },
        async {
            if is_enabled(enabled, "yts") && !query.is_empty() {
                providers::search_yts(&client, query).await
            } else {
                Vec::new()
            }
        },
        async {
            if is_enabled(enabled, "solid_torrents") && !query.is_empty() {
                providers::search_solid_torrents(&client, query).await
            } else {
                Vec::new()
            }
        },
        async {
            if is_enabled(enabled, "therarbg") && !query.is_empty() {
                providers::search_therarbg(&client, query).await
            } else {
                Vec::new()
            }
        },
        async {
            if is_enabled(enabled, "torrentio") {
                if let Some(ref imdb) = req.imdb_id {
                    providers::search_torrentio(&client, imdb, req.season, req.episode).await
                } else {
                    Vec::new()
                }
            } else {
                Vec::new()
            }
        },
    );

    let knaben = if knaben_api.is_empty() {
        knaben_html
    } else {
        knaben_api
    };

    let mut aggregated = Vec::new();
    aggregated.extend(knaben);
    aggregated.extend(tpb);
    aggregated.extend(uindex);
    aggregated.extend(csv);
    aggregated.extend(nyaa);
    aggregated.extend(yts);
    aggregated.extend(solid);
    aggregated.extend(rarbg);
    aggregated.extend(torrentio);

    // Highest seeders first, then dedup keeps the best copy.
    dedup_by_infohash(sort_by_seeders(aggregated))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    #[ignore = "network"]
    async fn search_all_live_smoke() {
        let results = search_all("matrix").await;
        assert!(!results.is_empty());
    }

    #[tokio::test]
    #[ignore = "network"]
    async fn search_enabled_subset() {
        let req = SearchRequest {
            query: "matrix".into(),
            enabled: vec!["torrents_csv".into()],
            imdb_id: None,
            season: None,
            episode: None,
        };
        let results = search_request(&req).await;
        assert!(results.iter().all(|r| r.source == "Torrents CSV"));
    }
}
