use super::{format_season_episode, movie_title, SourceEmbed};
use serde_json::Value;
use url::Url;

pub fn parse_json(
    body: &str,
    origin: &str,
    is_series: bool,
    season: Option<i32>,
    episode: Option<i32>,
    year: Option<i32>,
) -> Vec<SourceEmbed> {
    let json: Value = match serde_json::from_str(body) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };
    let Some(obj) = json.as_object() else {
        return Vec::new();
    };

    let api_title = obj.get("title").and_then(|v| v.as_str()).unwrap_or("");
    let title = if is_series {
        let (Some(season), Some(episode)) = (season, episode) else {
            return Vec::new();
        };
        Some(format!("{api_title} {}", format_season_episode(season, episode)))
    } else {
        year.map(|y| movie_title(api_title, y))
    };

    let base = match Url::parse(origin) {
        Ok(u) => u,
        Err(_) => return Vec::new(),
    };

    let mut out = Vec::new();
    for (key, value) in obj {
        if !key.starts_with("link") {
            continue;
        }
        let Some(path) = value.as_str() else { continue };
        if path.is_empty() || path.contains(",https") {
            continue;
        }
        let Some(url) = resolve_link(&base, path) else {
            continue;
        };
        out.push(SourceEmbed {
            url,
            title: title.clone(),
            country_codes: vec!["fr".into()],
            referer: Some(origin.to_string()),
            priority: None,
            height: None,
            bytes: None,
        });
    }
    out
}

fn resolve_link(base: &Url, path: &str) -> Option<String> {
    let trimmed = path.trim();
    if trimmed.starts_with("http://") || trimmed.starts_with("https://") {
        return Some(trimmed.to_string());
    }
    base.join(trimmed.trim_start_matches('/'))
        .ok()
        .map(|u| u.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_link_keys() {
        let body = r#"{"title":"Film","link1":"/embed/a","link2":"https://embed.example/b","link3":",https://skip"}"#;
        let rows = parse_json(body, "https://frembed.work", false, None, None, Some(2020));
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].url, "https://frembed.work/embed/a");
        assert_eq!(rows[0].title.as_deref(), Some("Film (2020)"));
    }
}
