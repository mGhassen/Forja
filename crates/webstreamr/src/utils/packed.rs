use utils::js_unpacker;
use regex::Regex;
use std::sync::LazyLock;

static HTTPS_PREFIX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(https:)?//").unwrap());

/// Walk [patterns] over unpacked JS and return the first capture group 1 as https URL.
pub fn extract_url_from_packed(html: &str, patterns: &[&str]) -> Option<String> {
    let unpacked = js_unpacker::unpack_eval(html).ok()?;
    extract_url_from_text(&unpacked, patterns)
}

pub fn extract_url_from_text(text: &str, patterns: &[&str]) -> Option<String> {
    for pat in patterns {
        let Ok(re) = Regex::new(pat) else {
            continue;
        };
        let Some(caps) = re.captures(text) else {
            continue;
        };
        let raw = caps.get(1)?.as_str();
        let raw = HTTPS_PREFIX.replace(raw, "");
        return Some(format!("https://{raw}"));
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_url_from_plain_sources_json() {
        let html = r#"sources: [{"file":"https://cdn.example.com/stream.m3u8"}]"#;
        let url = extract_url_from_text(html, &[r#""file"\s*:\s*"(https?:[^"]+)""#]).unwrap();
        assert_eq!(url, "https://cdn.example.com/stream.m3u8");
    }
}
