use serde::Serialize;
use std::time::Duration;

const MIN_BYTES: usize = 16 * 1024;
const MAX_BYTES: usize = 64 * 1024;
const UA: &str = "VLC/3.0.20 LibVLC/3.0.20";

#[derive(Debug, Serialize)]
struct ProbeResult {
    alive: bool,
}

pub fn probe_stream_alive_json(url: &str, timeout_secs: u64) -> String {
    match probe_stream_alive(url, timeout_secs) {
        Ok(alive) => serde_json::to_string(&ProbeResult { alive }).unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}

pub fn probe_stream_alive(url: &str, timeout_secs: u64) -> Result<bool, String> {
    let url = url.trim();
    if url.is_empty() || !url.starts_with("http") {
        return Err("Invalid URL".into());
    }
    let timeout = Duration::from_secs(timeout_secs.max(1).min(120));
    let rt = tokio::runtime::Runtime::new().map_err(|e| e.to_string())?;
    rt.block_on(async {
        let client = reqwest::Client::builder()
            .timeout(timeout)
            .redirect(reqwest::redirect::Policy::limited(8))
            .build()
            .map_err(|e| e.to_string())?;
        let range_end = MAX_BYTES.saturating_sub(1);
        let resp = client
            .get(url)
            .header("User-Agent", UA)
            .header("Accept", "*/*")
            .header("Connection", "keep-alive")
            .header("Range", format!("bytes=0-{range_end}"))
            .send()
            .await
            .map_err(|e| e.to_string())?;

        let code = resp.status().as_u16();
        if code != 206 && !(200..300).contains(&code) {
            return Ok(false);
        }

        let ct = resp
            .headers()
            .get(reqwest::header::CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("")
            .to_ascii_lowercase();
        let cl = resp
            .headers()
            .get(reqwest::header::CONTENT_LENGTH)
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.parse::<i64>().ok())
            .unwrap_or(-1);
        if is_dead_content_type(&ct) {
            return Ok(false);
        }

        let mut buf = Vec::new();
        let mut stream = resp.bytes_stream();
        use futures_util::StreamExt;
        let mut ended = true;
        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| e.to_string())?;
            buf.extend_from_slice(&chunk);
            if buf.len() >= MAX_BYTES {
                ended = false;
                break;
            }
            if buf.len() >= MIN_BYTES {
                ended = false;
                break;
            }
        }

        let is_m3u8 = ct.contains("mpegurl") || url.to_ascii_lowercase().contains(".m3u8");
        if is_m3u8 {
            let head_len = buf.len().min(1024);
            let head = String::from_utf8_lossy(&buf[..head_len]);
            return Ok(head.contains("#EXTM3U"));
        }
        if ended && buf.len() < MIN_BYTES {
            return Ok(false);
        }
        if cl >= 1 && cl <= 5_000_000 {
            return Ok(false);
        }

        if !buf.is_empty() && buf[0] == 0x47 {
            let mut valid_ts = true;
            let mut checked_packets = 0usize;
            let mut i = 0usize;
            while i + 188 <= buf.len() && checked_packets < 10 {
                if buf[i] != 0x47 {
                    valid_ts = false;
                    break;
                }
                checked_packets += 1;
                i += 188;
            }
            if valid_ts && checked_packets >= 3 {
                return Ok(true);
            }
        }

        if buf.len() >= 8 && &buf[4..8] == b"ftyp" {
            return Ok(true);
        }
        if has_video_signature(&buf) {
            return Ok(true);
        }
        if buf.len() >= 32 * 1024 {
            return Ok(true);
        }
        Ok(false)
    })
}

fn is_dead_content_type(ct: &str) -> bool {
    ct.contains("text/html")
        || ct.contains("application/json")
        || ct.contains("text/xml")
        || ct.contains("text/plain")
}

fn has_video_signature(buf: &[u8]) -> bool {
    if buf.len() < 4 {
        return false;
    }
    if buf[0] == 0x47 {
        return true;
    }
    if buf.len() >= 7 && &buf[..7] == b"#EXTM3U" {
        return true;
    }
    if buf.len() >= 4 && &buf[..4] == b"#EXT" {
        return true;
    }
    if buf[0] == 0xFF && (buf[1] & 0xE0) == 0xE0 {
        return true;
    }
    if buf.len() >= 4
        && buf[0] == 0x1A
        && buf[1] == 0x45
        && buf[2] == 0xDF
        && buf[3] == 0xA3
    {
        return true;
    }
    if buf.len() >= 4 && buf[0] == 0x4F && buf[1] == 0x67 && buf[2] == 0x67 && buf[3] == 0x53 {
        return true;
    }
    if buf.len() >= 4 && buf[0] == 0x00 && buf[1] == 0x00 && buf[2] == 0x00 && buf[3] == 0x01 {
        return true;
    }
    if buf.len() >= 4 && buf[0] == 0x00 && buf[1] == 0x00 && buf[2] == 0x01 && buf[3] >= 0xB0 {
        return true;
    }
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_bad_url() {
        assert!(probe_stream_alive("", 5).is_err());
    }

    #[test]
    fn detects_m3u8_head() {
        assert!(has_video_signature(b"#EXTM3U\n"));
    }

    #[test]
    fn detects_ts_sync() {
        let mut buf = vec![0x47; 600];
        assert!(has_video_signature(&buf));
    }
}
