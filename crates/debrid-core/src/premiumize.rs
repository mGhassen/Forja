use serde_json::Value;

use crate::http::{client, sleep_secs};
use crate::types::{basename, pick_file_index, DebridFile, NamedFile};

const API: &str = "https://www.premiumize.me/api";

struct PmFile {
    path: String,
    size: u64,
    link: String,
}

async fn walk_folder(
    http: &reqwest::Client,
    api_key: &str,
    folder_id: &str,
    prefix: &str,
    out: &mut Vec<PmFile>,
) -> Result<(), String> {
    let res = http
        .post(format!("{API}/folder/list"))
        .form(&[("apikey", api_key), ("id", folder_id)])
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let body: Value = res.json().await.map_err(|e| e.to_string())?;
    if body.get("status").and_then(|v| v.as_str()) != Some("success") {
        return Err(format!(
            "Premiumize folder/list: {}",
            body.get("message").and_then(|v| v.as_str()).unwrap_or("error")
        ));
    }
    let content = body
        .get("content")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    for raw in content {
        let Some(node) = raw.as_object() else { continue };
        let name = node.get("name").and_then(|v| v.as_str()).unwrap_or("");
        let path = if prefix.is_empty() {
            name.to_string()
        } else {
            format!("{prefix}/{name}")
        };
        if node.get("type").and_then(|v| v.as_str()) == Some("folder") {
            if let Some(id) = node.get("id").and_then(|v| v.as_str()) {
                Box::pin(walk_folder(http, api_key, id, &path, out)).await?;
            }
        } else {
            let stream = node.get("stream_link").and_then(|v| v.as_str());
            let link = if stream.is_some_and(|s| !s.is_empty()) {
                stream.unwrap().to_string()
            } else {
                node.get("link")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string()
            };
            out.push(PmFile {
                path,
                size: node.get("size").and_then(|v| v.as_u64()).unwrap_or(0),
                link,
            });
        }
    }
    Ok(())
}

pub async fn resolve(
    api_key: &str,
    magnet: &str,
    season: Option<i32>,
    episode: Option<i32>,
) -> Result<Vec<DebridFile>, String> {
    let key = api_key.trim();
    if key.is_empty() {
        return Err("Premiumize API key not set".into());
    }
    let http = client(std::time::Duration::from_secs(120))?;

    let mut files: Vec<PmFile> = Vec::new();

    if let Ok(dl_res) = http
        .post(format!("{API}/transfer/directdl"))
        .form(&[("apikey", key), ("src", magnet)])
        .send()
        .await
    {
        if let Ok(dl_body) = dl_res.json::<Value>().await {
            if dl_body.get("status").and_then(|v| v.as_str()) == Some("success") {
                let content = dl_body
                    .get("content")
                    .and_then(|v| v.as_array())
                    .cloned()
                    .unwrap_or_default();
                for raw in content {
                    let Some(node) = raw.as_object() else { continue };
                    let path = node
                        .get("path")
                        .and_then(|v| v.as_str())
                        .or_else(|| node.get("name").and_then(|v| v.as_str()))
                        .unwrap_or("")
                        .to_string();
                    let stream = node.get("stream_link").and_then(|v| v.as_str());
                    let link = if stream.is_some_and(|s| !s.is_empty()) {
                        stream.unwrap().to_string()
                    } else {
                        node.get("link")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string()
                    };
                    files.push(PmFile {
                        path,
                        size: node.get("size").and_then(|v| v.as_u64()).unwrap_or(0),
                        link,
                    });
                }
            }
        }
    }

    if files.is_empty() {
        let create_res = http
            .post(format!("{API}/transfer/create"))
            .form(&[("apikey", key), ("src", magnet)])
            .send()
            .await
            .map_err(|e| e.to_string())?;
        let create_body: Value = create_res.json().await.map_err(|e| e.to_string())?;
        if create_body.get("status").and_then(|v| v.as_str()) != Some("success") {
            return Err(format!(
                "Premiumize create: {}",
                create_body
                    .get("message")
                    .and_then(|v| v.as_str())
                    .unwrap_or("error")
            ));
        }
        let transfer_id = create_body
            .get("id")
            .and_then(|v| v.as_str())
            .ok_or_else(|| "Premiumize: no transfer id returned".to_string())?;

        let mut folder_id: Option<String> = None;
        for _ in 0..40 {
            sleep_secs(3).await;
            let list_res = http
                .post(format!("{API}/transfer/list"))
                .form(&[("apikey", key)])
                .send()
                .await
                .map_err(|e| e.to_string())?;
            let list_body: Value = list_res.json().await.map_err(|e| e.to_string())?;
            if list_body.get("status").and_then(|v| v.as_str()) != Some("success") {
                return Err(format!(
                    "Premiumize list: {}",
                    list_body
                        .get("message")
                        .and_then(|v| v.as_str())
                        .unwrap_or("error")
                ));
            }
            let transfers = list_body
                .get("transfers")
                .and_then(|v| v.as_array())
                .cloned()
                .unwrap_or_default();
            let mine = transfers
                .iter()
                .find(|t| t.get("id").and_then(|v| v.as_str()) == Some(transfer_id));
            let Some(mine) = mine else {
                return Err("Premiumize: transfer disappeared".into());
            };
            let status = mine.get("status").and_then(|v| v.as_str()).unwrap_or("");
            if status == "finished" || status == "seeding" {
                folder_id = mine
                    .get("folder_id")
                    .and_then(|v| v.as_str())
                    .map(str::to_string);
                break;
            }
            if matches!(status, "error" | "deleted" | "banned") {
                return Err(format!(
                    "Premiumize transfer failed: {status} ({})",
                    mine.get("message").and_then(|v| v.as_str()).unwrap_or("")
                ));
            }
        }
        let folder_id = folder_id.ok_or_else(|| "Premiumize: transfer did not finish in time".to_string())?;
        walk_folder(&http, key, &folder_id, "", &mut files).await?;
    }

    if files.is_empty() {
        return Err("Premiumize: no files in torrent".into());
    }

    let named: Vec<NamedFile> = files
        .iter()
        .map(|f| NamedFile {
            path: f.path.clone(),
            size: f.size,
        })
        .collect();
    let pick_idx = pick_file_index(&named, season, episode)
        .ok_or_else(|| "Premiumize: no video file found in torrent".to_string())?;
    let picked = &files[pick_idx];
    if picked.link.is_empty() {
        return Err("Premiumize: picked file has no download link".into());
    }

    Ok(vec![DebridFile {
        filename: basename(&picked.path),
        filesize: picked.size as i64,
        download_url: picked.link.clone(),
    }])
}

pub fn resolve_blocking(
    api_key: &str,
    magnet: &str,
    season: Option<i32>,
    episode: Option<i32>,
) -> Result<Vec<DebridFile>, String> {
    utils::engine_cancel::enter_job();
    crate::http::block_on(resolve(api_key, magnet, season, episode))
}
