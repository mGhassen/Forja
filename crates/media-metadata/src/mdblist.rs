use serde::Deserialize;
use serde_json::{json, Value};

use crate::fetch;

const BASE_URL: &str = "https://api.mdblist.com";

#[derive(Debug, Deserialize)]
pub struct RatingsByTmdb {
    pub api_key: String,
    pub tmdb_id: i64,
    pub media_type: String,
}

#[derive(Debug, Deserialize)]
pub struct ListIdRequest {
    pub api_key: String,
    pub list_id: i64,
}

#[derive(Debug, Deserialize)]
pub struct RemoveFromListRequest {
    pub api_key: String,
    pub list_id: i64,
    #[serde(default)]
    pub imdb_id: String,
    #[serde(default)]
    pub tmdb_id: Option<i64>,
    #[serde(default)]
    pub media_type: String,
}

fn get_json(url: &str) -> Result<Value, String> {
    let (status, body) = fetch::get(url, &Default::default(), 15)?;
    if status != 200 {
        return Err(format!("mdblist HTTP {}", status));
    }
    serde_json::from_str(&body).map_err(|e| e.to_string())
}

fn post_json(url: &str, body: &str) -> Result<u16, String> {
    let mut headers = std::collections::HashMap::new();
    headers.insert("Content-Type".to_string(), "application/json".to_string());
    let (status, _body) = fetch::post(url, &headers, body, 15)?;
    Ok(status)
}

pub fn user_info(api_key: &str) -> Result<Value, String> {
    get_json(&format!("{BASE_URL}/user?apikey={}", urlencoding::encode(api_key)))
}

pub fn ratings_by_imdb(api_key: &str, imdb_id: &str) -> Result<Value, String> {
    get_json(&format!(
        "{BASE_URL}/?apikey={}&i={}",
        urlencoding::encode(api_key),
        urlencoding::encode(imdb_id)
    ))
}

pub fn ratings_by_tmdb(req: &RatingsByTmdb) -> Result<Value, String> {
    let media_type = if req.media_type == "tv" || req.media_type == "series" {
        "show"
    } else {
        "movie"
    };
    get_json(&format!(
        "{BASE_URL}/?apikey={}&tm={}&m={media_type}",
        urlencoding::encode(&req.api_key),
        req.tmdb_id
    ))
}

pub fn user_lists(api_key: &str) -> Result<Vec<Value>, String> {
    let value = get_json(&format!(
        "{BASE_URL}/lists/user?apikey={}",
        urlencoding::encode(api_key)
    ))?;
    value
        .as_array()
        .cloned()
        .ok_or_else(|| "expected list".to_string())
}

pub fn list_items(req: &ListIdRequest) -> Result<Vec<Value>, String> {
    let value = get_json(&format!(
        "{BASE_URL}/lists/{}/items?apikey={}",
        req.list_id,
        urlencoding::encode(&req.api_key)
    ))?;
    value
        .as_array()
        .cloned()
        .ok_or_else(|| "expected list".to_string())
}

pub fn top_lists(api_key: &str) -> Result<Vec<Value>, String> {
    let value = get_json(&format!(
        "{BASE_URL}/lists/top?apikey={}",
        urlencoding::encode(api_key)
    ))?;
    value
        .as_array()
        .cloned()
        .ok_or_else(|| "expected list".to_string())
}

pub fn remove_from_list(req: &RemoveFromListRequest) -> Result<bool, String> {
    if req.imdb_id.is_empty() && req.tmdb_id.is_none() {
        return Err("imdb_id or tmdb_id required".into());
    }
    let mut body = serde_json::Map::new();
    if !req.imdb_id.is_empty() {
        body.insert("imdb_id".into(), json!(req.imdb_id));
    }
    if let Some(tmdb_id) = req.tmdb_id {
        body.insert("tmdb_id".into(), json!(tmdb_id));
    }
    if !req.media_type.is_empty() {
        let media_type = if req.media_type == "tv" || req.media_type == "series" {
            "show"
        } else {
            "movie"
        };
        body.insert("mediatype".into(), json!(media_type));
    }
    let payload = serde_json::to_string(&vec![body]).map_err(|e| e.to_string())?;
    let status = post_json(
        &format!(
            "{BASE_URL}/lists/{}/items/remove?apikey={}",
            req.list_id,
            urlencoding::encode(&req.api_key)
        ),
        &payload,
    )?;
    Ok(status == 200)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn remove_requires_id() {
        let req = RemoveFromListRequest {
            api_key: "k".into(),
            list_id: 1,
            imdb_id: String::new(),
            tmdb_id: None,
            media_type: String::new(),
        };
        assert!(remove_from_list(&req).is_err());
    }
}
