use serde_json::Value;

use crate::http::{client, sleep_secs};
use crate::types::{pick_file_index, DebridFile, NamedFile};

const API: &str = "https://api.torbox.app/v1/api/torrents";

pub async fn resolve(
    api_key: &str,
    magnet: &str,
    season: Option<i32>,
    episode: Option<i32>,
) -> Result<Vec<DebridFile>, String> {
    let key = api_key.trim();
    if key.is_empty() {
        return Err("TorBox API Key not set".into());
    }
    let http = client(std::time::Duration::from_secs(90))?;
    let auth = format!("Bearer {key}");

    let create_res = http
        .post(format!("{API}/createtorrent"))
        .header("Authorization", &auth)
        .form(&[("magnet", magnet)])
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let create_data: Value = create_res.json().await.map_err(|e| e.to_string())?;
    if create_data.get("success") == Some(&Value::Bool(false)) {
        return Err(format!(
            "TorBox failed: {}",
            create_data
                .get("detail")
                .and_then(|v| v.as_str())
                .unwrap_or("unknown error")
        ));
    }
    let torrent_id = create_data
        .pointer("/data/torrent_id")
        .ok_or_else(|| "TorBox: no torrent id".to_string())?;

    let mut info: Value = Value::Null;
    for _ in 0..20 {
        let info_res = http
            .get(format!("{API}/mylist?id={torrent_id}&bypass_cache=true"))
            .header("Authorization", &auth)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        let body: Value = info_res.json().await.map_err(|e| e.to_string())?;
        info = body
            .get("data")
            .cloned()
            .unwrap_or(Value::Null);
        if info.get("download_finished") == Some(&Value::Bool(true))
            || info.get("download_state").and_then(|v| v.as_str()) == Some("cached")
        {
            break;
        }
        if info.get("download_state").and_then(|v| v.as_str()) == Some("error") {
            return Err("TorBox Download failed".into());
        }
        sleep_secs(3).await;
    }

    let raw_files = info
        .get("files")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    if raw_files.is_empty() {
        return Err("TorBox returned no files".into());
    }

    let named: Vec<NamedFile> = raw_files
        .iter()
        .map(|f| NamedFile {
            path: f
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            size: f.get("size").and_then(|v| v.as_u64()).unwrap_or(0),
        })
        .collect();
    let picked_idx = pick_file_index(&named, season, episode)
        .ok_or_else(|| "No video file found in torrent".to_string())?;
    let picked = &raw_files[picked_idx];
    let file_id = picked.get("id").ok_or_else(|| "TorBox: no file id".to_string())?;
    let permalink = format!(
        "https://api.torbox.app/v1/api/torrents/requestdl?token={key}&torrent_id={torrent_id}&file_id={file_id}&redirect=true"
    );

    Ok(vec![DebridFile {
        filename: picked
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("video")
            .to_string(),
        filesize: picked.get("size").and_then(|v| v.as_i64()).unwrap_or(0),
        download_url: permalink,
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
