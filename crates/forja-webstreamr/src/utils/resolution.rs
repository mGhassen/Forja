const RESOLUTIONS: &[&str] = &[
    "2160p", "1440p", "1080p", "720p", "576p", "480p", "360p", "240p", "144p",
];

pub fn find_height(value: &str) -> Option<u32> {
    let lower = value.to_lowercase();
    for res in RESOLUTIONS {
        if lower.contains(&res.to_lowercase()) {
            return res.trim_end_matches('p').parse().ok();
        }
    }
    None
}
