mod providers;
mod search;

pub use providers::{all_provider_ids, display_name, SearchRequest, PROVIDER_IDS};
pub use search::{search_all, search_request};

use regex::Regex;
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TorrentSearchResult {
    pub name: String,
    pub magnet: String,
    pub seeders: String,
    pub size: String,
    pub source: String,
}

pub fn parse_knaben_html(html: &str) -> Vec<TorrentSearchResult> {
    let document = Html::parse_document(html);
    let row_sel = Selector::parse("tbody tr").unwrap();
    let mut results = Vec::new();
    for row in document.select(&row_sel) {
        let title_sel = Selector::parse(r#"td.text-wrap a[href^="magnet:"]"#).unwrap();
        let title_link = row.select(&title_sel).next();
        let Some(link) = title_link else { continue };
        let title = link
            .value()
            .attr("title")
            .map(|s| s.to_string())
            .unwrap_or_else(|| link.text().collect::<String>().trim().to_string());
        let magnet = link.value().attr("href").unwrap_or("").to_string();
        if magnet.is_empty() {
            continue;
        }
        let cells: Vec<_> = row.select(&Selector::parse("td").unwrap()).collect();
        let size = cells
            .get(1)
            .map(|c| c.text().collect::<String>().trim().to_string())
            .unwrap_or_else(|| "Unknown".into());
        let seeders = if cells.len() >= 3 {
            cells[cells.len() - 3]
                .text()
                .collect::<String>()
                .trim()
                .to_string()
        } else {
            "Unknown".into()
        };
        results.push(TorrentSearchResult {
            name: title,
            magnet,
            seeders,
            size,
            source: "Knaben".into(),
        });
    }
    results
}

pub fn parse_tpb_html(html: &str, source: &str) -> Vec<TorrentSearchResult> {
    let document = Html::parse_document(html);
    let row_sel = Selector::parse("table tr").unwrap();
    let mut results = Vec::new();
    for row in document.select(&row_sel) {
        if !row.select(&Selector::parse("th").unwrap()).collect::<Vec<_>>().is_empty() {
            continue;
        }
        let title_link = row.select(&Selector::parse("a.detLink").unwrap()).next();
        let magnet_link = row
            .select(&Selector::parse(r#"a[href^="magnet:"]"#).unwrap())
            .next();
        let (Some(title_link), Some(magnet_link)) = (title_link, magnet_link) else {
            continue;
        };
        let title = title_link.text().collect::<String>().trim().to_string();
        let magnet = magnet_link.value().attr("href").unwrap_or("").to_string();
        if magnet.is_empty() {
            continue;
        }
        let cells: Vec<_> = row.select(&Selector::parse("td").unwrap()).collect();
        let size = cells
            .get(4)
            .map(|c| c.text().collect::<String>().trim().to_string())
            .unwrap_or_else(|| "Unknown".into());
        let seeders = cells
            .get(5)
            .map(|c| c.text().collect::<String>().trim().to_string())
            .unwrap_or_else(|| "Unknown".into());
        results.push(TorrentSearchResult {
            name: title,
            magnet,
            seeders,
            size,
            source: source.into(),
        });
    }
    results
}

pub fn parse_uindex_html(html: &str) -> Vec<TorrentSearchResult> {
    let document = Html::parse_document(html);
    let row_sel = Selector::parse("table tr").unwrap();
    let mut results = Vec::new();
    for row in document.select(&row_sel) {
        if !row.select(&Selector::parse("th").unwrap()).collect::<Vec<_>>().is_empty() {
            continue;
        }
        let cells: Vec<_> = row.select(&Selector::parse("td").unwrap()).collect();
        if cells.len() < 5 {
            continue;
        }
        let title_cell = &cells[1];
        let magnet = title_cell
            .select(&Selector::parse(r#"a[href^="magnet:"]"#).unwrap())
            .next()
            .and_then(|a| a.value().attr("href"))
            .unwrap_or("")
            .to_string();
        let title = title_cell
            .select(&Selector::parse(r#"a[href*="/details.php"]"#).unwrap())
            .next()
            .map(|a| a.text().collect::<String>().trim().to_string())
            .unwrap_or_default();
        if title.is_empty() || magnet.is_empty() {
            continue;
        }
        let size = cells[2].text().collect::<String>().trim().to_string();
        let seeders = cells[3]
            .select(&Selector::parse("span.g").unwrap())
            .next()
            .map(|s| s.text().collect::<String>().trim().to_string())
            .unwrap_or_else(|| cells[3].text().collect::<String>().trim().to_string())
            .replace(',', "");
        results.push(TorrentSearchResult {
            name: title,
            magnet,
            seeders: if seeders.is_empty() {
                "Unknown".into()
            } else {
                seeders
            },
            size: if size.is_empty() {
                "Unknown".into()
            } else {
                size
            },
            source: "UIndex".into(),
        });
    }
    results
}

pub fn dedup_by_infohash(results: Vec<TorrentSearchResult>) -> Vec<TorrentSearchResult> {
    let infohash_re = Regex::new(r"(?i)btih:([a-f0-9]{40})").unwrap();
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for r in results {
        let hash = infohash_re
            .captures(&r.magnet)
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().to_lowercase());
        if let Some(h) = hash {
            if !seen.insert(h) {
                continue;
            }
        }
        out.push(r);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_knaben_row() {
        let html = r#"<table><tbody><tr>
<td class="text-wrap"><a href="magnet:?xt=urn:btih:abc" title="Movie 1080p">Movie</a></td>
<td>2 GB</td><td></td><td>100</td>
</tr></tbody></table>"#;
        let r = parse_knaben_html(html);
        assert_eq!(r.len(), 1);
        assert!(r[0].magnet.starts_with("magnet:"));
    }
}
