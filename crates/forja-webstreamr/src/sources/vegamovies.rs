use super::SourceEmbed;
use regex::Regex;
use std::sync::LazyLock;

static VCLOUD_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"href="(https?://[^"]*vcloud[^"]+)""#).unwrap());
static EPISODE_HEADER_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?:-\s*:|:)\s*Episodes?\s*:?\s*0*(\d{1,3})\s*:?\s*-?").unwrap()
});
static HEIGHT_IN_LABEL_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(2160|1440|1080|720|576|480|360|240|144)p").unwrap());

fn episode_slice(html: &str, episode: i32) -> Option<String> {
    let matches: Vec<_> = EPISODE_HEADER_RE.captures_iter(html).collect();
    for (i, m) in matches.iter().enumerate() {
        let n: i32 = m.get(1)?.as_str().parse().ok()?;
        if n != episode {
            continue;
        }
        let start = m.get(0)?.end();
        let end = matches
            .get(i + 1)
            .and_then(|next| next.get(0))
            .map(|m| m.start())
            .unwrap_or(html.len());
        return Some(html[start..end].to_string());
    }
    None
}

fn height_from_label(label: Option<&str>) -> Option<i32> {
    let label = label?;
    let lower = label.to_lowercase();
    for cap in HEIGHT_IN_LABEL_RE.captures_iter(&lower) {
        if let Ok(h) = cap.get(1)?.as_str().parse() {
            return Some(h);
        }
    }
    None
}

pub fn parse_nexdrive_html(
    html: &str,
    referer: &str,
    episode: Option<i32>,
    label: Option<&str>,
) -> Vec<SourceEmbed> {
    let scope = if let Some(ep) = episode {
        episode_slice(html, ep).unwrap_or_default()
    } else {
        html.to_string()
    };
    if scope.is_empty() {
        return Vec::new();
    }

    let height = height_from_label(label);
    let title = label.filter(|s| !s.is_empty()).map(str::to_string);
    let mut seen = std::collections::HashSet::new();
    let mut out = Vec::new();

    for cap in VCLOUD_RE.captures_iter(&scope) {
        let url = cap.get(1).map(|m| m.as_str()).unwrap_or("");
        if url.is_empty() || !seen.insert(url.to_string()) {
            continue;
        }
        out.push(SourceEmbed {
            url: url.to_string(),
            title: title.clone(),
            country_codes: vec!["multi".into(), "hi".into(), "en".into()],
            referer: Some(referer.to_string()),
            priority: None,
            height,
            bytes: None,
        });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_vcloud_links() {
        let html = r#"<a href="https://vcloud.example/a.zip">DL</a>"#;
        let rows = parse_nexdrive_html(html, "https://nexdrive.example/p", None, Some("1080p"));
        assert_eq!(rows[0].url, "https://vcloud.example/a.zip");
        assert_eq!(rows[0].height, Some(1080));
    }

    #[test]
    fn slices_episode_section() {
        let html = r#"
-:Episode: 1:-
<a href="https://vcloud.example/ep1.zip">DL</a>
-:Episode: 2:-
<a href="https://vcloud.example/ep2.zip">DL</a>
"#;
        let rows = parse_nexdrive_html(html, "https://nexdrive.example/p", Some(2), None);
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].url, "https://vcloud.example/ep2.zip");
    }
}
