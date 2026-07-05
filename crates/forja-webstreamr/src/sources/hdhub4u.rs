use super::SourceEmbed;
use scraper::{Html, Selector};

pub fn parse_html(html: &str, referer: &str, country_codes: &[String]) -> Vec<SourceEmbed> {
    let document = Html::parse_document(html);
    let ccs = if country_codes.is_empty() {
        vec!["multi".into()]
    } else {
        country_codes.to_vec()
    };

    let mut out = Vec::new();
    for a in document.select(&Selector::parse(r#"a[href*="hubdrive"]"#).unwrap()) {
        let text = a.text().collect::<String>();
        if text.contains('⚡') {
            continue;
        }
        let Some(href) = a.value().attr("href") else {
            continue;
        };
        if href.is_empty() {
            continue;
        }
        out.push(SourceEmbed {
            url: href.to_string(),
            title: None,
            country_codes: ccs.clone(),
            referer: Some(referer.to_string()),
            priority: None,
        });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_hubdrive_links() {
        let html = r#"
<a href="https://hubdrive.example/a">Download</a>
<a href="https://hubdrive.example/skip">⚡ Fast</a>
"#;
        let rows = parse_html(
            html,
            "https://hdhub4u.example/p",
            &["hi".into(), "multi".into()],
        );
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].url, "https://hubdrive.example/a");
        assert!(rows[0].country_codes.contains(&"hi".into()));
    }
}
