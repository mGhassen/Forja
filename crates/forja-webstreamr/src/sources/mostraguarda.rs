use super::SourceEmbed;
use regex::Regex;
use scraper::{Html, Selector};
use std::sync::LazyLock;

static PROTOCOL_FIX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(https:)?//").unwrap());

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
        let url = PROTOCOL_FIX.replace(raw, "https://").to_string();
        if url.contains("mostraguarda") {
            continue;
        }
        out.push(SourceEmbed {
            url,
            title: None,
            country_codes: vec!["it".into()],
            referer: Some(referer.to_string()),
            priority: None,
        });
    }
    out
}
