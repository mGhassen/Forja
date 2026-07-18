use std::collections::HashSet;

use regex::Regex;
use serde_json::{json, Value};

use super::common::{anime_get, decode_html_entities, jaccard, tokenize, StreamResultOut};

const ORIGIN: &str = "https://watchhentai.net";

fn origin() -> String {
    utils::provider_runtime::api_base("watchhentaiOrigin")
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| ORIGIN.to_string())
}

const UA: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
     (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

const STOPWORDS: &[&str] = &[
    "a", "an", "the", "of", "and", "or", "to", "in", "on", "at", "for", "with", "by", "from", "is",
    "it", "no", "wa", "ga", "ni", "o", "wo", "de", "mo", "ka", "ya", "na", "e", "he", "te", "ne",
    "animation", "anime", "motion", "ova", "ona", "tv", "special", "version", "edition", "dubbed",
    "subbed", "sub", "dub", "uncensored", "censored", "episode", "ep", "season", "side", "part",
    "arc", "chapter", "vol", "volume",
];

struct SearchHit {
    url: String,
    title: String,
}

fn get(url: &str, referer: Option<&str>) -> Result<Option<String>, String> {
    let mut headers = std::collections::HashMap::from([
        ("User-Agent".into(), UA.into()),
        (
            "Accept".into(),
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
                .into(),
        ),
        ("Accept-Language".into(), "en-US,en;q=0.9".into()),
        ("Cache-Control".into(), "no-cache".into()),
    ]);
    if let Some(r) = referer {
        headers.insert("Referer".into(), r.to_string());
    }
    let resp = anime_get(url, &headers, 25)?;
    if resp.status != 200 {
        return Ok(None);
    }
    Ok(Some(resp.body))
}

fn title_variants(t: &str) -> Vec<String> {
    let mut out = HashSet::new();
    out.insert(t.trim().to_string());
    for pat in [":", "\u{2013}", "\u{2014}"] {
        if let Some(idx) = t.find(pat) {
            if idx > 0 {
                out.insert(t[..idx].trim().to_string());
            }
        }
    }
    if let Some(idx) = t.find(" ~") {
        if idx > 0 {
            out.insert(t[..idx].trim().to_string());
        }
    }
    if let Some(idx) = t.find(" - ") {
        if idx > 0 {
            out.insert(t[..idx].trim().to_string());
        }
    }
    if let Some(idx) = t.find('(') {
        if idx > 0 {
            out.insert(t[..idx].trim().to_string());
        }
    }
    if let Some(idx) = t.find('/') {
        if idx > 0 {
            out.insert(t[..idx].trim().to_string());
        }
    }
    let side_re = Regex::new(r"(?i)\s+(?:side|part|arc)\s+").unwrap();
    if let Some(m) = side_re.find(t) {
        if m.start() > 0 {
            out.insert(t[..m.start()].trim().to_string());
        }
    }
    let deco_re = Regex::new(
        r"(?i)\s+(?:the\s+)?(?:animation|motion\s+anime|anime|ova|ona|special)\s*$",
    )
    .unwrap();
    if let Some(m) = deco_re.find(t) {
        let stripped = t[..m.start()].trim();
        if !stripped.is_empty() {
            out.insert(stripped.to_string());
        }
    }
    let words: Vec<&str> = t.trim().split_whitespace().collect();
    if words.len() > 2 {
        out.insert(words[..2].join(" "));
    }
    if words.len() > 3 {
        out.insert(words[..3].join(" "));
    }
    out.into_iter().filter(|s| !s.is_empty()).collect()
}

fn parse_hits(html: &str) -> Vec<SearchHit> {
    let start = html.find("csearch").unwrap_or(usize::MAX);
    if start == usize::MAX {
        return vec![];
    }
    let end = html[start..]
        .find("class=\"sidebar")
        .map(|i| start + i)
        .unwrap_or(html.len());
    if end <= start {
        return vec![];
    }
    let region = &html[start..end];
    let rx = Regex::new(
        r#"(?is)<div class="result-item"><article>.*?<div class="title">\s*<a href="([^"]+)">([^<]+)</a>"#,
    )
    .unwrap();
    rx.captures_iter(region)
        .map(|c| SearchHit {
            url: c.get(1).unwrap().as_str().to_string(),
            title: decode_html_entities(c.get(2).unwrap().as_str().trim()),
        })
        .collect()
}

fn score_hit(hit: &SearchHit, queries: &[HashSet<String>]) -> f64 {
    let r = tokenize(&hit.title, STOPWORDS);
    let mut best = 0.0;
    for q in queries {
        let j = jaccard(&r, q);
        if j > best {
            best = j;
        }
    }
    best
}

fn find_series(titles: &[String]) -> Result<Option<String>, String> {
    let mut all_variants = HashSet::new();
    for t in titles {
        for v in title_variants(t) {
            all_variants.insert(v);
        }
    }
    if all_variants.is_empty() {
        return Ok(None);
    }
    let mut ordered: Vec<String> = all_variants.into_iter().collect();
    ordered.sort_by_key(|s| s.len());
    let q_sets: Vec<HashSet<String>> = ordered
        .iter()
        .map(|s| tokenize(s, STOPWORDS))
        .filter(|s| !s.is_empty())
        .collect();
    if q_sets.is_empty() {
        return Ok(None);
    }

    let mut tried = HashSet::new();
    let mut all_hits = Vec::new();
    for q in ordered.iter().take(4) {
        let key = q.to_lowercase();
        if !tried.insert(key) {
            continue;
        }
        let url = format!("{}/?s={}", origin(), urlencoding::encode(q));
        if let Some(html) = get(&url, None)? {
            for h in parse_hits(&html) {
                if !all_hits.iter().any(|x: &SearchHit| x.url == h.url) {
                    all_hits.push(h);
                }
            }
            if !all_hits.is_empty() && score_hit(&all_hits[0], &q_sets) >= 0.99 {
                break;
            }
        }
    }
    if all_hits.is_empty() {
        return Ok(None);
    }

    let mut best: Option<&SearchHit> = None;
    let mut best_score = -1.0;
    let mut best_len = usize::MAX;
    for h in &all_hits {
        let s = score_hit(h, &q_sets);
        let len = tokenize(&h.title, STOPWORDS).len();
        if s > best_score || (s == best_score && len < best_len) {
            best_score = s;
            best = Some(h);
            best_len = len;
        }
    }
    if best_score < 0.50 {
        return Ok(None);
    }
    Ok(best.map(|h| h.url.clone()))
}

fn pick_episode(series_html: &str, ep: i32) -> Option<String> {
    let rx = Regex::new(r"(?i)/videos/([a-z0-9\-]+-episode-(\d+)[a-z0-9\-]*)/?").unwrap();
    let ep_str = ep.to_string();
    let mut matching: Vec<String> = rx
        .captures_iter(series_html)
        .filter_map(|c| {
            if c.get(2).map(|m| m.as_str()) == Some(ep_str.as_str()) {
                Some(format!("/videos/{}/", c.get(1).unwrap().as_str()))
            } else {
                None
            }
        })
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();
    if matching.is_empty() {
        return None;
    }
    matching.sort_by_key(|u| {
        let mut s = 0i32;
        if u.contains("dubbed") {
            s -= 100;
        }
        if u.contains("uncensored") {
            s -= 10;
        }
        s
    });
    Some(format!("{}{}", origin(), matching[0]))
}

fn extract_stream_url(video_html: &str) -> Option<String> {
    let rx = Regex::new(
        r#"(?i)(?:data-litespeed-src|src)\s*=\s*['"](https?://watchhentai\.net/jwplayer/\?source=[^'"]+)['"]"#,
    )
    .unwrap();
    rx.captures(video_html)
        .map(|c| decode_html_entities(c.get(1).unwrap().as_str()))
}

fn pick_best_source(jw_html: &str) -> Option<String> {
    let rx = Regex::new(r#"(?i)file\s*:\s*["'](https?://[^"']+\.mp4)["']"#).unwrap();
    let all: Vec<String> = rx
        .captures_iter(jw_html)
        .map(|c| c.get(1).unwrap().as_str().to_string())
        .collect();
    if all.is_empty() {
        return None;
    }
    let qual_re = Regex::new(r"_(\d+)p\.mp4$").unwrap();
    let qualified: Vec<String> = all
        .iter()
        .filter(|u| qual_re.is_match(u))
        .cloned()
        .collect();
    if !qualified.is_empty() {
        let mut sorted = qualified;
        sorted.sort_by_key(|u| {
            qual_re
                .captures(u)
                .and_then(|c| c.get(1).unwrap().as_str().parse::<i32>().ok())
                .unwrap_or(0)
        });
        sorted.reverse();
        return Some(sorted[0].clone());
    }
    Some(all[0].clone())
}

pub fn watchhentai_streams(title_candidates: &[String], episode: i32) -> Result<Value, String> {
    let series_url = match find_series(title_candidates)? {
        Some(u) => u,
        None => return Ok(json!({ "result": null })),
    };
    let series_html = match get(&series_url, None)? {
        Some(h) => h,
        None => return Ok(json!({ "result": null })),
    };
    let video_url = match pick_episode(&series_html, episode) {
        Some(u) => u,
        None => return Ok(json!({ "result": null })),
    };
    let video_html = match get(&video_url, Some(&origin()))? {
        Some(h) => h,
        None => return Ok(json!({ "result": null })),
    };
    let jw_url = match extract_stream_url(&video_html) {
        Some(u) => u,
        None => return Ok(json!({ "result": null })),
    };
    let jw_html = match get(&jw_url, Some(&video_url))? {
        Some(h) => h,
        None => return Ok(json!({ "result": null })),
    };
    let stream = match pick_best_source(&jw_html) {
        Some(u) => u,
        None => return Ok(json!({ "result": null })),
    };

    Ok(json!({
        "result": StreamResultOut {
            url: stream,
            referer: format!("{}/", origin()),
            origin: origin(),
            tracks: vec![],
            provider: String::new(),
            stream_label: None,
        }
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_hits_extracts_title_and_url() {
        let html = r#"
        csearch
        <div class="result-item"><article><div class="title">
        <a href="/series/foo/">Test Title</a>
        </div></article></div>
        class="sidebar
        "#;
        let hits = parse_hits(html);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].title, "Test Title");
    }

    #[test]
    fn pick_best_source_prefers_1080p() {
        let html = r#"file: "https://hstorage.xyz/a_720p.mp4", file: "https://hstorage.xyz/a_1080p.mp4""#;
        assert_eq!(
            pick_best_source(html).as_deref(),
            Some("https://hstorage.xyz/a_1080p.mp4")
        );
    }

    #[test]
    fn pick_episode_finds_matching_ep() {
        let html = r#"<a href="/videos/foo-episode-3-bar/">ep3</a><a href="/videos/foo-episode-1-bar/">ep1</a>"#;
        assert!(pick_episode(html, 1).unwrap().contains("episode-1"));
    }
}
