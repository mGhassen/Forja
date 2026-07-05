use regex::Regex;
use serde::{Deserialize, Serialize};
use std::sync::LazyLock;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HlsQuality {
    pub label: String,
    pub url: String,
    pub bandwidth: Option<u64>,
    pub height: Option<u32>,
    pub is_auto: bool,
}

static RESOLUTION_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(\d+)x(\d+)").unwrap());

pub fn parse_hls_master(master_url: &str, body: &str) -> Option<Vec<HlsQuality>> {
    if !body.contains("#EXT-X-STREAM-INF") {
        return None;
    }
    let base = url::Url::parse(master_url).ok()?;

    let normalized = body
        .replace("\r\n", "\n")
        .replace('\r', "\n")
        .replace("#EXT-X-STREAM-INF", "\n#EXT-X-STREAM-INF");

    let lines: Vec<&str> = normalized.split('\n').collect();
    let mut variants = Vec::new();

    for i in 0..lines.len() {
        let line = lines[i].trim();
        if !line.starts_with("#EXT-X-STREAM-INF") {
            continue;
        }
        let mut uri_line: Option<&str> = None;
        for candidate in lines.iter().skip(i + 1) {
            let c = candidate.trim();
            if c.is_empty() || c.starts_with('#') {
                continue;
            }
            uri_line = Some(c);
            break;
        }
        let uri_line = uri_line?;
        let colon = line.find(':')?;
        let attrs = parse_attrs(&line[colon + 1..]);
        let bw = attrs
            .get("BANDWIDTH")
            .or_else(|| attrs.get("AVERAGE-BANDWIDTH"))
            .and_then(|s| s.parse().ok());
        let height = attrs.get("RESOLUTION").and_then(|res| {
            RESOLUTION_RE
                .captures(res)?
                .get(2)?
                .as_str()
                .parse()
                .ok()
        });
        let resolved = base.join(uri_line).ok()?.to_string();
        variants.push(HlsQuality {
            label: format_label(height, bw),
            url: resolved,
            bandwidth: bw,
            height,
            is_auto: false,
        });
    }

    if variants.len() < 2 {
        return None;
    }

    variants.sort_by(|a, b| {
        let ah = a.height.unwrap_or(0);
        let bh = b.height.unwrap_or(0);
        if ah != bh {
            return bh.cmp(&ah);
        }
        (b.bandwidth.unwrap_or(0)).cmp(&a.bandwidth.unwrap_or(0))
    });

    let mut out = vec![HlsQuality {
        label: "Auto".to_string(),
        url: master_url.to_string(),
        bandwidth: None,
        height: None,
        is_auto: true,
    }];
    out.extend(variants);
    Some(out)
}

fn parse_attrs(s: &str) -> std::collections::HashMap<String, String> {
    let mut out = std::collections::HashMap::new();
    let mut key: Option<String> = None;
    let mut buf = String::new();
    let mut in_quotes = false;
    for c in s.chars() {
        if c == '"' {
            in_quotes = !in_quotes;
            continue;
        }
        if c == '=' && key.is_none() && !in_quotes {
            key = Some(buf.trim().to_string());
            buf.clear();
            continue;
        }
        if c == ',' && !in_quotes {
            if let Some(k) = key.take() {
                out.insert(k, buf.trim().to_string());
            }
            buf.clear();
            continue;
        }
        buf.push(c);
    }
    if let Some(k) = key {
        out.insert(k, buf.trim().to_string());
    }
    out
}

fn format_label(height: Option<u32>, bandwidth: Option<u64>) -> String {
    if let Some(h) = height {
        return format!("{h}p");
    }
    if let Some(bw) = bandwidth {
        return format!("{} kbps", bw / 1000);
    }
    "Variant".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_master_playlist() {
        let body = r#"#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
1080p/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
720p/index.m3u8
"#;
        let q = parse_hls_master("https://example.com/master.m3u8", body).unwrap();
        assert_eq!(q.len(), 3);
        assert!(q[0].is_auto);
        assert_eq!(q[1].label, "1080p");
    }
}
