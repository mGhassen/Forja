use super::SourceEmbed;
use regex::Regex;
use scraper::{Html, Selector};
use std::sync::LazyLock;

static SIZE_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"([\d.]+ ?[GM]B)").unwrap());
static HEIGHT_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(\d{3,})p").unwrap());

fn find_country_codes(text: &str) -> Vec<String> {
    const LANGS: &[(&str, &str)] = &[
        ("Hindi", "hi"),
        ("Tamil", "ta"),
        ("Telugu", "te"),
        ("Multi", "multi"),
    ];
    let mut out = vec!["multi".to_string()];
    for (name, code) in LANGS {
        if text.contains(name) && !out.iter().any(|c| c == *code) {
            out.push((*code).into());
        }
    }
    out
}

fn parse_bytes(input: &str) -> Option<u64> {
    let caps = Regex::new(r"([\d.,]+)\s*([KMGTP]?B)")
        .unwrap()
        .captures(input)?;
    let num: f64 = caps.get(1)?.as_str().replace(',', "").parse().ok()?;
    let mult = match caps.get(2)?.as_str().to_uppercase().as_str() {
        "KB" => 1024.0,
        "MB" => 1024.0 * 1024.0,
        "GB" => 1024.0 * 1024.0 * 1024.0,
        "TB" => 1024.0 * 1024.0 * 1024.0 * 1024.0,
        _ => 1.0,
    };
    Some((num * mult).round() as u64)
}

fn extract_from_element(inner_html: &str, referer: &str) -> Option<SourceEmbed> {
    let document = Html::parse_fragment(inner_html);
    let title = document
        .select(&Selector::parse(".file-title, .episode-file-title").unwrap())
        .next()
        .map(|el| el.text().collect::<String>().trim().to_string())
        .filter(|s| !s.is_empty());

    let size_m = SIZE_RE.find(inner_html).map(|m| m.as_str());
    let height_m = HEIGHT_RE
        .captures(inner_html)
        .and_then(|c| c.get(1))
        .and_then(|m| m.as_str().parse().ok());

    let mut hub_cloud = None;
    let mut hub_drive = None;
    for a in document.select(&Selector::parse("a").unwrap()) {
        let text = a.text().collect::<String>();
        let href = a.value().attr("href")?;
        if text.contains("HubCloud") {
            hub_cloud = Some(href.to_string());
            break;
        }
        if text.contains("HubDrive") {
            hub_drive = Some(href.to_string());
        }
    }
    let url = hub_cloud.or(hub_drive)?;

    Some(SourceEmbed {
        url,
        title,
        country_codes: find_country_codes(inner_html),
        referer: Some(referer.to_string()),
        priority: None,
        height: height_m,
        bytes: size_m.and_then(parse_bytes),
    })
}

pub fn parse_html(
    html: &str,
    referer: &str,
    is_series: bool,
    season: Option<i32>,
    episode: Option<i32>,
) -> Vec<SourceEmbed> {
    let document = Html::parse_document(html);
    let mut out = Vec::new();

    if is_series {
        let (Some(season), Some(episode)) = (season, episode) else {
            return out;
        };
        let s = format!("{season:02}");
        let e = format!("{episode:02}");
        for ep in document.select(&Selector::parse(".episode-item").unwrap()) {
            let ep_title = ep
                .select(&Selector::parse(".episode-title").unwrap())
                .next()
                .map(|el| el.text().collect::<String>())
                .unwrap_or_default();
            if !ep_title.contains(&format!("S{s}")) {
                continue;
            }
            for dl in ep.select(&Selector::parse(".episode-download-item").unwrap()) {
                let text = dl.text().collect::<String>();
                if !text.contains(&format!("Episode-{e}")) {
                    continue;
                }
                let inner = dl.html();
                if let Some(row) = extract_from_element(&inner, referer) {
                    out.push(row);
                }
            }
        }
        return out;
    }

    for dl in document.select(&Selector::parse(".download-item").unwrap()) {
        let inner = dl.html();
        if let Some(row) = extract_from_element(&inner, referer) {
            out.push(row);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_movie_download() {
        let html = r#"
<div class="download-item">
  <span class="file-title">Film 1080p</span>
  Hindi
  1.2 GB 1080p
  <a href="https://hubcloud.example/x">HubCloud</a>
</div>
"#;
        let rows = parse_html(html, "https://4khdhub.example/p", false, None, None);
        assert_eq!(rows[0].url, "https://hubcloud.example/x");
        assert_eq!(rows[0].height, Some(1080));
        assert!(rows[0].country_codes.contains(&"hi".into()));
    }
}
