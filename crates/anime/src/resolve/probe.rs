use std::collections::HashMap;

use crate::http;

pub fn probe_stream_url(url: &str, headers: &HashMap<String, String>) -> bool {
    let url = url.trim();
    if url.is_empty() {
        return false;
    }

    if url.contains(".m3u8") {
        if let Ok(resp) = http::fetch_with_retries("GET", url, headers, None, None, false, 8, 0) {
            return resp.status == 200 && resp.body.contains("#EXTM3U");
        }
        return false;
    }

    if let Ok(resp) = http::fetch_with_retries("HEAD", url, headers, None, None, false, 8, 0) {
        if (200..400).contains(&resp.status) {
            return true;
        }
    }

    let mut get_headers = headers.clone();
    get_headers.insert("Range".into(), "bytes=0-0".into());
    if let Ok(resp) = http::fetch_with_retries("GET", url, &get_headers, None, None, false, 8, 0) {
        return resp.status == 200 || resp.status == 206;
    }

    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_url_not_reachable() {
        assert!(!probe_stream_url("", &HashMap::new()));
    }
}
