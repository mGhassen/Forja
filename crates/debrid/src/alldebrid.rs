use serde_json::Value;

use crate::http::{client, sleep_secs};
use crate::types::{basename, pick_file_index, DebridFile, NamedFile};

const API: &str = "https://api.alldebrid.com/v4";

struct AdFile {
    path: String,
    size: u64,
    link: String,
}

async fn decode(res: reqwest::Response) -> Result<Value, String> {
    let body: Value = res.json().await.map_err(|e| e.to_string())?;
    if body.get("status").and_then(|v| v.as_str()) == Some("error") {
        let err = body.get("error");
        let code = err.and_then(|e| e.get("code")).map(|v| v.to_string()).unwrap_or_default();
        let msg = err
            .and_then(|e| e.get("message"))
            .and_then(|v| v.as_str())
            .unwrap_or("unknown error");
        return Err(format!("AllDebrid: {code} - {msg}"));
    }
    Ok(body.get("data").cloned().unwrap_or(Value::Null))
}

fn flatten_ad_files(nodes: &[Value], prefix: &str, out: &mut Vec<AdFile>) {
    for node in nodes {
        let Some(obj) = node.as_object() else { continue };
        let name = obj.get("n").and_then(|v| v.as_str()).unwrap_or("");
        if let Some(children) = obj.get("e").and_then(|v| v.as_array()) {
            let next = if prefix.is_empty() {
                name.to_string()
            } else {
                format!("{prefix}/{name}")
            };
            flatten_ad_files(children, &next, out);
        } else {
            out.push(AdFile {
                path: if prefix.is_empty() {
                    name.to_string()
                } else {
                    format!("{prefix}/{name}")
                },
                size: obj.get("s").and_then(|v| v.as_u64()).unwrap_or(0),
                link: obj.get("l").and_then(|v| v.as_str()).unwrap_or("").to_string(),
            });
        }
    }
}

pub async fn resolve(
    api_key: &str,
    magnet: &str,
    season: Option<i32>,
    episode: Option<i32>,
) -> Result<Vec<DebridFile>, String> {
    let key = api_key.trim();
    if key.is_empty() {
        return Err("AllDebrid API key not set".into());
    }
    let http = client(std::time::Duration::from_secs(120))?;
    let auth = format!("Bearer {key}");

    let up_res = http
        .post(format!("{API}/magnet/upload"))
        .header("Authorization", &auth)
        .form(&[("magnets[]", magnet)])
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let up_data = decode(up_res).await?;
    let magnets = up_data
        .get("magnets")
        .and_then(|v| v.as_array())
        .ok_or_else(|| "AllDebrid: empty magnet upload response".to_string())?;
    let first = magnets
        .first()
        .and_then(|v| v.as_object())
        .ok_or_else(|| "AllDebrid: empty magnet upload response".to_string())?;
    if first.get("error").is_some() {
        let e = first.get("error").unwrap();
        return Err(format!(
            "AllDebrid: {} - {}",
            e.get("code").map(|v| v.to_string()).unwrap_or_default(),
            e.get("message").and_then(|v| v.as_str()).unwrap_or("error")
        ));
    }
    let magnet_id = first
        .get("id")
        .ok_or_else(|| "AllDebrid: no magnet id returned".to_string())?;

    for _ in 0..40 {
        let st_res = http
            .post("https://api.alldebrid.com/v4.1/magnet/status")
            .header("Authorization", &auth)
            .form(&[("id", magnet_id.to_string().as_str())])
            .send()
            .await
            .map_err(|e| e.to_string())?;
        let st_data = decode(st_res).await?;
        let mags = st_data.get("magnets");
        let mag_obj = if let Some(arr) = mags.and_then(|v| v.as_array()) {
            arr.first()
        } else {
            mags
        };
        let code = mag_obj
            .and_then(|v| v.get("statusCode"))
            .and_then(|v| v.as_i64())
            .unwrap_or(-1);
        if code == 4 {
            break;
        }
        if code >= 5 {
            let status = mag_obj
                .and_then(|v| v.get("status"))
                .and_then(|v| v.as_str())
                .unwrap_or("error");
            return Err(format!("AllDebrid magnet failed: {status} (code {code})"));
        }
        sleep_secs(3).await;
    }

    let files_res = http
        .post(format!("{API}/magnet/files"))
        .header("Authorization", &auth)
        .form(&[("id[]", magnet_id.to_string().as_str())])
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let files_data = decode(files_res).await?;
    let files_magnets = files_data
        .get("magnets")
        .and_then(|v| v.as_array())
        .ok_or_else(|| "AllDebrid: empty files response".to_string())?;
    let files_obj = files_magnets
        .first()
        .and_then(|v| v.as_object())
        .ok_or_else(|| "AllDebrid: empty files response".to_string())?;
    if files_obj.get("error").is_some() {
        let e = files_obj.get("error").unwrap();
        return Err(format!(
            "AllDebrid files: {} - {}",
            e.get("code").map(|v| v.to_string()).unwrap_or_default(),
            e.get("message").and_then(|v| v.as_str()).unwrap_or("error")
        ));
    }
    let tree = files_obj
        .get("files")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    let mut flat: Vec<AdFile> = Vec::new();
    flatten_ad_files(&tree, "", &mut flat);
    if flat.is_empty() {
        return Err("AllDebrid: no files in magnet".into());
    }

    let named: Vec<NamedFile> = flat
        .iter()
        .map(|f| NamedFile {
            path: f.path.clone(),
            size: f.size,
        })
        .collect();
    let pick_idx = pick_file_index(&named, season, episode)
        .ok_or_else(|| "AllDebrid: no video file found in torrent".to_string())?;
    let picked = &flat[pick_idx];
    if picked.link.is_empty() {
        return Err("AllDebrid: picked file has no unlock link".into());
    }

    let un_res = http
        .post(format!("{API}/link/unlock"))
        .header("Authorization", &auth)
        .form(&[("link", picked.link.as_str())])
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let un_data = decode(un_res).await?;
    if un_data.get("delayed").is_some() {
        return Err("AllDebrid returned a delayed link (not supported)".into());
    }
    let dl_link = un_data
        .get("link")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "AllDebrid unlock returned no link".to_string())?;

    Ok(vec![DebridFile {
        filename: un_data
            .get("filename")
            .and_then(|v| v.as_str())
            .map(str::to_string)
            .unwrap_or_else(|| basename(&picked.path)),
        filesize: un_data
            .get("filesize")
            .and_then(|v| v.as_i64())
            .unwrap_or(picked.size as i64),
        download_url: dl_link.to_string(),
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
