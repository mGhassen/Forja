use super::SourceEmbed;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct WatchResponse {
    #[serde(rename = "streamUrl")]
    stream_url: String,
    #[serde(rename = "releaseName")]
    release_name: String,
}

pub fn parse_json(body: &str, referer: &str) -> Vec<SourceEmbed> {
    let data: WatchResponse = match serde_json::from_str(body) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };
    if data.stream_url.is_empty() {
        return Vec::new();
    }
    vec![SourceEmbed {
        url: data.stream_url,
        title: Some(data.release_name),
        country_codes: vec!["de".into()],
        referer: Some(referer.to_string()),
        priority: None,
        height: None,
        bytes: None,
    }]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_watch_response() {
        let body = r#"{"streamUrl":"https://cdn.example/movie.m3u8","releaseName":"Film"}"#;
        let rows = parse_json(body, "https://einschalten.in/movies/123");
        assert_eq!(rows[0].url, "https://cdn.example/movie.m3u8");
        assert_eq!(rows[0].title.as_deref(), Some("Film"));
        assert_eq!(rows[0].country_codes, vec!["de"]);
    }
}
