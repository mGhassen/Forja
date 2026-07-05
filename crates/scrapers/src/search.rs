use crate::{dedup_by_infohash, parse_knaben_html, parse_tpb_html, parse_uindex_html, TorrentSearchResult};
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
}

async fn search_knaben(client: &reqwest::Client, query: &str) -> Vec<TorrentSearchResult> {
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

async fn search_tpb(client: &reqwest::Client, query: &str) -> Vec<TorrentSearchResult> {
    let encoded = urlencoding::encode(query);
    let mut all = Vec::new();
    for page in 1..=TPB_MAX_PAGES {
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

/// Search knaben + TPB + uindex in parallel, dedup by infohash, sort by seeders.
pub async fn search_all(query: &str) -> Vec<TorrentSearchResult> {
    let query = query.trim();
    if query.is_empty() {
        return Vec::new();
    }

    let client = match reqwest::Client::builder()
        .timeout(Duration::from_secs(SCRAPER_TIMEOUT_SECS))
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
    {
        Ok(c) => c,
        Err(_) => return Vec::new(),
    };

    let (knaben, tpb, uindex) = tokio::join!(
        search_knaben(&client, query),
        search_tpb(&client, query),
        search_uindex(&client, query),
    );

    let mut aggregated = Vec::new();
    aggregated.extend(knaben);
    aggregated.extend(tpb);
    aggregated.extend(uindex);

    sort_by_seeders(dedup_by_infohash(aggregated))
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
}
