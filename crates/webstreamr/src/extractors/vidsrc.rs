use crate::fetcher::{fetch_text, FetchConfig};
use crate::types::StreamFile;
use regex::Regex;
use serde::Deserialize;
use std::collections::HashMap;
use std::sync::LazyLock;

static IFRAME_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)<iframe[^>]+id=["']player_iframe["'][^>]+src=["']([^"']+)["']"#).unwrap()
});
static PRORCP_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"src\s*:\s*['"](/prorcp/[^'"]+)['"]"#).unwrap());
static FILE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"file\s*:\s*"([^"]+\.m3u8[^"]*)""#).unwrap());
static VHOST_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\{v\d+\}").unwrap());

const EMBED_HOST: &str = "https://vsembed.ru";
const DEFAULT_HOST: &str = "cloudnestra.com";
const USER_AGENT: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
(KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36";

#[derive(Debug, Deserialize)]
struct ResolveRequest {
    tmdb_id: i64,
    #[serde(default)]
    is_movie: bool,
    season: Option<i32>,
    episode: Option<i32>,
}

pub fn build_embed_url(
    tmdb_id: i64,
    is_movie: bool,
    season: Option<i32>,
    episode: Option<i32>,
) -> String {
    if is_movie {
        format!("{EMBED_HOST}/embed/movie/{tmdb_id}")
    } else {
        format!(
            "{EMBED_HOST}/embed/tv/{tmdb_id}/{}-{}",
            season.unwrap_or(1),
            episode.unwrap_or(1)
        )
    }
}

fn fetch_cfg(referer: Option<&str>) -> FetchConfig {
    let mut headers = HashMap::new();
    headers.insert("User-Agent".into(), USER_AGENT.into());
    headers.insert(
        "Accept".into(),
        "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".into(),
    );
    headers.insert("Accept-Language".into(), "en-US,en;q=0.9".into());
    if let Some(r) = referer {
        headers.insert("Referer".into(), r.into());
    }
    FetchConfig {
        headers,
        ..Default::default()
    }
}

fn absolutize_src(raw: &str) -> String {
    let raw = raw.trim();
    if raw.starts_with("http") {
        raw.to_string()
    } else if raw.starts_with("//") {
        format!("https:{raw}")
    } else if raw.starts_with('/') {
        format!("{EMBED_HOST}{raw}")
    } else {
        raw.to_string()
    }
}

pub fn find_iframe_src(html: &str) -> Option<String> {
    let m = IFRAME_RE.captures(html)?;
    Some(absolutize_src(m.get(1)?.as_str()))
}

pub fn find_prorcp_url(rcp_html: &str) -> Option<String> {
    let path = PRORCP_RE.captures(rcp_html)?.get(1)?.as_str();
    Some(format!("https://{DEFAULT_HOST}{path}"))
}

pub fn extract_m3u8_from_prorcp(html: &str) -> Option<String> {
    let raw = FILE_RE.captures(html)?.get(1)?.as_str();
    let variants: Vec<&str> = if raw.contains(" or ") {
        raw.split(" or ").collect()
    } else {
        vec![raw]
    };
    for v in variants {
        let part = v.split('|').next().unwrap_or(v).trim();
        let candidate = VHOST_RE.replace_all(part, DEFAULT_HOST).into_owned();
        if candidate.starts_with("http") && candidate.contains(".m3u8") {
            return Some(candidate);
        }
    }
    None
}

pub fn extract_from_html_chain(
    outer_html: &str,
    rcp_html: &str,
    prorcp_html: &str,
) -> Option<StreamFile> {
    let _iframe = IFRAME_RE.captures(outer_html)?;
    let _prorcp = PRORCP_RE.captures(rcp_html)?;
    let url = extract_m3u8_from_prorcp(prorcp_html)?;
    Some(StreamFile {
        url,
        quality: None,
        headers: None,
    })
}

pub fn extract_vidsrc_chain_json(outer_html: &str, rcp_html: &str, prorcp_html: &str) -> String {
    match extract_from_html_chain(outer_html, rcp_html, prorcp_html) {
        Some(file) => serde_json::json!({
            "url": file.url,
            "format": "hls",
        })
        .to_string(),
        None => serde_json::json!({ "error": "not_found" }).to_string(),
    }
}

pub fn resolve_vidsrc_embed_json(request_json: &str) -> String {
    let req: ResolveRequest = match serde_json::from_str(request_json) {
        Ok(r) => r,
        Err(e) => return serde_json::json!({ "error": e.to_string() }).to_string(),
    };

    let embed_url = build_embed_url(req.tmdb_id, req.is_movie, req.season, req.episode);
    let outer = match fetch_text(&embed_url, &fetch_cfg(None)) {
        Ok(h) if !h.is_empty() => h,
        Ok(_) => return serde_json::json!({ "error": "empty_embed" }).to_string(),
        Err(e) => return serde_json::json!({ "error": e }).to_string(),
    };

    let rcp_url = match find_iframe_src(&outer) {
        Some(u) => u,
        None => return serde_json::json!({ "error": "no_iframe" }).to_string(),
    };

    let rcp_html = match fetch_text(&rcp_url, &fetch_cfg(Some(&format!("{EMBED_HOST}/")))) {
        Ok(h) if !h.is_empty() => h,
        Ok(_) => return serde_json::json!({ "error": "empty_rcp" }).to_string(),
        Err(e) => return serde_json::json!({ "error": e }).to_string(),
    };

    let prorcp_url = match find_prorcp_url(&rcp_html) {
        Some(u) => u,
        None => return serde_json::json!({ "error": "no_prorcp" }).to_string(),
    };

    let prorcp_html = match fetch_text(&prorcp_url, &fetch_cfg(Some(&rcp_url))) {
        Ok(h) if !h.is_empty() => h,
        Ok(_) => return serde_json::json!({ "error": "empty_prorcp" }).to_string(),
        Err(e) => return serde_json::json!({ "error": e }).to_string(),
    };

    let Some(file) = extract_from_html_chain(&outer, &rcp_html, &prorcp_html) else {
        return serde_json::json!({ "error": "no_m3u8" }).to_string();
    };

    serde_json::json!({
        "url": file.url,
        "format": "hls",
        "provider": "vidsrc",
        "headers": {
            "User-Agent": USER_AGENT,
            "Referer": "https://cloudnestra.com/",
            "Origin": "https://cloudnestra.com",
        }
    })
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn movie_embed_url() {
        assert_eq!(
            build_embed_url(550, true, None, None),
            "https://vsembed.ru/embed/movie/550"
        );
    }

    #[test]
    fn tv_embed_url() {
        assert_eq!(
            build_embed_url(1399, false, Some(2), Some(5)),
            "https://vsembed.ru/embed/tv/1399/2-5"
        );
    }

    #[test]
    fn prorcp_m3u8_with_vhost() {
        let html = r#"<script>file: "https://{v1}/hls/movie.m3u8|720p"</script>"#;
        assert_eq!(
            extract_m3u8_from_prorcp(html),
            Some("https://cloudnestra.com/hls/movie.m3u8".into())
        );
    }

    #[test]
    fn prorcp_m3u8_or_variants() {
        let html = r#"file: "https://tmstr4.{v1}/a.m3u8 or https://app2.{v2}/b.m3u8""#;
        assert_eq!(
            extract_m3u8_from_prorcp(html),
            Some("https://tmstr4.cloudnestra.com/a.m3u8".into())
        );
    }

    #[test]
    fn chain_golden_fixture() {
        let outer = std::fs::read_to_string("tests/fixtures/vidsrc_outer.html").unwrap();
        let rcp = std::fs::read_to_string("tests/fixtures/vidsrc_rcp.html").unwrap();
        let prorcp = std::fs::read_to_string("tests/fixtures/vidsrc_prorcp.html").unwrap();
        let json = extract_vidsrc_chain_json(&outer, &rcp, &prorcp);
        assert!(json.contains("cloudnestra.com/hls/movie.m3u8"));
    }
}
