use std::collections::{HashMap, HashSet};
use std::sync::LazyLock;

use regex::Regex;
use serde_json::{json, Value};
use urlencoding::encode;

use crate::http;

const BASE: &str = "https://my-subs.co";

static HDRS: LazyLock<HashMap<String, String>> = LazyLock::new(|| {
    let mut m = HashMap::new();
    m.insert(
        "User-Agent".into(),
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
         (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
            .into(),
    );
    m.insert("Accept".into(), "text/html,*/*".into());
    m.insert("Referer".into(), format!("{BASE}/"));
    m
});

static SHOW_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)href=['"]/showlistsubtitles-(\d+)-([a-z0-9-]+)['"]"#).unwrap()
});

static FILM_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?i)href=['"](/film-versions-\d+-[a-z0-9-]+-subtitles)['"][^>]*>([^<]+)<"#,
    )
    .unwrap()
});

static FILM_SLUG_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)/film-versions-\d+-([a-z0-9-]+)-subtitles").unwrap());

static VERSION_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)<b>\s*Version\s*:\s*</b>\s*<i>\s*([^<]*?)\s*</i>").unwrap()
});

static ROW_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        concat!(
            r"(?i)<b>\s*Language\s*:\s*</b>\s*",
            r#"<span class="flag-icon flag-icon-([a-z]{2,3})"\s+title="([^"]+)"[^>]*></span>\s*"#,
            r"<i>\s*([^<]+?)\s*</i>",
            r"[\s\S]{0,2000}?href='(/downloads/[^']+)'",
        ),
    )
    .unwrap()
});

static REAL_URL_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"REAL_URL\s*=\s*"((?:\\/|/)[^"]+)""#).unwrap());

pub fn fetch_all(
    title: &str,
    year: Option<i32>,
    season: Option<i32>,
    episode: Option<i32>,
) -> Result<Vec<Value>, String> {
    let title = title.trim();
    if title.is_empty() {
        return Ok(vec![]);
    }
    let is_series = season.is_some() && episode.is_some();
    let versions_path = resolve_versions_path(title, year, is_series, season, episode)?;
    let Some(path) = versions_path else {
        return Ok(vec![]);
    };
    let entries = scrape_versions_page(&path)?;
    if entries.is_empty() {
        return Ok(vec![]);
    }

    let mut resolved = Vec::new();
    const BATCH: usize = 6;
    for chunk in entries.chunks(BATCH) {
        for entry in chunk {
            if let Some(r) = resolve_gate(entry) {
                resolved.push(r);
            }
        }
    }

    let mut totals = HashMap::new();
    for e in &resolved {
        let name = e
            .get("language")
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown")
            .to_string();
        *totals.entry(name).or_insert(0) += 1;
    }
    let mut seen = HashMap::new();
    for e in &mut resolved {
        let name = e
            .get("language")
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown")
            .to_string();
        let n = seen.entry(name.clone()).or_insert(0);
        *n += 1;
        let release = e
            .get("release")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .trim();
        let base = if totals.get(&name).copied().unwrap_or(0) > 1 {
            format!("{name} {n}")
        } else {
            name
        };
        let display = if release.is_empty() {
            format!("{base} - mysubs")
        } else {
            format!("{base} [{release}] - mysubs")
        };
        if let Value::Object(map) = e {
            map.insert("display".into(), json!(display));
        }
    }

    Ok(resolved)
}

fn resolve_versions_path(
    title: &str,
    year: Option<i32>,
    is_series: bool,
    season: Option<i32>,
    episode: Option<i32>,
) -> Result<Option<String>, String> {
    let search_url = format!("{BASE}/search.php?key={}", encode(title));
    let resp = http::fetch_with_retries("GET", &search_url, &HDRS, None, None, false, 15, 0)?;
    if resp.status != 200 {
        return Ok(None);
    }
    let html = &resp.body;
    let want_slug = slug(title);

    if is_series {
        let (ep, se) = (episode.unwrap_or(0), season.unwrap_or(0));
        let mut best_show_id = None;
        let mut best_slug = None;
        let mut best_score = i32::MIN;
        for cap in SHOW_RE.captures_iter(html) {
            let show_id = cap.get(1).map(|m| m.as_str()).unwrap_or("");
            let s = cap.get(2).map(|m| m.as_str()).unwrap_or("");
            let score = slug_score(s, &want_slug);
            if score > best_score {
                best_score = score;
                best_show_id = Some(show_id.to_string());
                best_slug = Some(s.to_string());
            }
        }
        match (best_show_id, best_slug) {
            (Some(id), Some(slug)) => Ok(Some(format!(
                "/versions-{id}-{ep}-{se}-{slug}-subtitles"
            ))),
            _ => Ok(None),
        }
    } else {
        let mut best_path = None;
        let mut best_score = i32::MIN;
        for cap in FILM_RE.captures_iter(html) {
            let path = cap.get(1).map(|m| m.as_str()).unwrap_or("");
            let label = cap.get(2).map(|m| m.as_str()).unwrap_or("");
            let slug_part = FILM_SLUG_RE
                .captures(path)
                .and_then(|c| c.get(1))
                .map(|m| m.as_str())
                .unwrap_or("");
            let mut score = slug_score(slug_part, &want_slug);
            if let Some(y) = year {
                if label.contains(&format!("({y})")) {
                    score += 100;
                }
            }
            if score > best_score {
                best_score = score;
                best_path = Some(path.to_string());
            }
        }
        Ok(best_path)
    }
}

fn scrape_versions_page(path: &str) -> Result<Vec<Value>, String> {
    let url = format!("{BASE}{path}");
    let resp = http::fetch_with_retries("GET", &url, &HDRS, None, None, false, 15, 0)?;
    if resp.status != 200 {
        return Ok(vec![]);
    }
    let html = &resp.body;
    let versions: Vec<_> = VERSION_RE
        .captures_iter(html)
        .map(|c| (c.get(0).unwrap().start(), c.get(1).map(|m| m.as_str()).unwrap_or("").to_string()))
        .collect();

    let release_for = |row_index: usize| -> String {
        let mut name = String::new();
        for (start, n) in &versions {
            if *start < row_index {
                name = n.clone();
            } else {
                break;
            }
        }
        name
    };

    let mut out = Vec::new();
    for cap in ROW_RE.captures_iter(html) {
        let cc = cap.get(1).map(|m| m.as_str()).unwrap_or("").to_lowercase();
        let flag_title = cap.get(2).map(|m| m.as_str()).unwrap_or("").trim();
        let lang_name = cap.get(3).map(|m| m.as_str()).unwrap_or("").trim();
        let gate = cap.get(4).map(|m| m.as_str()).unwrap_or("");
        let language = if lang_name.is_empty() {
            flag_title
        } else {
            lang_name
        };
        out.push(json!({
            "gate": gate,
            "language": title_case(language),
            "languageCode": flag_to_code(&cc, language),
            "release": release_for(cap.get(0).map(|m| m.start()).unwrap_or(0)),
        }));
    }
    Ok(out)
}

fn resolve_gate(entry: &Value) -> Option<Value> {
    let gate = entry.get("gate")?.as_str()?;
    let url = format!("{BASE}{gate}");
    let resp = http::fetch_with_retries("GET", &url, &HDRS, None, None, false, 12, 0).ok()?;
    if resp.status != 200 {
        return None;
    }
    let cap = REAL_URL_RE.captures(&resp.body)?;
    let real_path = cap.get(1)?.as_str().replace(r"\/", "/");
    let dl = if real_path.starts_with("http") {
        real_path
    } else {
        format!("{BASE}{real_path}")
    };
    Some(json!({
        "url": dl,
        "language": entry.get("languageCode").cloned().unwrap_or(json!("")),
        "display": entry.get("language").cloned().unwrap_or(json!("")),
        "release": entry.get("release").cloned().unwrap_or(json!("")),
        "sourceName": "mysubs",
    }))
}

fn slug(s: &str) -> String {
    let lower = s.to_lowercase();
    let cleaned = lower
        .replace(['`', '\'', '\u{2019}', '"'], "")
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect::<String>();
    cleaned
        .trim_matches('-')
        .split('-')
        .filter(|p| !p.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

fn slug_score(candidate: &str, want: &str) -> i32 {
    if candidate == want {
        return 1000;
    }
    let c_tokens: HashSet<_> = candidate.split('-').collect();
    let w_tokens: HashSet<_> = want.split('-').collect();
    let overlap = c_tokens.intersection(&w_tokens).count() as i32;
    let extra = c_tokens.len() as i32 - overlap;
    overlap * 10 - extra
}

fn title_case(s: &str) -> String {
    let mut chars = s.chars();
    match chars.next() {
        None => String::new(),
        Some(first) => {
            let upper: String = first.to_uppercase().collect();
            let rest: String = chars.collect::<String>().to_lowercase();
            format!("{upper}{rest}")
        }
    }
}

fn flag_to_code(flag: &str, lang_name: &str) -> String {
    const MAP: &[(&str, &str)] = &[
        ("gb", "en"),
        ("us", "en"),
        ("sa", "ar"),
        ("fr", "fr"),
        ("es", "es"),
        ("de", "de"),
        ("it", "it"),
        ("pt", "pt"),
        ("br", "pt-BR"),
        ("ru", "ru"),
        ("jp", "ja"),
        ("kr", "ko"),
        ("cn", "zh"),
        ("tw", "zh"),
        ("hk", "zh"),
        ("nl", "nl"),
        ("pl", "pl"),
        ("tr", "tr"),
        ("gr", "el"),
        ("cz", "cs"),
        ("dk", "da"),
        ("fi", "fi"),
        ("no", "no"),
        ("se", "sv"),
        ("hu", "hu"),
        ("ro", "ro"),
        ("bg", "bg"),
        ("rs", "sr"),
        ("hr", "hr"),
        ("sk", "sk"),
        ("si", "sl"),
        ("ua", "uk"),
        ("il", "he"),
        ("ir", "fa"),
        ("th", "th"),
        ("vn", "vi"),
        ("id", "id"),
        ("my", "ms"),
        ("in", "hi"),
        ("pk", "ur"),
    ];
    for (k, v) in MAP {
        if *k == flag {
            return (*v).to_string();
        }
    }
    let n = lang_name.to_lowercase();
    if n.len() >= 2 {
        n.chars().take(2).collect()
    } else {
        flag.to_string()
    }
}
