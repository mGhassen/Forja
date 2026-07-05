use super::SourceEmbed;
use scraper::{Html, Selector};

pub fn parse_html(html: &str, referer: &str, title: Option<&str>) -> Vec<SourceEmbed> {
    let document = Html::parse_document(html);
    let title = title.filter(|s| !s.is_empty()).map(str::to_string);
    let submenu_sel = Selector::parse(".open_submenu").unwrap();
    let link_sel = Selector::parse("[data-tr], [data-video]").unwrap();

    let mut out = Vec::new();
    for sub in document.select(&submenu_sel) {
        let text = sub.text().collect::<String>();
        if !text.contains("Español") {
            continue;
        }
        let country_codes = if text.contains("Latino") {
            vec!["mx".into()]
        } else {
            vec!["es".into()]
        };
        for el in sub.select(&link_sel) {
            let raw = el
                .value()
                .attr("data-tr")
                .or_else(|| el.value().attr("data-video"));
            let Some(raw) = raw else { continue };
            if raw.is_empty() {
                continue;
            }
            out.push(SourceEmbed {
                url: raw.to_string(),
                title: title.clone(),
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
    fn parses_spanish_submenus() {
        let html = r#"
<div class="open_submenu">Español Latino<a data-tr="https://embed.example/lat"></a></div>
<div class="open_submenu">Español Castellano<a data-video="https://embed.example/cas"></a></div>
<div class="open_submenu">English<a data-tr="https://embed.example/en"></a></div>
"#;
        let rows = parse_html(html, "https://cuevana.example/p", Some("Film S01E01"));
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].url, "https://embed.example/lat");
        assert_eq!(rows[0].country_codes, vec!["mx"]);
        assert_eq!(rows[1].country_codes, vec!["es"]);
    }
}
