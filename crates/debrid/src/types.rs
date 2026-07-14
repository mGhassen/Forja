use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DebridFile {
    pub filename: String,
    pub filesize: i64,
    pub download_url: String,
}

#[derive(Debug, Clone)]
pub struct NamedFile {
    pub path: String,
    pub size: u64,
}

pub fn pick_file_index(
    files: &[NamedFile],
    season: Option<i32>,
    episode: Option<i32>,
) -> Option<usize> {
    let sized: Vec<(String, u64)> = files
        .iter()
        .map(|f| (f.path.clone(), f.size))
        .collect();
    match (season, episode) {
        (Some(s), Some(e)) => utils::episode_matcher::pick_episode_index_sized(&sized, s, e),
        _ => utils::episode_matcher::pick_largest_video_index_sized(&sized),
    }
}

pub fn basename(path: &str) -> String {
    path.rsplit(['/', '\\']).next().unwrap_or(path).to_string()
}
