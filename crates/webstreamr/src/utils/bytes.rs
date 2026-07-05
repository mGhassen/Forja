use regex::Regex;
use std::sync::LazyLock;

static BYTES_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)([\d.,]+)\s*([KMGTP]?B)").unwrap());

pub fn parse_bytes(input: &str) -> Option<u64> {
    let m = BYTES_RE.captures(input.trim())?;
    let num: f64 = m.get(1)?.as_str().replace(',', "").parse().ok()?;
    let unit = m.get(2)?.as_str().to_uppercase();
    let mult: f64 = match unit.as_str() {
        "B" => 1.0,
        "KB" => 1024.0,
        "MB" => 1024.0 * 1024.0,
        "GB" => 1024.0 * 1024.0 * 1024.0,
        "TB" => 1024.0 * 1024.0 * 1024.0 * 1024.0,
        "PB" => 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0,
        _ => 1.0,
    };
    Some((num * mult).round() as u64)
}
