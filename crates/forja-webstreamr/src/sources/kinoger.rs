use regex::Regex;
use std::sync::LazyLock;

static SHOW_JS_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\.show\(.*").unwrap());
static LIST_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\[(.*?)]").unwrap());
static URL_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"https?://[^\s'"<>]+"#).unwrap());

pub fn extract_episode_urls(html: &str, season_index: usize, episode_index: usize) -> Vec<String> {
    let mut out = Vec::new();
    for m in SHOW_JS_RE.find_iter(html) {
        if let Some(url) = find_episode_url_in_show_js(m.as_str(), season_index, episode_index) {
            out.push(url);
        }
    }
    out
}

fn find_episode_url_in_show_js(show_js: &str, season_index: usize, episode_index: usize) -> Option<String> {
    let lists: Vec<_> = LIST_RE.captures_iter(show_js).collect();
    let inner = lists.get(season_index)?.get(1)?.as_str();
    let parts: Vec<_> = inner.split(',').collect();
    let part = parts.get(episode_index)?;
    URL_RE
        .find(part)
        .map(|m| m.as_str().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_episode_url_from_show_js() {
        let html = r#"<script>$(".ep").show([["https://cdn.example/ep1.m3u8","x"],["https://cdn.example/s2e1.m3u8"]])</script>"#;
        let urls = extract_episode_urls(html, 1, 0);
        assert_eq!(urls, vec!["https://cdn.example/s2e1.m3u8"]);
    }
}
