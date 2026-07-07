use crate::types::ExtractResult;
use scraper::{Html, Selector};

pub fn supports_host(host: &str) -> bool {
    host.contains("hubdrive")
}

pub fn extract_from_html(html: &str, _page_url: &str) -> Option<ExtractResult> {
    let document = Html::parse_document(html);
    for a in document.select(&Selector::parse("a").ok()?) {
        let text: String = a.text().collect();
        if !text.contains("HubCloud") {
            continue;
        }
        let href = a.value().attr("href")?;
        if href.is_empty() {
            continue;
        }
        return Some(ExtractResult {
            next_url: Some(href.to_string()),
            ..Default::default()
        });
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ignores_stylesheet_href_before_hubcloud_anchor() {
        let html = r#"
<link href="/assets/vendor/fontawesome-free/css/all.min.css" rel="stylesheet">
<a href="https://hubcloud.example/drive/abc"><i></i> [HubCloud Server]</a>
"#;
        let r = extract_from_html(html, "https://hubdrive.example/file/1").unwrap();
        assert_eq!(r.next_url.as_deref(), Some("https://hubcloud.example/drive/abc"));
    }
}
