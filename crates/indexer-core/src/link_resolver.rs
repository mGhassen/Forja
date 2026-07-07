use base64::Engine;
use reqwest::header::LOCATION;

use crate::http::{block_on, client_no_redirect};
use crate::types::ResolvedLink;

const MAX_REDIRECTS: u32 = 10;
const TIMEOUT_SECS: u64 = 15;

pub async fn resolve(url: &str) -> Result<ResolvedLink, String> {
    resolve_with_depth(url, 0).await
}

async fn resolve_with_depth(url: &str, depth: u32) -> Result<ResolvedLink, String> {
    if url.starts_with("magnet:") {
        return Ok(ResolvedLink {
            is_magnet: true,
            link: url.to_string(),
            torrent_base64: None,
        });
    }

    if depth >= MAX_REDIRECTS {
        return Err("Could not resolve download link — too many redirects.".into());
    }

    let http = client_no_redirect(std::time::Duration::from_secs(TIMEOUT_SECS))?;
    let response = http.get(url).send().await.map_err(|e| {
        if e.is_timeout() {
            "Download link timed out. The indexer may be down.".into()
        } else if e.is_connect() {
            format!("Cannot reach indexer — is it running? {e}")
        } else {
            "Failed to download .torrent file. Check your connection.".into()
        }
    })?;

    let status = response.status().as_u16();

    if (301..=308).contains(&status) {
        let location = response
            .headers()
            .get(LOCATION)
            .and_then(|v| v.to_str().ok())
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .ok_or_else(|| "Redirect response missing Location header".to_string())?;

        if location.starts_with("magnet:") {
            return Ok(ResolvedLink {
                is_magnet: true,
                link: location.to_string(),
                torrent_base64: None,
            });
        }

        let next = if location.starts_with("http://") || location.starts_with("https://") {
            location.to_string()
        } else {
            reqwest::Url::parse(url)
                .ok()
                .and_then(|base| base.join(location).ok())
                .map(|u| u.to_string())
                .ok_or_else(|| "Invalid redirect URL".to_string())?
        };

        return Box::pin(resolve_with_depth(&next, depth + 1)).await;
    }

    if status == 200 {
        let content_type = response
            .headers()
            .get(reqwest::header::CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("")
            .to_ascii_lowercase();
        let bytes = response.bytes().await.map_err(|e| e.to_string())?;

        if content_type.contains("application/x-bittorrent")
            || content_type.contains("application/octet-stream")
        {
            return Ok(ResolvedLink {
                is_magnet: false,
                link: String::new(),
                torrent_base64: Some(
                    base64::engine::general_purpose::STANDARD.encode(bytes),
                ),
            });
        }

        if content_type.contains("text/plain") {
            let body = String::from_utf8_lossy(&bytes).trim().to_string();
            if body.starts_with("magnet:") {
                return Ok(ResolvedLink {
                    is_magnet: true,
                    link: body,
                    torrent_base64: None,
                });
            }
        }

        if !bytes.is_empty() {
            return Ok(ResolvedLink {
                is_magnet: false,
                link: String::new(),
                torrent_base64: Some(
                    base64::engine::general_purpose::STANDARD.encode(bytes),
                ),
            });
        }

        return Err("Received empty response from server".into());
    }

    if (400..500).contains(&status) {
        return Err(format!(
            "Download link returned an error (HTTP {status}). The torrent may no longer be available."
        ));
    }

    if status >= 500 {
        return Err(format!("Server error (HTTP {status})"));
    }

    Err(format!("Unexpected HTTP status: {status}"))
}

pub fn resolve_blocking(url: &str) -> Result<ResolvedLink, String> {
    utils::engine_cancel::enter_job();
    block_on(resolve(url))
}
