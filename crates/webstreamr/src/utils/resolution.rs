const RESOLUTIONS: &[&str] = &[
    "2160p", "1440p", "1080p", "720p", "576p", "480p", "360p", "240p", "144p",
];

pub fn get_closest_resolution(height: Option<u32>) -> &'static str {
    let Some(height) = height else {
        return "Unknown";
    };
    let nums: Vec<u32> = RESOLUTIONS
        .iter()
        .filter_map(|r| r.trim_end_matches('p').parse().ok())
        .collect();
    let closest = nums
        .iter()
        .min_by_key(|n| height.abs_diff(**n))
        .copied()
        .unwrap_or(height);
    match closest {
        2160 => "2160p",
        1440 => "1440p",
        1080 => "1080p",
        720 => "720p",
        576 => "576p",
        480 => "480p",
        360 => "360p",
        240 => "240p",
        144 => "144p",
        _ => "Unknown",
    }
}

pub fn find_height(value: &str) -> Option<u32> {
    let lower = value.to_lowercase();
    for res in RESOLUTIONS {
        if lower.contains(&res.to_lowercase()) {
            return res.trim_end_matches('p').parse().ok();
        }
    }
    None
}
