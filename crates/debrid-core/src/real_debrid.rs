use serde_json::Value;

use crate::http::{client, sleep_secs};
use crate::types::{basename, pick_file_index, DebridFile, NamedFile};

const API: &str = "https://api.real-debrid.com/rest/1.0";

pub async fn verify_api_key(api_key: &str) -> Result<Value, String> {
    let key = api_key.trim();
    if key.is_empty() {
        return Err("empty api key".into());
    }
    let http = client(std::time::Duration::from_secs(15))?;
    let res = http
        .get(format!("{API}/user"))
        .header("Authorization", format!("Bearer {key}"))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if res.status().as_u16() == 200 {
        res.json::<Value>().await.map_err(|e| e.to_string())
    } else {
        Err("invalid api key".into())
    }
}

pub async fn resolve(
    api_key: &str,
    magnet: &str,
    season: Option<i32>,
    episode: Option<i32>,
) -> Result<Vec<DebridFile>, String> {
    let token = api_key.trim();
    if token.is_empty() {
        return Err("Real-Debrid not logged in".into());
    }
    let http = client(std::time::Duration::from_secs(60))?;
    let auth = format!("Bearer {token}");

    let add_res = http
        .post(format!("{API}/torrents/addMagnet"))
        .header("Authorization", &auth)
        .form(&[("magnet", magnet)])
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if add_res.status().as_u16() != 201 {
        let body = add_res.text().await.unwrap_or_default();
        return Err(format!("Failed to add magnet to RD: {body}"));
    }
    let add_json: Value = add_res.json().await.map_err(|e| e.to_string())?;
    let torrent_id = add_json
        .get("id")
        .and_then(|v| v.as_str())
        .ok_or_else(|| "RD: no torrent id".to_string())?;

    let mut info: Value = Value::Null;
    let mut rd_files: Vec<Value> = Vec::new();
    for _ in 0..20 {
        let info_res = http
            .get(format!("{API}/torrents/info/{torrent_id}"))
            .header("Authorization", &auth)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        info = info_res.json().await.map_err(|e| e.to_string())?;
        let status = info.get("status").and_then(|v| v.as_str()).unwrap_or("");
        if matches!(status, "magnet_error" | "error" | "dead" | "virus") {
            return Err(format!("RD rejected magnet (status: {status})"));
        }
        rd_files = info
            .get("files")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        if !rd_files.is_empty() {
            break;
        }
        sleep_secs(2).await;
    }
    if rd_files.is_empty() {
        return Err("RD never returned a file list".into());
    }

    let named: Vec<NamedFile> = rd_files
        .iter()
        .map(|f| NamedFile {
            path: f
                .get("path")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            size: f.get("bytes").and_then(|v| v.as_u64()).unwrap_or(0),
        })
        .collect();
    let picked_idx = pick_file_index(&named, season, episode)
        .ok_or_else(|| "No video file found in torrent".to_string())?;
    let picked = &rd_files[picked_idx];
    let picked_id = picked
        .get("id")
        .map(|v| v.to_string().trim_matches('"').to_string())
        .unwrap_or_default();
    let picked_path = picked
        .get("path")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    let picked_size = picked.get("bytes").and_then(|v| v.as_i64()).unwrap_or(0);

    let sel_res = http
        .post(format!("{API}/torrents/selectFiles/{torrent_id}"))
        .header("Authorization", &auth)
        .form(&[("files", picked_id.as_str())])
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let sel_status = sel_res.status().as_u16();
    if sel_status != 204 && sel_status != 202 {
        let _ = http
            .post(format!("{API}/torrents/selectFiles/{torrent_id}"))
            .header("Authorization", &auth)
            .form(&[("files", "all")])
            .send()
            .await;
    }

    for _ in 0..40 {
        let info_res = http
            .get(format!("{API}/torrents/info/{torrent_id}"))
            .header("Authorization", &auth)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        info = info_res.json().await.map_err(|e| e.to_string())?;
        let status = info.get("status").and_then(|v| v.as_str()).unwrap_or("");
        if status == "downloaded" {
            break;
        }
        if matches!(status, "error" | "dead" | "virus") {
            return Err(format!("RD download failed (status: {status})"));
        }
        sleep_secs(3).await;
    }
    if info.get("status").and_then(|v| v.as_str()) != Some("downloaded") {
        return Err("RD download timed out".into());
    }

    let links: Vec<String> = info
        .get("links")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default();
    if links.is_empty() {
        return Err("RD returned no links".into());
    }

    let target_link = if links.len() == 1 {
        links[0].clone()
    } else {
        let selected: Vec<&Value> = info
            .get("files")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter(|f| f.get("selected").and_then(|v| v.as_i64()) == Some(1))
                    .collect()
            })
            .unwrap_or_default();
        let idx = selected
            .iter()
            .position(|f| f.get("id").map(|v| v.to_string()) == Some(picked_id.clone()));
        idx.and_then(|i| links.get(i).cloned())
            .unwrap_or_else(|| links[0].clone())
    };

    let un_res = http
        .post(format!("{API}/unrestrict/link"))
        .header("Authorization", &auth)
        .form(&[("link", target_link.as_str())])
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if un_res.status().as_u16() != 200 {
        let body = un_res.text().await.unwrap_or_default();
        return Err(format!("RD unrestrict failed: {body}"));
    }
    let data: Value = un_res.json().await.map_err(|e| e.to_string())?;
    Ok(vec![DebridFile {
        filename: data
            .get("filename")
            .and_then(|v| v.as_str())
            .map(str::to_string)
            .unwrap_or_else(|| basename(picked_path)),
        filesize: data
            .get("filesize")
            .and_then(|v| v.as_i64())
            .unwrap_or(picked_size),
        download_url: data
            .get("download")
            .and_then(|v| v.as_str())
            .ok_or_else(|| "RD unrestrict returned no download url".to_string())?
            .to_string(),
    }])
}

pub fn verify_blocking(api_key: &str) -> Result<Value, String> {
    utils::engine_cancel::enter_job();
    crate::http::block_on(verify_api_key(api_key))
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
