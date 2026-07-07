use super::SourceEmbed;
use scraper::{Html, Selector};
use serde::Deserialize;

pub fn parse_page_html(html: &str, base_url: &str) -> Vec<SourceEmbed> {
    let document = Html::parse_document(html);
    let base = base_url.trim_end_matches('/');
    let sel = Selector::parse(".dooplay_player_option").unwrap();

    let mut out = Vec::new();
    for el in document.select(&sel) {
        if el.value().id() == Some("player-option-trailer") {
            continue;
        }
        let Some(post) = el.value().attr("data-post") else {
            continue;
        };
        let Some(dtype) = el.value().attr("data-type") else {
            continue;
        };
        let Some(nume) = el.value().attr("data-nume") else {
            continue;
        };
        if post.is_empty() || dtype.is_empty() || nume.is_empty() {
            continue;
        }
        out.push(SourceEmbed {
            url: format!("{base}/wp-json/dooplayer/v2/{post}/{dtype}/{nume}"),
            title: None,
            country_codes: vec!["al".into()],
            referer: None,
            priority: None,
            height: None,
            bytes: None,
        });
    }
    out
}

#[derive(Debug, Deserialize)]
struct DooplayerResponse {
    embed_url: String,
}

pub fn parse_dooplayer_json(body: &str, referer: &str, title: Option<&str>) -> Vec<SourceEmbed> {
    let data: DooplayerResponse = match serde_json::from_str(body) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };
    if data.embed_url.is_empty() {
        return Vec::new();
    }
    vec![SourceEmbed {
        url: data.embed_url,
        title: title.filter(|s| !s.is_empty()).map(str::to_string),
        country_codes: vec!["al".into()],
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
    fn parses_player_options() {
        let html = r#"
<div class="dooplay_player_option" data-post="1" data-type="movie" data-nume="0"></div>
<div class="dooplay_player_option" id="player-option-trailer" data-post="2" data-type="movie" data-nume="0"></div>
"#;
        let rows = parse_page_html(html, "https://kokoshka.digital");
        assert_eq!(rows.len(), 1);
        assert!(rows[0].url.contains("/wp-json/dooplayer/v2/1/movie/0"));
    }

    #[test]
    fn parses_dooplayer_json() {
        let body = r#"{"embed_url":"https://embed.example/x"}"#;
        let rows = parse_dooplayer_json(body, "https://kokoshka.digital/p", Some("Film"));
        assert_eq!(rows[0].url, "https://embed.example/x");
    }
}
