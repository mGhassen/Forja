use std::collections::HashSet;

use regex::Regex;
use serde_json::{json, Value};

use super::common::{anime_get, jaccard, tokenize, StreamResultOut};

const SITE: &str = "https://hentaini.com";
const API: &str = "https://admin.hentaini.com/api";

fn site() -> String {
    utils::provider_runtime::api_base("hentainiSite")
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| SITE.to_string())
}

fn api() -> String {
    utils::provider_runtime::api_base("hentainiApi")
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| API.to_string())
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

struct HSeries {
    id: i64,
    title: String,
    title_english: String,
    url: String,
}

impl Clone for HSeries {
    fn clone(&self) -> Self {
        Self {
            id: self.id,
            title: self.title.clone(),
            title_english: self.title_english.clone(),
            url: self.url.clone(),
        }
    }
}

fn get(url: &str) -> Result<Option<String>, String> {
    let headers = std::collections::HashMap::from([
        ("User-Agent".into(), UA.into()),
        ("Accept".into(), "application/json".into()),
        ("Accept-Language".into(), "en-US,en;q=0.9".into()),
        ("Referer".into(), format!("{}/", site())),
    ]);
    let resp = anime_get(url, &headers, 25)?;
    if resp.status != 200 {
        return Ok(None);
    }
    Ok(Some(resp.body))
}

fn title_variants(t: &str) -> Vec<String> {
    let mut out = HashSet::new();
    out.insert(t.trim().to_string());

    let patterns: &[&str] = &[":", "\u{2013}", "\u{2014}"];
    for pat in patterns {
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

fn parse_series_list(body: &str) -> Vec<HSeries> {
    let Ok(json) = serde_json::from_str::<Value>(body) else {
        return vec![];
    };
    let Some(data) = json.get("data").and_then(|v| v.as_array()) else {
        return vec![];
    };
    let mut out = Vec::new();
    for e in data {
        let id = e.get("id").and_then(|v| v.as_i64());
        let title = e.get("title").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let title_en = e.get("title_english").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let url = e.get("url").and_then(|v| v.as_str()).unwrap_or("").to_string();
        if let Some(id) = id {
            if !url.is_empty() {
                out.push(HSeries {
                    id,
                    title,
                    title_english: title_en,
                    url,
                });
            }
        }
    }
    out
}

fn score_series(s: &HSeries, queries: &[HashSet<String>]) -> f64 {
    let mut candidates = Vec::new();
    if !s.title.is_empty() {
        candidates.push(tokenize(&s.title, STOPWORDS));
    }
    if !s.title_english.is_empty() {
        candidates.push(tokenize(&s.title_english, STOPWORDS));
    }
    candidates.push(tokenize(&s.url.replace('-', " "), STOPWORDS));
    let mut best = 0.0;
    for r in candidates {
        for q in queries {
            let j = jaccard(&r, q);
            if j > best {
                best = j;
            }
        }
    }
    best
}

fn find_series(titles: &[String]) -> Result<Option<HSeries>, String> {
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
        let enc = urlencoding::encode(q);
        let url1 = format!(
            "{}/series?filters%5Btitle%5D%5B%24containsi%5D={enc}&pagination%5Blimit%5D=20",
            api()
        );
        if let Some(body) = get(&url1)? {
            for h in parse_series_list(&body) {
                if !all_hits.iter().any(|x: &HSeries| x.id == h.id) {
                    all_hits.push(h);
                }
            }
        }
        let url2 = format!(
            "{}/series?filters%5Btitle_english%5D%5B%24containsi%5D={enc}&pagination%5Blimit%5D=20",
            api()
        );
        if let Some(body) = get(&url2)? {
            for h in parse_series_list(&body) {
                if !all_hits.iter().any(|x| x.id == h.id) {
                    all_hits.push(h);
                }
            }
        }
        if !all_hits.is_empty() {
            if score_series(&all_hits[0], &q_sets) >= 0.99 {
                break;
            }
        }
    }
    if all_hits.is_empty() {
        return Ok(None);
    }

    let mut best: Option<&HSeries> = None;
    let mut best_score = -1.0;
    for h in &all_hits {
        let s = score_series(h, &q_sets);
        if s > best_score {
            best_score = s;
            best = Some(h);
        }
    }
    if best_score < 0.45 {
        return Ok(None);
    }
    Ok(best.cloned())
}

fn pick_player(players_json: &str) -> Option<String> {
    let Ok(list) = serde_json::from_str::<Value>(players_json) else {
        return None;
    };
    let arr = list.as_array()?;
    let mut hls = None;
    let mut mp4 = None;
    let mp4_re = Regex::new(r"\.mp4($|\?)").unwrap();
    for p in arr {
        let name = p.get("name").and_then(|v| v.as_str()).unwrap_or("").to_uppercase();
        let url = p.get("url").and_then(|v| v.as_str()).unwrap_or("");
        if url.is_empty() {
            continue;
        }
        if name == "HLS" && url.ends_with(".m3u8") {
            hls.get_or_insert(url.to_string());
        } else if mp4_re.is_match(url) && !url.contains("/embed") {
            mp4.get_or_insert(url.to_string());
        }
    }
    hls.or(mp4)
}

pub fn hentaini_streams(title_candidates: &[String], episode: i32) -> Result<Value, String> {
    let series = match find_series(title_candidates)? {
        Some(s) => s,
        None => return Ok(json!({ "result": null })),
    };

    let url = format!(
        "{}/series?filters%5Bid%5D={}&populate=episodes",
        api(),
        series.id
    );
    let body = match get(&url)? {
        Some(b) => b,
        None => return Ok(json!({ "result": null })),
    };
    let json: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    let episodes = json
        .pointer("/data/0/episodes")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    let mut target: Option<&Value> = None;
    for e in &episodes {
        if e.get("episode_number").and_then(|v| v.as_i64()) == Some(episode as i64) {
            target = Some(e);
            break;
        }
    }
    let target = match target {
        Some(v) => v,
        None => return Ok(json!({ "result": null })),
    };
    let players = target.get("players").and_then(|v| v.as_str()).unwrap_or("");
    if players.is_empty() {
        return Ok(json!({ "result": null }));
    }
    let stream = match pick_player(players) {
        Some(s) => s,
        None => return Ok(json!({ "result": null })),
    };

    Ok(json!({
        "result": StreamResultOut {
            url: stream,
            referer: format!("{}/", site()),
            origin: site(),
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
    fn title_variants_splits_on_colon() {
        let v = title_variants("Foo!: Bar the Animation");
        assert!(v.contains(&"Foo!".to_string()));
    }

    #[test]
    fn pick_player_prefers_hls() {
        let players = r#"[{"name":"HLS","url":"https://cdn/x.m3u8"},{"name":"MP4","url":"https://cdn/x.mp4"}]"#;
        assert_eq!(
            pick_player(players).as_deref(),
            Some("https://cdn/x.m3u8")
        );
    }
}
