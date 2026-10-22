use std::collections::{HashMap, HashSet};
use std::sync::LazyLock;

use regex::Regex;
use serde_json::{json, Value};
use urlencoding::encode;

const ORIGIN: &str = "https://www.subtitlecat.com";

static HDRS: LazyLock<HashMap<String, String>> = LazyLock::new(|| {
    let mut m = HashMap::new();
    m.insert(
        "User-Agent".into(),
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
         (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
            .into(),
    );
    m.insert(
        "Accept".into(),
        "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".into(),
    );
    m.insert("Accept-Language".into(), "en-US,en;q=0.9".into());
    m
});

static SEARCH_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)<a\s+href="(subs/(\d+)/([^"]+\.html))"[^>]*>([^<]*)</a>"#).unwrap()
});

static DL_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?i)<a\s+id="download_([A-Za-z0-9-]+)"[^>]*href="(/subs/\d+/[^"]+\.srt)""#,
    )
    .unwrap()
});

static TR_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?i)translate_from_server_folder\(\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*\)"#,
    )
    .unwrap()
});

static DASH_LANG_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"-([A-Za-z0-9-]+)\.srt$").unwrap());

pub fn build_query(title: &str, year: Option<i32>, season: Option<i32>, episode: Option<i32>) -> String {
    let clean = title.split_whitespace().collect::<Vec<_>>().join(" ");
    if let (Some(s), Some(e)) = (season, episode) {
        return format!("{clean} S{s:02}E{e:02}");
    }
    if let Some(y) = year.filter(|y| *y > 0) {
        return format!("{clean} {y}");
    }
    clean
}

pub fn fetch_all(
    title: &str,
    year: Option<i32>,
    season: Option<i32>,
    episode: Option<i32>,
    translate_base_url: Option<&str>,
    max_results: usize,
) -> Result<Vec<Value>, String> {
    let query = build_query(title, year, season, episode);
    let hits = search(&query)?;
    if hits.is_empty() {
        return Ok(vec![]);
    }

    // The site searches by substring: "Rick and Morty S01E02" also returns
    // "Rick and Morty: The Anime S01E02". Keep only releases named after the
    // requested title (and episode tag when given).
    let picks: Vec<_> = hits
        .into_iter()
        .filter(|h| release_matches_request(&h.name, title, season, episode))
        .take(max_results)
        .collect();
    let mut out = Vec::new();
    let mut seen_direct = HashSet::new();
    let mut translated_langs = HashSet::new();

    for (i, hit) in picks.iter().enumerate() {
        let detail = match fetch_detail(&hit.detail_url) {
            Ok(d) => d,
            Err(_) => continue,
        };

        for ln in &detail.direct_languages {
            if !seen_direct.insert(ln.url.clone()) {
                continue;
            }
            out.push(json!({
                "url": ln.url,
                "display": format!("{} {} - subtitlecat", ln.label, i + 1),
                "language": ln.code,
                "sourceName": "subtitlecat",
            }));
        }

        if let Some(base) = translate_base_url.filter(|s| !s.is_empty()) {
            for ln in &detail.translatable_languages {
                if translated_langs.contains(&ln.code) {
                    continue;
                }
                if detail.direct_languages.iter().any(|d| d.code == ln.code) {
                    continue;
                }
                translated_langs.insert(ln.code.clone());
                let orig_url = format!("{ORIGIN}{}{}", detail.folder, detail.orig_filename);
                let t_url = format!(
                    "{base}/subtitlecat-translate?orig={}&tl={}&name={}",
                    encode(&orig_url),
                    encode(&ln.code),
                    encode(&detail.base_name),
                );
                out.push(json!({
                    "url": t_url,
                    "display": format!("{} (translated) - subtitlecat", ln.label),
                    "language": ln.code,
                    "sourceName": "subtitlecat",
                    "translated": true,
                }));
            }
        }
    }

    Ok(out)
}

struct SearchHit {
    detail_url: String,
    /// Release name from the result page (anchor text, else the html slug).
    name: String,
}

/// Normalize a title or release name to lowercase words: `'` is dropped
/// (Grey's → greys, as scene names spell it), `&` becomes "and", `.`/`_`/`-`
/// and punctuation become spaces, so "Rick.and.Morty.S01E02.480p" compares
/// with "Rick and Morty".
fn title_words(s: &str) -> Vec<String> {
    s.to_lowercase()
        .replace(['\'', '\u{2019}'], "")
        .replace('&', " and ")
        .replace(['.', '_', '-', ':', '(', ')', '[', ']', ',', '!', '?', ';'], " ")
        .split_whitespace()
        .map(|w| w.to_string())
        .collect()
}

/// Title words to match against a release: a trailing `(2005)` / `(US)`
/// qualifier or a bare trailing year in the catalog title is not part of the
/// release name ("Doctor Who (2005)" → doctor who; "The Office (US)" → the
/// office).
fn request_title_words(title: &str) -> Vec<String> {
    let trimmed = title.trim();
    let base = match trimmed.rfind('(') {
        Some(i) if trimmed.ends_with(')') => trimmed[..i].trim(),
        _ => trimmed,
    };
    let mut words = title_words(base);
    if words.len() > 1 {
        let last = &words[words.len() - 1];
        if last.len() == 4 && last.chars().all(|c| c.is_ascii_digit()) {
            words.pop();
        }
    }
    words
}

/// `(season, episode)` of a scene tag such as `s01e02` or `s1e2`.
fn episode_tag(word: &str) -> Option<(i32, i32)> {
    let rest = word.strip_prefix('s')?;
    let i = rest.find('e')?;
    let (s, e) = (&rest[..i], &rest[i + 1..]);
    if s.is_empty() || e.is_empty() {
        return None;
    }
    Some((s.parse().ok()?, e.parse().ok()?))
}

fn is_episode_tag(word: &str) -> bool {
    episode_tag(word).is_some()
}

/// True when the release is named after [title]: the words before the
/// episode tag (or the whole name without one) start with the title words,
/// followed by nothing, a year, a region tag (US/UK/…) or release noise that
/// starts with a digit (1080p, 720p). Extra title words are another show:
/// "Rick and Morty The Anime S01E02" does not match "Rick and Morty";
/// "Rick.and.Morty.S01E02.480p" and "Dune.2021.1080p" do.
pub fn release_matches_request(
    release: &str,
    title: &str,
    season: Option<i32>,
    episode: Option<i32>,
) -> bool {
    let want = request_title_words(title);
    if want.is_empty() {
        return true;
    }
    let words = title_words(release);
    if words.is_empty() {
        return false;
    }
    let tag_at = words.iter().position(|w| is_episode_tag(w));
    if let (Some(s), Some(e)) = (season, episode) {
        match tag_at.and_then(|i| episode_tag(&words[i])) {
            Some((ts, te)) if ts == s && te == e => {}
            Some(_) => return false,
            // No tag at all: keep (the site may slug a whole-season pack).
            None => {}
        }
    }
    let head: Vec<&str> = match tag_at {
        Some(i) => words[..i].iter().map(|w| w.as_str()).collect(),
        None => words.iter().map(|w| w.as_str()).collect(),
    };
    if head.len() < want.len() {
        return false;
    }
    if !head.iter().zip(want.iter()).all(|(a, b)| *a == b.as_str()) {
        return false;
    }
    let mut extra = head[want.len()..].iter();
    loop {
        match extra.next() {
            None => return true,
            Some(w) if w.starts_with(|c: char| c.is_ascii_digit()) => return true,
            Some(w) if is_region_tag(w) => continue,
            Some(_) => return false,
        }
    }
}

fn is_region_tag(word: &str) -> bool {
    matches!(word, "us" | "uk" | "au" | "ca" | "nz")
}

struct LangEntry {
    code: String,
    label: String,
    url: String,
}

struct DetailPage {
    direct_languages: Vec<LangEntry>,
    translatable_languages: Vec<LangEntry>,
    folder: String,
    orig_filename: String,
    base_name: String,
}

fn search(query: &str) -> Result<Vec<SearchHit>, String> {
    let url = format!("{ORIGIN}/index.php?search={}", encode(query));
    let (status, body) = crate::fetch::get(&url, &HDRS, 15)?;
    if status != 200 {
        return Err(format!("search {}", status));
    }
    let mut out = Vec::new();
    let mut seen = HashSet::new();
    for cap in SEARCH_RE.captures_iter(&body) {
        let rel = cap.get(1).map(|m| m.as_str()).unwrap_or("");
        if !seen.insert(rel.to_string()) {
            continue;
        }
        let anchor = cap.get(4).map(|m| m.as_str().trim()).unwrap_or("");
        let slug = cap
            .get(3)
            .map(|m| m.as_str().trim_end_matches(".html"))
            .unwrap_or("");
        out.push(SearchHit {
            detail_url: format!("{ORIGIN}/{rel}"),
            name: if anchor.is_empty() { slug.to_string() } else { anchor.to_string() },
        });
    }
    Ok(out)
}

fn fetch_detail(detail_url: &str) -> Result<DetailPage, String> {
    let (status, body) = crate::fetch::get(detail_url, &HDRS, 15)?;
    if status != 200 {
        return Err(format!("detail {}", status));
    }
    Ok(parse_detail_page(&body))
}

fn parse_detail_page(html: &str) -> DetailPage {
    let mut directs = Vec::new();
    let mut direct_codes = HashSet::new();
    for cap in DL_RE.captures_iter(html) {
        let code = cap.get(1).map(|m| m.as_str()).unwrap_or("");
        let href = cap.get(2).map(|m| m.as_str()).unwrap_or("");
        let norm = normalize_lang(code);
        directs.push(LangEntry {
            code: norm.clone(),
            label: language_label(code),
            url: format!("{ORIGIN}{href}"),
        });
        direct_codes.insert(norm);
    }

    let mut translatables = Vec::new();
    let mut folder = String::new();
    let mut orig_filename = String::new();
    for cap in TR_RE.captures_iter(html) {
        let code = cap.get(1).map(|m| m.as_str()).unwrap_or("");
        orig_filename = cap.get(2).map(|m| m.as_str()).unwrap_or("").to_string();
        folder = cap.get(3).map(|m| m.as_str()).unwrap_or("").to_string();
        let norm = normalize_lang(code);
        if direct_codes.contains(&norm) {
            continue;
        }
        translatables.push(LangEntry {
            code: norm,
            label: language_label(code),
            url: String::new(),
        });
    }

    if folder.is_empty() && !directs.is_empty() {
        let path = directs[0].url.strip_prefix(ORIGIN).unwrap_or(&directs[0].url);
        if let Some(last_slash) = path.rfind('/') {
            folder = format!("{}/", &path[..last_slash]);
            let fname = &path[last_slash + 1..];
            let base = DASH_LANG_RE.replace(fname, "").to_string();
            orig_filename = format!("{base}-orig.srt");
        }
    }

    let base_name = orig_filename.replace("-orig.srt", "");
    DetailPage {
        direct_languages: directs,
        translatable_languages: translatables,
        folder,
        orig_filename,
        base_name,
    }
}

fn normalize_lang(code: &str) -> String {
    let c = code.to_lowercase();
    match c.as_str() {
        "iw" => "he".into(),
        "jw" => "jv".into(),
        "in" => "id".into(),
        _ => c,
    }
}

fn language_label(code: &str) -> String {
    const MAP: &[(&str, &str)] = &[
        ("af", "Afrikaans"),
        ("ar", "Arabic"),
        ("bg", "Bulgarian"),
        ("zh-cn", "Chinese (S)"),
        ("zh-tw", "Chinese (T)"),
        ("cs", "Czech"),
        ("da", "Danish"),
        ("nl", "Dutch"),
        ("en", "English"),
        ("fi", "Finnish"),
        ("fr", "French"),
        ("de", "German"),
        ("el", "Greek"),
        ("he", "Hebrew"),
        ("iw", "Hebrew"),
        ("hi", "Hindi"),
        ("hu", "Hungarian"),
        ("id", "Indonesian"),
        ("in", "Indonesian"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("jv", "Javanese"),
        ("jw", "Javanese"),
        ("ko", "Korean"),
        ("no", "Norwegian"),
        ("fa", "Persian"),
        ("pl", "Polish"),
        ("pt", "Portuguese"),
        ("pt-br", "Portuguese (BR)"),
        ("ro", "Romanian"),
        ("ru", "Russian"),
        ("sr", "Serbian"),
        ("sk", "Slovak"),
        ("es", "Spanish"),
        ("sv", "Swedish"),
        ("th", "Thai"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese"),
    ];
    let c = code.to_lowercase();
    for (k, v) in MAP {
        if *k == c {
            return (*v).to_string();
        }
    }
    code.to_string()
}

#[cfg(test)]
mod tests {
    use super::release_matches_request;

    #[test]
    fn same_title_release_matches() {
        assert!(release_matches_request(
            "Rick.and.Morty.S01E02.480p.x264-RUBiK",
            "Rick and Morty",
            Some(1),
            Some(2),
        ));
        assert!(release_matches_request(
            "Rick and Morty - S01E02 - Lawnmower Dog",
            "Rick and Morty",
            Some(1),
            Some(2),
        ));
    }

    #[test]
    fn other_show_sharing_the_prefix_is_rejected() {
        assert!(!release_matches_request(
            "Rick.and.Morty.The.Anime.S01E02.480p.x264-RUBiK",
            "Rick and Morty",
            Some(1),
            Some(2),
        ));
        assert!(!release_matches_request(
            "Rick and Morty The Anime S01E02",
            "Rick and Morty",
            Some(1),
            Some(2),
        ));
    }

    #[test]
    fn wrong_episode_tag_is_rejected() {
        assert!(!release_matches_request(
            "Rick.and.Morty.S01E03.720p",
            "Rick and Morty",
            Some(1),
            Some(2),
        ));
    }

    #[test]
    fn year_suffix_and_movies_match() {
        assert!(release_matches_request("Dune.2021.1080p", "Dune", None, None));
        assert!(release_matches_request("Dune (2021)", "Dune", None, None));
        assert!(!release_matches_request("Dune Part Two 2024", "Dune", None, None));
        assert!(release_matches_request(
            "The.Office.US.S01E02.720p",
            "The Office",
            Some(1),
            Some(2),
        ));
        assert!(release_matches_request(
            "The.Office.S01E02.720p",
            "The Office (US)",
            Some(1),
            Some(2),
        ));
        assert!(release_matches_request(
            "Doctor.Who.S01E01",
            "Doctor Who (2005)",
            Some(1),
            Some(1),
        ));
    }

    #[test]
    fn apostrophes_ampersands_and_short_tags() {
        assert!(release_matches_request(
            "Greys.Anatomy.S01E01.720p",
            "Grey's Anatomy",
            Some(1),
            Some(1),
        ));
        assert!(release_matches_request(
            "Law.and.Order.S01E02",
            "Law & Order",
            Some(1),
            Some(2),
        ));
        assert!(release_matches_request(
            "Rick and Morty S1E2",
            "Rick and Morty",
            Some(1),
            Some(2),
        ));
        assert!(!release_matches_request(
            "Rick and Morty S1E3",
            "Rick and Morty",
            Some(1),
            Some(2),
        ));
    }
}
