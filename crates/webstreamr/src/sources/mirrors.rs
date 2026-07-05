use super::SourceEmbed;
use regex::Regex;
use scraper::{ElementRef, Html, Selector};
use std::sync::LazyLock;

static PROTOCOL_FIX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(https:)?//").unwrap());

fn normalize_link(raw: &str, fix_protocol: bool) -> String {
    if fix_protocol {
        PROTOCOL_FIX.replace(raw, "https://").to_string()
    } else {
        raw.to_string()
    }
}

pub fn parse_episode_mirrors(
    html: &str,
    referer: &str,
    season: i32,
    episode: i32,
    title: Option<String>,
    country_codes: Vec<String>,
    skip_host: &str,
    fix_protocol: bool,
) -> Vec<SourceEmbed> {
    let document = Html::parse_document(html);
    let num = format!("{season}x{episode}");
    let num_sel = Selector::parse(&format!(r#"[data-num="{num}"]"#)).unwrap();
    let mirrors_sel = Selector::parse(".mirrors").unwrap();
    let link_sel = Selector::parse("[data-link]").unwrap();

    let mut out = Vec::new();
    for marker in document.select(&num_sel) {
        let Some(parent) = marker.parent().and_then(ElementRef::wrap) else {
            continue;
        };
        let Some(mirrors) = parent.select(&mirrors_sel).next() else {
            continue;
        };
        for el in mirrors.select(&link_sel) {
            let Some(raw) = el.value().attr("data-link") else {
                continue;
            };
            if raw.is_empty() || raw == "#" {
                continue;
            }
            let url = normalize_link(raw, fix_protocol);
            if url.contains(skip_host) {
                continue;
            }
            out.push(SourceEmbed {
                url,
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
    fn parses_mirrors_for_episode() {
        let html = r#"
<div>
  <span data-num="1x2"></span>
  <div class="mirrors">
    <a data-link="https://embed.example/a"></a>
    <a data-link="//skip.example/x"></a>
  </div>
</div>
"#;
        let rows = parse_episode_mirrors(
            html,
            "https://example.com/p",
            1,
            2,
            Some("Show S01E02".into()),
            vec!["de".into()],
            "skip.example",
            true,
        );
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].url, "https://embed.example/a");
    }
}
