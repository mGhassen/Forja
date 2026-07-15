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
static MASTER_URLS_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"master_urls\s*=\s*"([^"]+\.m3u8[^"]*)""#).unwrap()
});
static VHOST_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\{v\d+\}").unwrap());

/// Canonical embed host (site announcement: vsembed.ru → vsembed.su).
const EMBED_HOST: &str = "https://vsembed.su";
/// Fallback when CDN host cannot be parsed from the rcp iframe URL (legacy fixtures).
const LEGACY_CDN_HOST: &str = "cloudnestra.com";
const USER_AGENT: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
(KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36";

/// CDN host from an absolute or protocol-relative rcp / iframe URL (e.g. cloudorchestranova.com).
fn cdn_host_from_url(url: &str) -> Option<String> {
    let normalized = if url.starts_with("//") {
        format!("https:{url}")
    } else {
        url.to_string()
    };
    let after_scheme = normalized.split("://").nth(1)?;
    let host = after_scheme.split('/').next()?.split(':').next()?;
    if host.is_empty() {
        None
    } else {
        Some(host.to_string())
    }
}

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
        format!("{EMBED_HOST}/embed/movie?tmdb={tmdb_id}")
    } else {
        format!(
            "{EMBED_HOST}/embed/tv?tmdb={tmdb_id}&season={}&episode={}",
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

pub fn find_prorcp_url(rcp_html: &str, rcp_url: &str) -> Option<String> {
    let path = PRORCP_RE.captures(rcp_html)?.get(1)?.as_str();
    let host = cdn_host_from_url(rcp_url).unwrap_or_else(|| LEGACY_CDN_HOST.into());
    Some(format!("https://{host}{path}"))
}

fn expand_m3u8_candidate(part: &str, cdn_host: &str) -> Option<String> {
    let candidate = VHOST_RE.replace_all(part.trim(), cdn_host).into_owned();
    if candidate.starts_with("http") && candidate.contains(".m3u8") {
        Some(candidate)
    } else {
        None
    }
}

fn parse_m3u8_variants(raw: &str, cdn_host: &str) -> Vec<String> {
    let variants: Vec<&str> = if raw.contains(" or ") {
        raw.split(" or ").collect()
    } else {
        vec![raw]
    };
    variants
        .into_iter()
        .filter_map(|v| {
            let part = v.split('|').next().unwrap_or(v);
            expand_m3u8_candidate(part, cdn_host)
        })
        .collect()
}

fn fetch_stream_token(stream_host: &str, referer: &str) -> Option<String> {
    let token_url = format!("https://{stream_host}/generate.php");
    let body = fetch_text(&token_url, &fetch_cfg(Some(referer))).ok()?;
    let token = body.trim();
    if token.is_empty() {
        None
    } else {
        Some(token.to_string())
    }
}

fn apply_vidsrc_tokens(url: &str, referer: &str) -> Option<String> {
    let mut out = url.to_string();
    if out.contains("__TOKENPG__") {
        let host = cdn_host_from_url(&out)?;
        let token = fetch_stream_token(&host, referer)?;
        out = out.replace("__TOKENPG__", &token);
    }
    if out.contains("__TOKEN__") {
        let host = cdn_host_from_url(&out)?;
        let token = fetch_stream_token(&host, referer)?;
        out = out.replace("__TOKEN__", &token);
    }
    Some(out)
}

fn referer_with_slash(referer: Option<&str>, cdn_host: &str) -> String {
    referer
        .map(|r| {
            if r.ends_with('/') {
                r.to_string()
            } else {
                format!("{r}/")
            }
        })
        .unwrap_or_else(|| format!("https://{cdn_host}/"))
}

pub fn extract_m3u8_from_prorcp(
    html: &str,
    cdn_host: &str,
    referer: Option<&str>,
) -> Option<String> {
    let mut candidates = Vec::new();
    if let Some(raw) = FILE_RE.captures(html).and_then(|c| c.get(1)).map(|m| m.as_str()) {
        candidates.extend(parse_m3u8_variants(raw, cdn_host));
    }
    if let Some(raw) = MASTER_URLS_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str())
    {
        candidates.extend(parse_m3u8_variants(raw, cdn_host));
    }
    if candidates.is_empty() {
        return None;
    }
    candidates.sort_by_key(|u| (!u.contains("master.m3u8"), u.contains("list.m3u8")));
    let referer = referer_with_slash(referer, cdn_host);
    for candidate in candidates {
        let url = if candidate.contains("__TOKEN") {
            apply_vidsrc_tokens(&candidate, &referer)?
        } else {
            candidate
        };
        return Some(url);
    }
    None
}

pub fn extract_from_html_chain(
    outer_html: &str,
    rcp_html: &str,
    prorcp_html: &str,
    rcp_url: Option<&str>,
) -> Option<StreamFile> {
    let _iframe = IFRAME_RE.captures(outer_html)?;
    let _prorcp = PRORCP_RE.captures(rcp_html)?;
    let cdn_host = rcp_url
        .and_then(cdn_host_from_url)
        .or_else(|| find_iframe_src(outer_html).and_then(|u| cdn_host_from_url(&u)))
        .unwrap_or_else(|| LEGACY_CDN_HOST.into());
    let url = extract_m3u8_from_prorcp(prorcp_html, &cdn_host, rcp_url)?;
    Some(StreamFile {
        url,
        quality: None,
        headers: None,
    })
}

pub fn extract_vidsrc_chain_json(
    outer_html: &str,
    rcp_html: &str,
    prorcp_html: &str,
    rcp_url: Option<&str>,
) -> String {
    match extract_from_html_chain(outer_html, rcp_html, prorcp_html, rcp_url) {
        Some(file) => {
            // CloudStream leaf segments (`page-N.html`) return CF 403 when
            // Referer/Origin are set — browser players use no-referrer. UA only.
            serde_json::json!({
                "url": file.url,
                "format": "hls",
                "headers": {
                    "User-Agent": USER_AGENT,
                }
            })
            .to_string()
        }
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

    let prorcp_url = match find_prorcp_url(&rcp_html, &rcp_url) {
        Some(u) => u,
        None => return serde_json::json!({ "error": "no_prorcp" }).to_string(),
    };

    let prorcp_html = match fetch_text(&prorcp_url, &fetch_cfg(Some(&rcp_url))) {
        Ok(h) if !h.is_empty() => h,
        Ok(_) => return serde_json::json!({ "error": "empty_prorcp" }).to_string(),
        Err(e) => return serde_json::json!({ "error": e }).to_string(),
    };

    let Some(file) = extract_from_html_chain(&outer, &rcp_html, &prorcp_html, Some(&rcp_url)) else {
        return serde_json::json!({ "error": "no_m3u8" }).to_string();
    };

    serde_json::json!({
        "url": file.url,
        "format": "hls",
        "provider": "vidsrc",
        "headers": {
            "User-Agent": USER_AGENT,
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
            "https://vsembed.su/embed/movie?tmdb=550"
        );
    }

    #[test]
    fn tv_embed_url() {
        assert_eq!(
            build_embed_url(1399, false, Some(2), Some(5)),
            "https://vsembed.su/embed/tv?tmdb=1399&season=2&episode=5"
        );
    }

    #[test]
    fn prorcp_m3u8_with_vhost() {
        let html = r#"<script>file: "https://{v1}/hls/movie.m3u8|720p"</script>"#;
        assert_eq!(
            extract_m3u8_from_prorcp(html, "cloudorchestranova.com", None),
            Some("https://cloudorchestranova.com/hls/movie.m3u8".into())
        );
    }

    #[test]
    fn prorcp_m3u8_or_variants() {
        let html = r#"file: "https://tmstr4.{v1}/a.m3u8 or https://app2.{v2}/b.m3u8""#;
        assert_eq!(
            extract_m3u8_from_prorcp(html, "cloudorchestranova.com", None),
            Some("https://tmstr4.cloudorchestranova.com/a.m3u8".into())
        );
    }

    #[test]
    fn prorcp_master_urls_without_tokens() {
        let html = r#"var master_urls = "https://cdn.example/alpha/master.m3u8 or https://cdn.example/beta/list.m3u8""#;
        assert_eq!(
            extract_m3u8_from_prorcp(html, "cloudorchestranova.com", None),
            Some("https://cdn.example/alpha/master.m3u8".into())
        );
    }

    #[test]
    fn find_prorcp_uses_rcp_host() {
        let rcp_html = r#"src: '/prorcp/token123'"#;
        let url = find_prorcp_url(
            rcp_html,
            "https://cloudorchestranova.com/rcp/abc",
        )
        .unwrap();
        assert_eq!(url, "https://cloudorchestranova.com/prorcp/token123");
    }

    #[test]
    fn chain_golden_fixture_cloudorchestranova() {
        let outer = std::fs::read_to_string("tests/fixtures/vidsrc_outer.html").unwrap();
        let rcp = std::fs::read_to_string("tests/fixtures/vidsrc_rcp.html").unwrap();
        let prorcp = std::fs::read_to_string("tests/fixtures/vidsrc_prorcp.html").unwrap();
        let rcp_url = "https://cloudorchestranova.com/rcp/abc";
        let json = extract_vidsrc_chain_json(&outer, &rcp, &prorcp, Some(rcp_url));
        assert!(json.contains("cloudorchestranova.com/hls/movie.m3u8"));
        let v: serde_json::Value = serde_json::from_str(&json).unwrap();
        let headers = v.get("headers").and_then(|h| h.as_object()).unwrap();
        assert!(headers.get("User-Agent").is_some());
        assert!(headers.get("Referer").is_none());
        assert!(headers.get("Origin").is_none());
    }

    #[test]
    fn chain_legacy_cloudnestra_fixture() {
        let outer = r#"<html><iframe id="player_iframe" src="https://cloudnestra.com/embed/1"></iframe></html>"#;
        let rcp = std::fs::read_to_string("tests/fixtures/vidsrc_rcp.html").unwrap();
        let prorcp = std::fs::read_to_string("tests/fixtures/vidsrc_prorcp.html").unwrap();
        let json = extract_vidsrc_chain_json(
            outer,
            &rcp,
            &prorcp,
            Some("https://cloudnestra.com/rcp/abc"),
        );
        assert!(json.contains("cloudnestra.com/hls/movie.m3u8"));
    }
}
