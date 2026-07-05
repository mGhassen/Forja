use super::mirrors::parse_episode_mirrors;
use super::SourceEmbed;

pub fn parse_html(
    html: &str,
    referer: &str,
    season: i32,
    episode: i32,
    title: Option<&str>,
) -> Vec<SourceEmbed> {
    parse_episode_mirrors(
        html,
        referer,
        season,
        episode,
        title.filter(|s| !s.is_empty()).map(str::to_string),
        vec!["it".into()],
        "eurostreaming",
        false,
    )
}
