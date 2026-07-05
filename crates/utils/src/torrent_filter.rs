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

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq)]
pub struct TorrentRow {
    pub name: String,
    pub magnet: String,
    pub seeders: String,
    pub size: String,
    pub source: String,
}

static RELEASE_PREFIX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^\[[^\]]+\]\s*").unwrap());
static YEAR_ONLY: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^\d{4}$").unwrap());
static SEASON_RANGE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)s(\d+)\s*-\s*s?(\d+)").unwrap());

const NOISE_WORDS: &[&str] = &[
    "complete", "series", "season", "multi", "bluray", "webrip", "web", "dl", "hdtv", "x264",
    "x265", "h264", "h265", "hevc", "1080p", "720p", "4k", "uhd",
];

pub fn filter_torrents(
    items: &[TorrentRow],
    show_title: &str,
    required_season: Option<i32>,
    required_episode: Option<i32>,
) -> Vec<TorrentRow> {
    if items.is_empty() || show_title.is_empty() {
        return items.to_vec();
    }

    let norm_show = normalize_title(show_title);

    items
        .iter()
        .filter(|item| {
            let clean_title = RELEASE_PREFIX.replace(&item.name, "").to_string();
            let info = parse_scene_info(&clean_title);
            let title_part = if info.match_index > 0 {
                clean_title[..info.match_index as usize].to_string()
            } else {
                clean_title.clone()
            };
            let norm_title = normalize_title(&title_part);

            if !norm_title.starts_with(&norm_show) {
                return false;
            }

            if required_season.is_some() {
                let mut suffix = norm_title[norm_show.len()..].trim().to_string();
                for word in NOISE_WORDS {
                    suffix = suffix.replace(word, "");
                }
                suffix = suffix.trim().to_string();
                if !suffix.is_empty() && !YEAR_ONLY.is_match(&suffix) {
                    return false;
                }
            }

            if let (Some(season), Some(episode)) = (required_season, required_episode) {
                return info.season == Some(season) && info.episode == Some(episode);
            }

            if let Some(season) = required_season {
                if required_episode.is_some() {
                    // handled above
                } else if let Some(s) = info.season {
                    if s != season {
                        if let Some(caps) = SEASON_RANGE.captures(&clean_title.to_lowercase()) {
                            let start: i32 =
                                caps.get(1).and_then(|m| m.as_str().parse().ok()).unwrap_or(0);
                            let end: i32 =
                                caps.get(2).and_then(|m| m.as_str().parse().ok()).unwrap_or(0);
                            if season < start || season > end {
                                return false;
                            }
                        } else {
                            return false;
                        }
                    }
                }
                return info.is_season_pack
                    || info.is_multi_season
                    || (info.season.is_some() && info.episode.is_none());
            }

            true
        })
        .cloned()
        .collect()
}

fn parse_seeds(seeders: &str) -> i64 {
    seeders
        .chars()
        .filter(|c| c.is_ascii_digit())
        .collect::<String>()
        .parse()
        .unwrap_or(0)
}

fn quality_score(name: &str) -> i32 {
    let n = name.to_lowercase();
    if n.contains("2160p") || n.contains("4k") || n.contains("uhd") {
        return 400;
    }
    if n.contains("1080p") || n.contains("fhd") {
        return 300;
    }
    if n.contains("720p") || n.contains("hd") {
        return 200;
    }
    if n.contains("480p") || n.contains("sd") {
        return 100;
    }
    0
}

fn parse_size_bytes(size: &str) -> f64 {
    let s = size.to_lowercase();
    let value: f64 = s
        .chars()
        .filter(|c| c.is_ascii_digit() || *c == '.')
        .collect::<String>()
        .parse()
        .unwrap_or(0.0);
    if s.contains("gb") {
        value * 1024.0 * 1024.0 * 1024.0
    } else if s.contains("mb") {
        value * 1024.0 * 1024.0
    } else if s.contains("kb") {
        value * 1024.0
    } else {
        value
    }
}

pub fn sort_torrents(items: &mut [TorrentRow], preference: &str) {
    match preference {
        "Seeders (High to Low)" => {
            items.sort_by(|a, b| parse_seeds(&b.seeders).cmp(&parse_seeds(&a.seeders)));
        }
        "Seeders (Low to High)" => {
            items.sort_by(|a, b| parse_seeds(&a.seeders).cmp(&parse_seeds(&b.seeders)));
        }
        "Quality (High to Low)" => items.sort_by(|a, b| {
            quality_score(&b.name)
                .cmp(&quality_score(&a.name))
                .then(parse_seeds(&b.seeders).cmp(&parse_seeds(&a.seeders)))
        }),
        "Quality (Low to High)" => items.sort_by(|a, b| {
            quality_score(&a.name)
                .cmp(&quality_score(&b.name))
                .then(parse_seeds(&b.seeders).cmp(&parse_seeds(&a.seeders)))
        }),
        "Size (High to Low)" => {
            items.sort_by(|a, b| {
                parse_size_bytes(&b.size)
                    .partial_cmp(&parse_size_bytes(&a.size))
                    .unwrap_or(std::cmp::Ordering::Equal)
            });
        }
        "Size (Low to High)" => {
            items.sort_by(|a, b| {
                parse_size_bytes(&a.size)
                    .partial_cmp(&parse_size_bytes(&b.size))
                    .unwrap_or(std::cmp::Ordering::Equal)
            });
        }
        _ => {}
    }
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

    #[test]
    fn sort_by_seeders_desc() {
        let mut rows = vec![
            TorrentRow {
                name: "a".into(),
                magnet: "m1".into(),
                seeders: "10".into(),
                size: "1 GB".into(),
                source: "x".into(),
            },
            TorrentRow {
                name: "b".into(),
                magnet: "m2".into(),
                seeders: "100".into(),
                size: "2 GB".into(),
                source: "x".into(),
            },
        ];
        sort_torrents(&mut rows, "Seeders (High to Low)");
        assert_eq!(rows[0].seeders, "100");
    }
}
