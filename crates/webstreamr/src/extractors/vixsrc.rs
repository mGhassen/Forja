use crate::types::{ExtractResult, StreamFormat};
use regex::Regex;
use std::collections::HashMap;
use std::sync::LazyLock;
use url::Url;

static TOKEN_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"['"]token['"]\s*[:=]\s*['"]([^'"]+)['"]"#).unwrap());
static EXPIRES_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"['"]expires['"]\s*[:=]\s*['"]([^'"]+)['"]"#).unwrap());
static URL_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"url\s*[:=]\s*['"](https?://[^'"]+)['"]|['"]url['"]\s*[:=]\s*['"](https?://[^'"]+)['"]|(https?://[^'"\s]+\.mp4[^'"\s]*)|(https?://[^'"\s]+\.m3u8[^'"\s]*)"#,
    )
    .unwrap()
});

pub fn supports_host(host: &str) -> bool {
    host.contains("vixsrc")
}

fn first_url_match<'a>(caps: &'a regex::Captures<'a>) -> Option<&'a str> {
    (1..=4).find_map(|i| caps.get(i).map(|m| m.as_str()))
}

pub fn extract_from_html(html: &str, page_url: &str) -> Option<ExtractResult> {
    let token = TOKEN_RE.captures(html)?.get(1)?.as_str();
    let expires = EXPIRES_RE.captures(html)?.get(1)?.as_str();
    let url_caps = URL_RE.captures(html)?;
    let base_url = first_url_match(&url_caps)?;
    let mut base = Url::parse(base_url).ok()?;
    base.set_path(&format!("{}.m3u8", base.path()));
    {
        let mut qp = base.query_pairs_mut();
        qp.clear();
        qp.append_pair("token", token);
        qp.append_pair("expires", expires);
        qp.append_pair("h", "1");
    }

    let mut request_headers = HashMap::new();
    request_headers.insert("Referer".into(), page_url.to_string());

    Some(ExtractResult {
        url: base.to_string(),
        format: StreamFormat::Hls,
        request_headers: Some(request_headers),
        ..Default::default()
    })
}
