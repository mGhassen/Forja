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
    let timeout = Duration::from_secs(timeout_secs.clamp(1, 120));
    let rt = tokio::runtime::Runtime::new().map_err(|e| e.to_string())?;
    rt.block_on(async {
        let client = reqwest::Client::builder()
            .timeout(timeout)
            .redirect(reqwest::redirect::Policy::limited(8))
            .build()
            .map_err(|e| e.to_string())?;
        // No Range — live / Stalker CDNs often reject Range (403/416/empty)
        // while a normal GET plays fine in the player.
        let resp = client
            .get(url)
            .header("User-Agent", UA)
            .header("Accept", "*/*")
            .header("Connection", "keep-alive")
            .send()
            .await
            .map_err(|e| e.to_string())?;

        let code = resp.status().as_u16();
        if !(200..300).contains(&code) {
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

        // HLS: CT, URL suffix, or body — many Stalker links omit `.m3u8` and
        // serve `text/plain` / `application/octet-stream`.
        if looks_like_playlist(&ct, url, &buf) {
            return Ok(playlist_has_extm3u(&buf));
        }

        if is_error_page_content_type(&ct) {
            return Ok(false);
        }

        if ts_packets_ok(&buf) {
            return Ok(true);
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

        // Finite small body with no media signature → stub / error file.
        if ended && (1..=5_000_000).contains(&cl) {
            return Ok(false);
        }
        if ended && buf.len() < MIN_BYTES {
            return Ok(false);
        }
        Ok(false)
    })
}

fn looks_like_playlist(ct: &str, url: &str, buf: &[u8]) -> bool {
    ct.contains("mpegurl")
        || url.to_ascii_lowercase().contains(".m3u8")
        || playlist_has_extm3u(buf)
}

fn playlist_has_extm3u(buf: &[u8]) -> bool {
    let head_len = buf.len().min(1024);
    let head = String::from_utf8_lossy(&buf[..head_len]);
    let trimmed = head.trim_start();
    trimmed.starts_with("#EXTM3U") || trimmed.contains("#EXTM3U")
}

/// HTML / JSON / XML error pages. Not `text/plain` — playlists often use that.
fn is_error_page_content_type(ct: &str) -> bool {
    ct.contains("text/html") || ct.contains("application/json") || ct.contains("text/xml")
}

fn ts_packets_ok(buf: &[u8]) -> bool {
    if buf.is_empty() || buf[0] != 0x47 {
        return false;
    }
    let mut checked = 0usize;
    let mut i = 0usize;
    while i + 188 <= buf.len() && checked < 10 {
        if buf[i] != 0x47 {
            return false;
        }
        checked += 1;
        i += 188;
    }
    checked >= 3
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
        assert!(playlist_has_extm3u(b"#EXTM3U\n#EXTINF:1,\nseg.ts\n"));
    }

    #[test]
    fn playlist_from_text_plain_body() {
        let body = b"#EXTM3U\n#EXT-X-VERSION:3\n";
        assert!(looks_like_playlist("text/plain", "http://cdn/play/token", body));
        assert!(playlist_has_extm3u(body));
    }

    #[test]
    fn text_plain_without_playlist_not_media_ct() {
        assert!(!is_error_page_content_type("text/plain"));
        assert!(is_error_page_content_type("text/html"));
    }

    #[test]
    fn detects_ts_sync() {
        let buf = vec![0x47; 600];
        assert!(has_video_signature(&buf));
        assert!(ts_packets_ok(&buf));
    }
}
