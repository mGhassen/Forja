use serde_json::Value;

use crate::http::{block_on, client};
use crate::types::{format_size, normalize_base_url, ConnectionTest, ProwlarrTag, TorrentRow};

const SEARCH_TIMEOUT_SECS: u64 = 30;
const SHORT_TIMEOUT_SECS: u64 = 10;
const CATEGORIES: [i32; 2] = [2000, 5000];

pub async fn search(
    base_url: &str,
    api_key: &str,
    query: &str,
    indexer_ids: Option<&[i32]>,
) -> Result<Vec<TorrentRow>, String> {
    let normalized = normalize_base_url(base_url);
    let mut parts = vec![
        format!("query={}", urlencoding::encode(query)),
        "type=search".into(),
    ];

    if let Some(ids) = indexer_ids {
        if !ids.is_empty() {
            for id in ids {
                parts.push(format!("indexerIds={id}"));
            }
        } else {
            parts.push("indexerIds=-2".into());
        }
    } else {
        parts.push("indexerIds=-2".into());
    }

    for cat in CATEGORIES {
        parts.push(format!("categories={cat}"));
    }

    let url = format!("{normalized}/api/v1/search?{}", parts.join("&"));
    let http = client(std::time::Duration::from_secs(SEARCH_TIMEOUT_SECS))?;
    let response = http
        .get(&url)
        .header("X-Api-Key", api_key)
        .send()
        .await
        .map_err(map_client_error)?;

    let status = response.status().as_u16();
    let body = response.text().await.map_err(|e| e.to_string())?;

    if status == 401 {
        return Err("❌ Wrong API key (401). Check your API key in Settings.".into());
    }
    if status == 400 {
        if body.contains("all selected indexers being unavailable") {
            return Err(
                "❌ No torrent indexers available in Prowlarr. Go to Prowlarr → Indexers and ensure at least one torrent indexer is configured and tested successfully.".into(),
            );
        }
        return Err(format!("❌ Bad request (400). Response: {body}"));
    }
    if status == 403 {
        return Err("❌ Access denied (403). Check your Prowlarr API key and server configuration.".into());
    }
    if status == 500 {
        return Err("❌ Prowlarr server error (500). Check the Prowlarr logs.".into());
    }
    if status != 200 {
        return Err(format!("❌ Prowlarr returned HTTP {status}"));
    }

    parse_json_results(&body)
}

pub async fn test_connection(base_url: &str, api_key: &str) -> ConnectionTest {
    let normalized = normalize_base_url(base_url);
    let url = format!("{normalized}/api/v1/system/status");

    let http = match client(std::time::Duration::from_secs(SHORT_TIMEOUT_SECS)) {
        Ok(c) => c,
        Err(e) => {
            return ConnectionTest {
                success: false,
                message: format!("❌ Error: {e}"),
                indexer_count: None,
                version: None,
            };
        }
    };

    let response = match http
        .get(&url)
        .header("X-Api-Key", api_key)
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            return ConnectionTest {
                success: false,
                message: map_client_error(e),
                indexer_count: None,
                version: None,
            };
        }
    };

    let status = response.status().as_u16();
    let body = response.text().await.unwrap_or_default();

    if status == 401 {
        return ConnectionTest {
            success: false,
            message: "❌ Wrong API key (401)".into(),
            indexer_count: None,
            version: None,
        };
    }

    if status == 200 {
        if let Ok(data) = serde_json::from_str::<Value>(&body) {
            let version = data.get("version").and_then(|v| v.as_str()).map(str::to_string);
            return ConnectionTest {
                success: true,
                message: version
                    .as_ref()
                    .map(|v| format!("✅ Connected — Prowlarr v{v}"))
                    .unwrap_or_else(|| "✅ Connected".into()),
                indexer_count: None,
                version,
            };
        }
        return ConnectionTest {
            success: true,
            message: "✅ Connected".into(),
            indexer_count: None,
            version: None,
        };
    }

    ConnectionTest {
        success: false,
        message: format!("❌ HTTP {status}"),
        indexer_count: None,
        version: None,
    }
}

pub async fn fetch_tags(base_url: &str, api_key: &str) -> Result<Vec<ProwlarrTag>, String> {
    let normalized = normalize_base_url(base_url);
    let url = format!("{normalized}/api/v1/tag");
    let http = client(std::time::Duration::from_secs(SHORT_TIMEOUT_SECS))?;
    let response = http
        .get(&url)
        .header("X-Api-Key", api_key)
        .send()
        .await
        .map_err(map_client_error)?;

    let status = response.status().as_u16();
    let body = response.text().await.map_err(|e| e.to_string())?;
    if status != 200 {
        return Err(format!("Failed to fetch Prowlarr tags (HTTP {status})"));
    }

    let data: Vec<Value> = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    Ok(data
        .into_iter()
        .filter_map(|item| {
            let id = item.get("id")?.as_i64()?;
            let label = item.get("label")?.as_str()?.to_string();
            Some(ProwlarrTag { id, label })
        })
        .collect())
}

pub async fn resolve_tag_indexer_ids(
    base_url: &str,
    api_key: &str,
    tag_ids: &[i32],
) -> Result<Vec<i32>, String> {
    if tag_ids.is_empty() {
        return Ok(vec![]);
    }
    let normalized = normalize_base_url(base_url);
    let url = format!("{normalized}/api/v1/indexer");
    let http = client(std::time::Duration::from_secs(SHORT_TIMEOUT_SECS))?;
    let response = http
        .get(&url)
        .header("X-Api-Key", api_key)
        .send()
        .await
        .map_err(map_client_error)?;

    let status = response.status().as_u16();
    let body = response.text().await.map_err(|e| e.to_string())?;
    if status != 200 {
        return Err(format!("Failed to fetch Prowlarr indexers (HTTP {status})"));
    }

    let data: Vec<Value> = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    let tag_set: std::collections::HashSet<i32> = tag_ids.iter().copied().collect();
    let mut result = Vec::new();

    for item in data {
        if item.get("protocol").and_then(|v| v.as_str()) == Some("usenet") {
            continue;
        }
        let tags: Vec<i32> = item
            .get("tags")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|t| t.as_i64().map(|n| n as i32))
                    .collect()
            })
            .unwrap_or_default();
        if tags.iter().any(|t| tag_set.contains(t)) {
            if let Some(id) = item.get("id").and_then(|v| v.as_i64()) {
                result.push(id as i32);
            }
        }
    }

    Ok(result)
}

pub fn search_blocking(
    base_url: &str,
    api_key: &str,
    query: &str,
    indexer_ids: Option<&[i32]>,
) -> Result<Vec<TorrentRow>, String> {
    utils::engine_cancel::enter_job();
    block_on(search(base_url, api_key, query, indexer_ids))
}

pub fn test_connection_blocking(base_url: &str, api_key: &str) -> ConnectionTest {
    utils::engine_cancel::enter_job();
    block_on(test_connection(base_url, api_key))
}

pub fn fetch_tags_blocking(base_url: &str, api_key: &str) -> Result<Vec<ProwlarrTag>, String> {
    utils::engine_cancel::enter_job();
    block_on(fetch_tags(base_url, api_key))
}

pub fn resolve_tag_indexer_ids_blocking(
    base_url: &str,
    api_key: &str,
    tag_ids: &[i32],
) -> Result<Vec<i32>, String> {
    utils::engine_cancel::enter_job();
    block_on(resolve_tag_indexer_ids(base_url, api_key, tag_ids))
}

fn map_client_error(e: reqwest::Error) -> String {
    if e.is_timeout() {
        "⚠️ Prowlarr timed out. It may be overloaded or the URL is wrong.".into()
    } else if e.is_connect() {
        "⚠️ Cannot connect to Prowlarr. Is it running? Check your Base URL in Settings.".into()
    } else {
        format!("⚠️ Unexpected error: {e}")
    }
}

fn parse_json_results(json_body: &str) -> Result<Vec<TorrentRow>, String> {
    let data: Vec<Value> =
        serde_json::from_str(json_body).map_err(|_| "⚠️ Unexpected response from Prowlarr. The server may be misconfigured.".to_string())?;

    let mut results = Vec::new();

    for item in data {
        if item.get("protocol").and_then(|v| v.as_str()) == Some("usenet") {
            continue;
        }
        let title = item
            .get("title")
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown")
            .to_string();
        let size = item.get("size").and_then(|v| v.as_i64()).unwrap_or(0);
        let seeders = item
            .get("seeders")
            .map(|v| {
                v.as_i64()
                    .map(|n| n.to_string())
                    .or_else(|| v.as_str().map(str::to_string))
            })
            .flatten()
            .unwrap_or_else(|| "?".into());
        let indexer = item
            .get("indexer")
            .and_then(|v| v.as_str())
            .unwrap_or("Prowlarr")
            .to_string();

        let mut download_link = item
            .get("magnetUrl")
            .and_then(|v| v.as_str())
            .filter(|s| s.starts_with("magnet:"))
            .map(str::to_string);

        if download_link.is_none() {
            download_link = item
                .get("downloadUrl")
                .and_then(|v| v.as_str())
                .filter(|s| !s.is_empty())
                .map(str::to_string);
        }

        if download_link.is_none() {
            if let Some(hash) = item.get("infoHash").and_then(|v| v.as_str()) {
                if !hash.is_empty() {
                    download_link = Some(format!(
                        "magnet:?xt=urn:btih:{hash}&dn={}",
                        urlencoding::encode(&title)
                    ));
                }
            }
        }

        if let Some(link) = download_link {
            if !link.is_empty() {
                results.push(TorrentRow {
                    name: title,
                    magnet: link,
                    seeders,
                    size: format_size(size),
                    source: indexer,
                });
            }
        }
    }

    results.sort_by(|a, b| {
        let a_seeds = a.seeders.parse::<i32>().ok();
        let b_seeds = b.seeders.parse::<i32>().ok();
        match (a_seeds, b_seeds) {
            (None, None) => std::cmp::Ordering::Equal,
            (None, Some(_)) => std::cmp::Ordering::Greater,
            (Some(_), None) => std::cmp::Ordering::Less,
            (Some(a), Some(b)) => b.cmp(&a),
        }
    });

    Ok(results)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_prowlarr_json_result() {
        let json = r#"[{
            "title": "Movie 1080p",
            "size": 2147483648,
            "seeders": 10,
            "indexer": "RARBG",
            "protocol": "torrent",
            "magnetUrl": "magnet:?xt=urn:btih:deadbeef"
        }]"#;
        let rows = parse_json_results(json).unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].source, "RARBG");
        assert_eq!(rows[0].seeders, "10");
    }
}
