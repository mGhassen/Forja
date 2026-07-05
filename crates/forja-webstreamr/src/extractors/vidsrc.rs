use crate::types::StreamFile;
use regex::Regex;
use std::sync::LazyLock;

static IFRAME_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)<iframe[^>]+id=["']player_iframe["'][^>]+src=["']([^"']+)["']"#).unwrap()
});
static PRORCP_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"src\s*:\s*['"](/prorcp/[^'"]+)['"]"#).unwrap());
static FILE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"file\s*:\s*["']([^"']+)["']"#).unwrap());

const EMBED_HOST: &str = "https://vsembed.ru";
const DEFAULT_HOST: &str = "cloudnestra.com";

pub fn build_embed_url(
    tmdb_id: i64,
    is_movie: bool,
    season: Option<i32>,
    episode: Option<i32>,
) -> String {
    if is_movie {
        format!("{EMBED_HOST}/embed/movie/{tmdb_id}")
    } else {
        format!(
            "{EMBED_HOST}/embed/tv/{tmdb_id}/{}-{}",
            season.unwrap_or(1),
            episode.unwrap_or(1)
        )
    }
}

pub fn extract_from_html_chain(
    outer_html: &str,
    rcp_html: &str,
    prorcp_html: &str,
) -> Option<StreamFile> {
    let _rcp_path = PRORCP_RE.captures(rcp_html)?.get(1)?.as_str();
    let _iframe = IFRAME_RE.captures(outer_html)?;
    let file_raw = FILE_RE
        .captures(prorcp_html)?
        .get(1)?
        .as_str()
        .split('|')
        .next()?
        .to_string();
    let url = file_raw
        .replace("{v1}", DEFAULT_HOST)
        .replace("{v2}", DEFAULT_HOST);
    let url = if url.starts_with("http") {
        url
    } else if url.starts_with("//") {
        format!("https:{url}")
    } else {
        format!("https://{url}")
    };
    Some(StreamFile {
        url,
        quality: None,
        headers: None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn movie_embed_url() {
        assert_eq!(
            build_embed_url(550, true, None, None),
            "https://vsembed.ru/embed/movie/550"
        );
    }
}
