use super::SourceEmbed;
use scraper::{Html, Selector};

pub fn parse_html(html: &str, referer: &str) -> Vec<SourceEmbed> {
    let document = Html::parse_document(html);
    let title = document
        .select(&Selector::parse(r#"meta[property="og:title"]"#).unwrap())
        .next()
        .and_then(|el| el.value().attr("content"))
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());

    let mut out = Vec::new();
    for iframe in document.select(&Selector::parse(".video-inside iframe").unwrap()) {
        let src = iframe
            .value()
            .attr("data-src")
            .or_else(|| iframe.value().attr("src"));
        let Some(src) = src else { continue };
        if src.is_empty() {
            continue;
        }
        out.push(SourceEmbed {
            url: src.to_string(),
            title: title.clone(),
            country_codes: vec!["de".into()],
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
    fn parses_video_iframes() {
        let html = r#"
<head><meta property="og:title" content="Test Film"></head>
<div class="video-inside"><iframe data-src="https://embed.example/1"></iframe></div>
<div class="video-inside"><iframe src="https://embed.example/2"></iframe></div>
"#;
        let rows = parse_html(html, "https://megakino.example/watch/1");
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].url, "https://embed.example/1");
        assert_eq!(rows[0].title.as_deref(), Some("Test Film"));
    }
}
