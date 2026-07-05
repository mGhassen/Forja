use regex::Regex;
use std::sync::LazyLock;

const VIDEO_EXTS: &[&str] = &[
    ".mkv", ".mp4", ".avi", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".ts", ".mpg", ".mpeg",
    ".m2ts", ".divx", ".vob", ".ogv",
];

static SEASON_EPISODE_PATTERNS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    vec![
        Regex::new(r"(?i)s0*(\d{1,3})[\s._\-]*e0*(\d{1,4})").unwrap(),
        Regex::new(r"(?i)(?:^|[^a-z0-9])0*(\d{1,3})x0*(\d{1,4})(?:[^a-z0-9]|$)").unwrap(),
        Regex::new(r"(?i)season\s*0*(\d{1,3})\s*(?:episode|ep)\s*0*(\d{1,4})").unwrap(),
    ]
});

static EPISODE_ONLY_PATTERNS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    vec![
        Regex::new(r"(?i)(?:^|[^a-z0-9])e(?:p|pisode)?[\s._\-]*0*(\d{1,4})(?:[^a-z0-9]|$)").unwrap(),
        Regex::new(r"(?i)^\s*0*(\d{1,4})\s*[-._]\s*").unwrap(),
    ]
});

fn basename(filename: &str) -> String {
    if filename.is_empty() {
        return String::new();
    }
    filename
        .to_lowercase()
        .split(['/', '\\'])
        .next_back()
        .unwrap_or("")
        .to_string()
}

pub fn matches(filename: &str, season: i32, episode: i32) -> bool {
    let base = basename(filename);
    if base.is_empty() {
        return false;
    }
    for pattern in SEASON_EPISODE_PATTERNS.iter() {
        for caps in pattern.captures_iter(&base) {
            let s = caps.get(1).and_then(|m| m.as_str().parse().ok());
            let e = caps.get(2).and_then(|m| m.as_str().parse().ok());
            if s == Some(season) && e == Some(episode) {
                return true;
            }
        }
    }
    false
}

pub fn matches_episode_only(filename: &str, episode: i32) -> bool {
    let base = basename(filename);
    if base.is_empty() {
        return false;
    }
    for pattern in EPISODE_ONLY_PATTERNS.iter() {
        for caps in pattern.captures_iter(&base) {
            let e = caps.get(1).and_then(|m| m.as_str().parse().ok());
            if e == Some(episode) {
                return true;
            }
        }
    }
    false
}

fn is_video(name: &str) -> bool {
    let n = name.to_lowercase();
    if !VIDEO_EXTS.iter().any(|ext| n.ends_with(ext)) {
        return false;
    }
    if n.contains("sample") {
        return false;
    }
    if n.contains("featurette") {
        return false;
    }
    if n.contains("behind.the.scenes") || n.contains("behind-the-scenes") {
        return false;
    }
    if n.contains("/extras/") || n.contains(r"\extras\") {
        return false;
    }
    true
}

pub fn pick_episode_index(
    files: &[String],
    season: i32,
    episode: i32,
) -> Option<usize> {
    let videos: Vec<(usize, &String)> = files
        .iter()
        .enumerate()
        .filter(|(_, name)| is_video(name))
        .collect();
    if videos.is_empty() {
        return None;
    }

    let strong: Vec<(usize, &String)> = videos
        .iter()
        .copied()
        .filter(|(_, name)| matches(name, season, episode))
        .collect();
    if !strong.is_empty() {
        return Some(strong[0].0);
    }

    let has_any_strong = videos.iter().any(|(_, name)| {
        let base = basename(name);
        SEASON_EPISODE_PATTERNS.iter().any(|p| p.is_match(&base))
    });

    if !has_any_strong {
        let ep_only: Vec<(usize, &String)> = videos
            .iter()
            .copied()
            .filter(|(_, name)| matches_episode_only(name, episode))
            .collect();
        if !ep_only.is_empty() {
            return Some(ep_only[0].0);
        }
    }

    Some(videos[0].0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_sxxexx() {
        assert!(matches("Show.S03E07.1080p.mkv", 3, 7));
        assert!(matches("Show.s3e7.WEB-DL.mkv", 3, 7));
        assert!(!matches("Show.S03E07.1080p.mkv", 3, 8));
    }

    #[test]
    fn matches_nxnn() {
        assert!(matches("Show.3x07.HDTV.mkv", 3, 7));
    }

    #[test]
    fn pick_episode_prefers_match() {
        let files = vec![
            "sample.mkv".to_string(),
            "Show.S03E07.720p.mkv".to_string(),
            "Show.S03E07.1080p.mkv".to_string(),
        ];
        let idx = pick_episode_index(&files, 3, 7);
        assert!(idx.is_some());
        assert!(files[idx.unwrap()].contains("S03E07"));
    }
}
