use regex::Regex;
use std::sync::LazyLock;

static MULTI_SXE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)s(\d{1,2})[ ._-]*e(\d{1,3})[ ._-]*-[ ._-]*e?(\d{1,3})").unwrap());
static MULTI_X: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)(\d{1,2})x(\d{1,3})[ ._-]*-[ ._-]*x?(\d{1,3})").unwrap());
static SXE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)s(\d{1,2})[ ._-]*e(\d{1,3})").unwrap());
static X_FMT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)\b(\d{1,2})x(\d{1,3})\b").unwrap());
static WRITTEN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)season\s*(\d{1,2})\s*episode\s*(\d{1,3})").unwrap());
static S_ONLY: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(?i)\bs(\d{1,2})\b").unwrap());
static S_WRITTEN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)season\s*(\d{1,2})\b").unwrap());
static MULTI_SEASON: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)s(\d+)\s*-\s*s?(\d+)|season\s*\d+\s*-\s*\d+").unwrap());

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq)]
pub struct SceneInfo {
    pub season: Option<i32>,
    pub episode: Option<i32>,
    pub is_season_pack: bool,
    pub is_multi_episode: bool,
    pub is_multi_season: bool,
    pub match_index: i32,
}

pub fn normalize_title(title: &str) -> String {
    if title.is_empty() {
        return String::new();
    }
    let re_punct = Regex::new(r#"[",.:!?;_+\-\[\]\(\)]"#).unwrap();
    let re_space = Regex::new(r"\s+").unwrap();
    re_space
        .replace_all(&re_punct.replace_all(&title.to_lowercase(), " "), " ")
        .trim()
        .to_string()
}

pub fn parse_scene_info(title: &str) -> SceneInfo {
    let t = title.to_lowercase();
    let mut season = None;
    let mut episode = None;
    let mut is_multi_episode = MULTI_SXE.is_match(&t) || MULTI_X.is_match(&t);
    let is_multi_season = MULTI_SEASON.is_match(&t)
        || t.contains("complete series")
        || t.contains("collection")
        || t.contains("anthology");
    let mut is_season_pack = false;
    let mut match_index = -1;

    if let Some(m) = SXE.captures(&t) {
        season = m.get(1).and_then(|c| c.as_str().parse().ok());
        episode = m.get(2).and_then(|c| c.as_str().parse().ok());
        match_index = m.get(0).map(|m| m.start() as i32).unwrap_or(-1);
    } else if let Some(m) = X_FMT.captures(&t) {
        season = m.get(1).and_then(|c| c.as_str().parse().ok());
        episode = m.get(2).and_then(|c| c.as_str().parse().ok());
        match_index = m.get(0).map(|m| m.start() as i32).unwrap_or(-1);
    } else if let Some(m) = WRITTEN.captures(&t) {
        season = m.get(1).and_then(|c| c.as_str().parse().ok());
        episode = m.get(2).and_then(|c| c.as_str().parse().ok());
        match_index = m.get(0).map(|m| m.start() as i32).unwrap_or(-1);
    }

    if season.is_none() {
        if let Some(m) = S_ONLY.captures(&t) {
            season = m.get(1).and_then(|c| c.as_str().parse().ok());
            is_season_pack = true;
            match_index = m.get(0).map(|m| m.start() as i32).unwrap_or(-1);
        } else if let Some(m) = S_WRITTEN.captures(&t) {
            season = m.get(1).and_then(|c| c.as_str().parse().ok());
            is_season_pack = true;
            match_index = m.get(0).map(|m| m.start() as i32).unwrap_or(-1);
        }
    }

    if t.contains("complete") || t.contains("season pack") || t.contains("batch") {
        if season.is_some() && episode.is_none() {
            is_season_pack = true;
        }
        if season.is_some() && episode.is_some() {
            is_multi_episode = true;
        }
    }

    if season.is_some() && episode.is_none() && !is_season_pack {
        is_season_pack = true;
    }

    SceneInfo {
        season,
        episode,
        is_season_pack,
        is_multi_episode,
        is_multi_season,
        match_index,
    }
}

pub fn is_video_file(file_name: &str) -> bool {
    let t = file_name.to_lowercase();
    const EXTS: &[&str] = &[
        ".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".mpg", ".mpeg",
        ".m2ts", ".ts", ".vob", ".ogv", ".3gp", ".3g2", ".f4v", ".asf", ".rm", ".rmvb",
        ".divx",
    ];
    EXTS.iter().any(|ext| t.ends_with(ext))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_sxxexx() {
        let info = parse_scene_info("Show.S03E07.1080p.WEB-DL");
        assert_eq!(info.season, Some(3));
        assert_eq!(info.episode, Some(7));
    }

    #[test]
    fn normalize_strips_punct() {
        assert_eq!(normalize_title("Foo: Bar!"), "foo bar");
    }
}
