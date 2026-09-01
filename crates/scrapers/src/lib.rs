use regex::Regex;
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
    fn dedup_keeps_first_per_infohash() {
        let rows = vec![
            TorrentSearchResult {
                name: "a".into(),
                magnet: "magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".into(),
                seeders: "1".into(),
                size: "1 GB".into(),
                source: "A".into(),
            },
            TorrentSearchResult {
                name: "b".into(),
                magnet: "magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".into(),
                seeders: "2".into(),
                size: "2 GB".into(),
                source: "B".into(),
            },
        ];
        assert_eq!(dedup_by_infohash(rows).len(), 1);
    }
}
