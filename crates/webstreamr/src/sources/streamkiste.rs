use super::mirrors::parse_episode_mirrors;
use super::{format_season_episode, SourceEmbed};
use scraper::{Html, Selector};

fn title_from_html(html: &str, season: i32, episode: i32) -> Option<String> {
    let document = Html::parse_document(html);
    let og = document
        .select(&Selector::parse(r#"meta[property="og:title"]"#).unwrap())
        .next()
        .and_then(|el| el.value().attr("content"))
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())?;
    Some(format!("{og} {}", format_season_episode(season, episode)))
}

pub fn parse_html(
    html: &str,
    referer: &str,
    season: i32,
    episode: i32,
    title: Option<&str>,
) -> Vec<SourceEmbed> {
    let title = title
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| title_from_html(html, season, episode));
    parse_episode_mirrors(
        html,
        referer,
        season,
        episode,
        title,
        vec!["de".into()],
        "streamkiste",
        true,
    )
}
