use crate::types::{ExtractResult, StreamFormat};
use regex::Regex;
use std::sync::LazyLock;
use url::Url;

static NOT_FOUND: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"Page not found").unwrap());
static IFRAME_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?i)iframe.*?src=["']([^"']+)["']"#).unwrap());
static HEIGHT_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(\d{3,})p").unwrap());
static TITLE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)<h3>([^<]+)</h3>").unwrap());

pub fn supports_host(host: &str) -> bool {
    host.contains("filemoon")
        || matches!(
            host,
            "1azayf9w.xyz"
                | "222i8x.lol"
                | "81u6xl9d.xyz"
                | "8mhlloqo.fun"
                | "96ar.com"
                | "bf0skv.org"
                | "boosteradx.online"
                | "c1z39.com"
                | "cinegrab.com"
                | "f51rm.com"
                | "furher.in"
                | "kerapoxy.cc"
                | "l1afav.net"
                | "moonmov.pro"
                | "smdfs40r.skin"
                | "xcoic.com"
                | "z1ekv717.fun"
        )
}

fn resolve_url(src: &str, page_url: &str) -> String {
    if src.starts_with("http://") || src.starts_with("https://") {
        return src.to_string();
    }
    if let Ok(base) = Url::parse(page_url) {
        if let Ok(joined) = base.join(src) {
            return joined.to_string();
        }
    }
    src.to_string()
}

pub fn extract_from_html(html: &str, page_url: &str) -> Option<ExtractResult> {
    if NOT_FOUND.is_match(html) {
        return None;
    }
    let iframes: Vec<_> = IFRAME_RE.captures_iter(html).collect();
    if !iframes.is_empty() {
        let src = iframes.last()?.get(1)?.as_str();
        let title = TITLE_RE
            .captures(html)
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().trim().to_string())
            .filter(|s| !s.is_empty());
        return Some(ExtractResult {
            format: StreamFormat::Unknown,
            title,
            next_url: Some(resolve_url(src, page_url)),
            ..Default::default()
        });
    }

    let unpacked = forja_utils::js_unpacker::unpack_eval(html).ok()?;
    let height = HEIGHT_RE
        .captures(&unpacked)
        .and_then(|c| c.get(1))
        .and_then(|m| m.as_str().parse().ok());

    Some(ExtractResult {
        format: StreamFormat::Hls,
        height,
        ..Default::default()
    })
}
