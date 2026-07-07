use crate::types::ExtractResult;
use crate::utils::{find_height, parse_bytes};
use regex::Regex;
use scraper::{Html, Selector};
use std::collections::HashMap;
use std::sync::LazyLock;
use url::Url;

static REDIRECT_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"var url ?= ?'(.*?)'").unwrap());

pub fn supports_host(host: &str) -> bool {
    host.contains("hubcloud") || host.contains("vcloud")
}

pub fn extract_from_html(html: &str, _page_url: &str) -> Option<ExtractResult> {
    let links_url = REDIRECT_RE.captures(html)?.get(1)?.as_str();
    Some(ExtractResult {
        next_url: Some(links_url.to_string()),
        ..Default::default()
    })
}

pub fn extract_links_from_html(html: &str, page_url: &str) -> Vec<ExtractResult> {
    let document = Html::parse_document(html);
    let title = document
        .select(&Selector::parse("title").unwrap())
        .next()
        .map(|el| el.text().collect::<String>().trim().to_string())
        .unwrap_or_default();
    let height = find_height(&title);
    let size = document
        .select(&Selector::parse("#size").unwrap())
        .next()
        .map(|el| el.text().collect::<String>())
        .and_then(|t| parse_bytes(&t));

    let mut out = Vec::new();
    for a in document.select(&Selector::parse("a").unwrap()) {
        let text: String = a.text().collect();
        let Some(href) = a.value().attr("href") else {
            continue;
        };

        if text.contains("FSL") && !text.contains("FSLv2") {
            out.push(link_row(
                href,
                "HubCloud (FSL)",
                "hubcloud_fsl",
                &title,
                height,
                size,
                None,
            ));
        } else if text.contains("FSLv2") {
            out.push(link_row(
                href,
                "HubCloud (FSLv2)",
                "hubcloud_fslv2",
                &title,
                height,
                size,
                None,
            ));
        } else if text.contains("PixelServer") {
            let user_url = href.replace("/api/file/", "/u/");
            let api_url = user_url.replace("/u/", "/api/file/");
            let final_url = append_download_query(&api_url);
            let mut headers = HashMap::new();
            headers.insert("Referer".into(), user_url);
            out.push(link_row(
                &final_url,
                "HubCloud (PixelServer)",
                "hubcloud_pixelserver",
                &title,
                height,
                size,
                Some(headers),
            ));
        }
    }
    let _ = page_url;
    out
}

fn append_download_query(api_url: &str) -> String {
    let Ok(mut url) = Url::parse(api_url) else {
        return api_url.to_string();
    };
    let mut pairs: Vec<(String, String)> = url
        .query_pairs()
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();
    pairs.push(("download".into(), String::new()));
    url.query_pairs_mut().clear().extend_pairs(pairs);
    url.to_string()
}

fn link_row(
    href: &str,
    label: &str,
    meta_extractor_id: &str,
    title: &str,
    height: Option<u32>,
    bytes: Option<u64>,
    request_headers: Option<HashMap<String, String>>,
) -> ExtractResult {
    ExtractResult {
        url: href.to_string(),
        title: if title.is_empty() {
            None
        } else {
            Some(title.to_string())
        },
        height,
        request_headers,
        label: Some(label.to_string()),
        bytes,
        meta_extractor_id: Some(meta_extractor_id.to_string()),
        ..Default::default()
    }
}
