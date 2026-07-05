use super::SourceEmbed;
use regex::Regex;
use scraper::{Html, Selector};
use std::sync::LazyLock;

static PROTOCOL_FIX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(https:)?//").unwrap());

fn normalize_link(raw: &str) -> String {
    PROTOCOL_FIX.replace(raw, "https://").to_string()
}

pub fn parse_html(html: &str, referer: &str) -> Vec<SourceEmbed> {
    let document = Html::parse_document(html);
    let mut out = Vec::new();
    for el in document.select(&Selector::parse("[data-link]").unwrap()) {
        let Some(raw) = el.value().attr("data-link") else {
            continue;
        };
        if raw.is_empty() {
            continue;
        }
        let url = normalize_link(raw);
        if url.contains("meinecloud") {
            continue;
        }
        out.push(SourceEmbed {
            url,
            title: None,
            country_codes: vec!["de".into()],
            referer: Some(referer.to_string()),
            priority: None,
            height: None,
            bytes: None,
        });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_data_links() {
        let html = r#"<div data-link="//embed.example/a"></div><div data-link="https://embed.example/b"></div><div data-link="//meinecloud.click/x"></div>"#;
        let rows = parse_html(html, "https://meinecloud.click");
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].url, "https://embed.example/a");
        assert_eq!(rows[1].url, "https://embed.example/b");
    }
}
