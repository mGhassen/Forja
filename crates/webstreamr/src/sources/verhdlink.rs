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
    for mirror in document.select(&Selector::parse("._player-mirrors").unwrap()) {
        let class = mirror.value().attr("class").unwrap_or_default();
        let country_codes = if class.contains("latino") {
            vec!["mx".into()]
        } else if class.contains("castellano") {
            vec!["es".into()]
        } else {
            continue;
        };
        for el in mirror.select(&Selector::parse("[data-link]").unwrap()) {
            let Some(raw) = el.value().attr("data-link") else {
                continue;
            };
            if raw.is_empty() {
                continue;
            }
            let url = normalize_link(raw);
            if url.contains("verhdlink") {
                continue;
            }
            out.push(SourceEmbed {
                url,
                title: None,
                country_codes: country_codes.clone(),
                referer: Some(referer.to_string()),
                priority: None,
                height: None,
                bytes: None,
            });
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_mirror_links_by_language() {
        let html = r#"
<div class="_player-mirrors latino"><a data-link="//cdn.example/lat"></a></div>
<div class="_player-mirrors castellano"><a data-link="https://cdn.example/cas"></a></div>
<div class="_player-mirrors other"><a data-link="https://cdn.example/skip"></a></div>
"#;
        let rows = parse_html(html, "https://verhdlink.cam");
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].url, "https://cdn.example/lat");
        assert_eq!(rows[0].country_codes, vec!["mx"]);
        assert_eq!(rows[1].country_codes, vec!["es"]);
    }
}
