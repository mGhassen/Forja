use super::SourceEmbed;
use scraper::{Html, Selector};

pub fn parse_html(html: &str, referer: &str, title: Option<&str>) -> Vec<SourceEmbed> {
    let document = Html::parse_document(html);
    let title = title.filter(|s| !s.is_empty()).map(str::to_string);
    let anchor_sel = Selector::parse(".les-content a").unwrap();
    let iframe_sel = Selector::parse("iframe").unwrap();

    let mut out = Vec::new();
    for anchor in document.select(&anchor_sel) {
        let text = anchor.text().collect::<String>().to_lowercase();
        let country_codes = if text.contains("latino") {
            vec!["mx".into()]
        } else if text.contains("castellano") {
            vec!["es".into()]
        } else {
            continue;
        };
        let Some(iframe) = anchor.select(&iframe_sel).next() else {
            continue;
        };
        let Some(src) = iframe.value().attr("src") else {
            continue;
        };
        if src.is_empty() {
            continue;
        }
        out.push(SourceEmbed {
            url: src.to_string(),
            title: title.clone(),
            country_codes,
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
    fn parses_language_iframes() {
        let html = r#"
<div class="les-content">
  <a>Latino<iframe src="https://embed.example/lat"></iframe></a>
  <a>Castellano<iframe src="https://embed.example/cas"></iframe></a>
  <a>Other<iframe src="https://embed.example/skip"></iframe></a>
</div>
"#;
        let rows = parse_html(html, "https://homecine.example/p", Some("Film (2020)"));
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].url, "https://embed.example/lat");
        assert_eq!(rows[0].country_codes, vec!["mx"]);
        assert_eq!(rows[0].title.as_deref(), Some("Film (2020)"));
        assert_eq!(rows[1].country_codes, vec!["es"]);
    }
}
