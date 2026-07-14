mod alldebrid;
mod debrid_link;
mod http;
mod premiumize;
mod real_debrid;
mod torbox;
mod types;

use serde::Deserialize;
use serde_json::json;

pub use types::{basename, pick_file_index, DebridFile, NamedFile};

#[derive(Debug, Deserialize)]
struct DebridRequest {
    action: String,
    #[serde(default)]
    service: String,
    #[serde(default)]
    api_key: String,
    #[serde(default)]
    magnet: String,
    #[serde(default)]
    season: Option<i32>,
    #[serde(default)]
    episode: Option<i32>,
}

pub fn request_json(request_json: &str) -> String {
    let req: DebridRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    match req.action.as_str() {
        "verify_rd" => match real_debrid::verify_blocking(&req.api_key) {
            Ok(user) => serde_json::to_string(&json!({ "user": user }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "resolve" => {
            let result = match req.service.as_str() {
                "Real-Debrid" => real_debrid::resolve_blocking(
                    &req.api_key,
                    &req.magnet,
                    req.season,
                    req.episode,
                ),
                "TorBox" => torbox::resolve_blocking(
                    &req.api_key,
                    &req.magnet,
                    req.season,
                    req.episode,
                ),
                "AllDebrid" => alldebrid::resolve_blocking(
                    &req.api_key,
                    &req.magnet,
                    req.season,
                    req.episode,
                ),
                "Premiumize" => premiumize::resolve_blocking(
                    &req.api_key,
                    &req.magnet,
                    req.season,
                    req.episode,
                ),
                "Debrid-Link" => debrid_link::resolve_blocking(
                    &req.api_key,
                    &req.magnet,
                    req.season,
                    req.episode,
                ),
                other => Err(format!("Unknown debrid service: {other}")),
            };
            match result {
                Ok(files) => serde_json::to_string(&json!({ "files": files }))
                    .unwrap_or_else(|_| "{}".into()),
                Err(e) => json!({ "error": e }).to_string(),
            }
        }
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unknown_action() {
        let raw = request_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }
}
