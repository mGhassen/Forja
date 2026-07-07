use serde_json::Value;

use crate::http::{client, sleep_secs};
use crate::types::{basename, pick_file_index, DebridFile, NamedFile};

const API: &str = "https://debrid-link.com/api/v2/seedbox";

struct DlFile {
    path: String,
    size: u64,
    link: String,
}

async fn decode(res: reqwest::Response) -> Result<Value, String> {
    let body: Value = res.json().await.map_err(|e| e.to_string())?;
    if body.get("success") != Some(&Value::Bool(true)) {
        return Err(format!(
            "Debrid-Link: {}",
            body.get("error")
                .and_then(|v| v.as_str())
                .unwrap_or("unknown error")
        ));
    }
    Ok(body)
}

fn extract_files(torrent: &Value) -> Vec<DlFile> {
    let mut out = Vec::new();
    let Some(files) = torrent.get("files").and_then(|v| v.as_array()) else {
        return out;
    };
    for raw in files {
        let Some(f) = raw.as_object() else { continue };
        out.push(DlFile {
            path: f
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            size: f.get("size").and_then(|v| v.as_u64()).unwrap_or(0),
            link: f
                .get("downloadUrl")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
        });
    }
    out
}

pub async fn resolve(
    api_key: &str,
    magnet: &str,
    season: Option<i32>,
    episode: Option<i32>,
) -> Result<Vec<DebridFile>, String> {
    let key = api_key.trim();
    if key.is_empty() {
        return Err("Debrid-Link API key not set".into());
    }
    let http = client(std::time::Duration::from_secs(120))?;
    let auth = format!("Bearer {key}");

    let add_res = http
        .post(format!("{API}/add"))
        .header("Authorization", &auth)
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({"url": magnet, "async": true}))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let add_body = decode(add_res).await?;
    let torrent = add_body
        .get("value")
        .ok_or_else(|| "Debrid-Link: no torrent id returned".to_string())?;
    let torrent_id = torrent
        .get("id")
        .and_then(|v| v.as_str())
        .ok_or_else(|| "Debrid-Link: no torrent id returned".to_string())?;

    let mut files = extract_files(torrent);
    let mut ready = !files.is_empty() && files.iter().all(|f| !f.link.is_empty());

    for _ in 0..40 {
        if ready {
            break;
        }
        sleep_secs(3).await;
        let st_res = http
            .get(format!("{API}/list?ids={torrent_id}"))
            .header("Authorization", &auth)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        let st_body = decode(st_res).await?;
        if let Some(list) = st_body.get("value").and_then(|v| v.as_array()) {
            if let Some(first) = list.first() {
                files = extract_files(first);
                ready = !files.is_empty() && files.iter().all(|f| !f.link.is_empty());
            }
        }
    }

    if files.is_empty() {
        return Err("Debrid-Link: no files in torrent".into());
    }
    if !ready {
        return Err("Debrid-Link: torrent not ready after 120s".into());
    }

    let named: Vec<NamedFile> = files
        .iter()
        .map(|f| NamedFile {
            path: f.path.clone(),
            size: f.size,
        })
        .collect();
    let pick_idx = pick_file_index(&named, season, episode)
        .ok_or_else(|| "Debrid-Link: no video file found in torrent".to_string())?;
    let picked = &files[pick_idx];
    if picked.link.is_empty() {
        return Err("Debrid-Link: picked file has no download link".into());
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
