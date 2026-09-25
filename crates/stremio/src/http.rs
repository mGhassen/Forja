use serde::Serialize;
use std::collections::HashMap;
use std::sync::LazyLock;
use std::time::Duration;

use tokio::runtime::Runtime;

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct HttpResponse {
    pub status: u16,
    pub body: String,
}

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("stremio tokio runtime"));

static CLIENT: LazyLock<reqwest::Client> = LazyLock::new(|| {
    utils::dns::client_builder()
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .expect("stremio http client")
});

pub fn fetch_get(url: &str, timeout_secs: u64) -> Result<HttpResponse, String> {
    fetch_get_with_headers(url, timeout_secs, &HashMap::new())
}

/// Stream-list GET that aborts when this job's token is cancelled.
///
/// Catalog / manifest GETs stay on [fetch_get] (shutdown only) so a playback
/// cancel does not empty Home rails. Sources chip-off uses this path.
pub fn fetch_get_job(url: &str, timeout_secs: u64) -> Result<HttpResponse, String> {
    let token = utils::engine_cancel::cancellation_token();
    if token.is_cancelled() || utils::engine_cancel::is_shutdown_requested() {
        return Err(utils::engine_cancel::cancelled_message());
    }
    let headers = HashMap::new();
    RUNTIME.block_on(async {
        tokio::select! {
            biased;
            _ = token.cancelled() => Err(utils::engine_cancel::cancelled_message()),
            res = fetch_with_headers_async(url, timeout_secs, &headers, None) => res,
        }
    })
}

/// TMDB catalog GET — aborts on [utils::engine_cancel::request_catalog]
/// (Home filter flips) or shutdown; ignores playback [request].
pub fn fetch_get_catalog(url: &str, timeout_secs: u64) -> Result<HttpResponse, String> {
    RUNTIME.block_on(async {
        utils::engine_cancel::with_catalog_cancel(async {
            fetch_with_headers_async(url, timeout_secs, &HashMap::new(), None).await
        })
        .await
    })
}

pub fn fetch_get_with_headers(
    url: &str,
    timeout_secs: u64,
    headers: &HashMap<String, String>,
) -> Result<HttpResponse, String> {
    // Catalog / manifest / stream-list GETs must not die when playback cancels
    // a torrent job — Home Cinemeta rails were silently empty because of that.
    RUNTIME.block_on(async {
        utils::engine_cancel::with_shutdown_cancel(async {
            fetch_with_headers_async(url, timeout_secs, headers, None).await
        })
        .await
    })
}

pub fn fetch_post_with_headers(
    url: &str,
    timeout_secs: u64,
    headers: &HashMap<String, String>,
    body: &str,
) -> Result<HttpResponse, String> {
    fetch_with_headers(url, timeout_secs, headers, Some(body))
}

fn fetch_with_headers(
    url: &str,
    timeout_secs: u64,
    headers: &HashMap<String, String>,
    body: Option<&str>,
) -> Result<HttpResponse, String> {
    RUNTIME.block_on(async {
        utils::engine_cancel::with_cancel(async {
            fetch_with_headers_async(url, timeout_secs, headers, body).await
        })
        .await
    })
}

/// Catalog/metadata HTTP — ignores playback [engine_cancel::request],
/// but aborts on [engine_cancel::request_shutdown] so worker isolates can exit.
pub fn fetch_post_with_headers_unchecked(
    url: &str,
    timeout_secs: u64,
    headers: &HashMap<String, String>,
    body: &str,
) -> Result<HttpResponse, String> {
    RUNTIME.block_on(async {
        utils::engine_cancel::with_shutdown_cancel(async {
            fetch_with_headers_async(url, timeout_secs, headers, Some(body)).await
        })
        .await
    })
}

async fn fetch_with_headers_async(
    url: &str,
    timeout_secs: u64,
    headers: &HashMap<String, String>,
    body: Option<&str>,
) -> Result<HttpResponse, String> {
    let url = url.trim();
    if url.is_empty() || !url.starts_with("http") {
        return Err("Invalid URL".into());
    }
    let timeout = Duration::from_secs(timeout_secs.max(1));
    let client = CLIENT.clone();
    let mut req = if let Some(body) = body {
        client.post(url).body(body.to_string())
    } else {
        client.get(url)
    };
    req = req.timeout(timeout);
    for (k, v) in headers {
        req = req.header(k.as_str(), v.as_str());
    }
    let resp = req.send().await.map_err(|e| e.to_string())?;
    let status = resp.status().as_u16();
    let body = resp.text().await.map_err(|e| e.to_string())?;
    Ok(HttpResponse { status, body })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_url() {
        assert!(fetch_get("", 5).is_err());
    }

    #[test]
    fn rejects_non_http_url() {
        assert!(fetch_get("ftp://example.com", 5).is_err());
    }

    #[test]
    fn job_fetch_returns_when_token_already_cancelled() {
        utils::engine_cancel::clear_job_token();
        let token = utils::engine_cancel::new_job_token();
        token.cancel();
        utils::engine_cancel::attach_job_token(token);
        let started = std::time::Instant::now();
        let err = fetch_get_job("https://example.com/stream.json", 30).unwrap_err();
        assert_eq!(err, utils::engine_cancel::cancelled_message());
        assert!(started.elapsed() < std::time::Duration::from_secs(2));
        utils::engine_cancel::clear_job_token();
    }

    #[test]
    fn fetches_torrentio_streams() {
        // Live smoke — soft-skip on transport/Cloudflare blocks (CI / residential IPs).
        let resp = match fetch_get(
            "https://torrentio.strem.fun/stream/movie/tt0114709.json",
            15,
        ) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("skip fetches_torrentio_streams: {e}");
                return;
            }
        };
        if resp.status == 403 && resp.body.contains("Cloudflare") {
            eprintln!("skip fetches_torrentio_streams: Cloudflare blocked torrentio");
            return;
        }
        assert_eq!(resp.status, 200);
        assert!(resp.body.contains("\"streams\""));
    }

    #[test]
    fn post_with_headers_reuses_shared_client() {
        let headers = HashMap::from([
            ("Accept".into(), "application/json".into()),
            ("Content-Type".into(), "application/json".into()),
            (
                "User-Agent".into(),
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
                 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
                    .into(),
            ),
            ("Origin".into(), "https://anilist.co".into()),
            ("Referer".into(), "https://anilist.co/".into()),
        ]);
        let body = r#"{"query":"query { Page(page: 1, perPage: 1) { media(sort: TRENDING_DESC, type: ANIME) { id } } }"}"#;
        let resp = match fetch_post_with_headers(
            "https://graphql.anilist.co",
            15,
            &headers,
            body,
        ) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("skip post_with_headers_reuses_shared_client: {e}");
                return;
            }
        };
        if resp.status == 403 {
            eprintln!("skip post_with_headers_reuses_shared_client: AniList blocked request");
            return;
        }
        assert_eq!(resp.status, 200);
        assert!(resp.body.contains("\"data\""));
    }
}
