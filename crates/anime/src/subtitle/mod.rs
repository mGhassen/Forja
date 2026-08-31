mod levrx;
mod mysubs;
mod subtitlecat;
mod wyzie;

use serde::Deserialize;
use serde_json::json;

#[derive(Debug, Deserialize)]
struct SubtitleRequest {
    action: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    year: Option<i32>,
    #[serde(default)]
    season: Option<i32>,
    #[serde(default)]
    episode: Option<i32>,
    #[serde(default)]
    tmdb_id: i64,
    #[serde(default)]
    translate_base_url: String,
    #[serde(default = "default_max_results")]
    max_results: usize,
}

fn default_max_results() -> usize {
    8
}

pub fn subtitle_request_json(request_json: &str) -> String {
    let req: SubtitleRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    let entries_result = match req.action.as_str() {
        "wyzie_fetch" => wyzie::fetch(req.tmdb_id, req.season, req.episode).map(|e| json!({ "entries": e })),
        "levrx_fetch" => levrx::fetch(req.tmdb_id, req.season, req.episode).map(|e| json!({ "entries": e })),
        "subtitlecat_fetch" => {
            if req.title.trim().is_empty() {
                return json!({ "error": "title required" }).to_string();
            }
            let base = if req.translate_base_url.is_empty() {
                None
            } else {
                Some(req.translate_base_url.as_str())
            };
            subtitlecat::fetch_all(
                &req.title,
                req.year,
                req.season,
                req.episode,
                base,
                req.max_results,
            )
            .map(|e| json!({ "entries": e }))
        }
        "mysubs_fetch" => {
            if req.title.trim().is_empty() {
                return json!({ "error": "title required" }).to_string();
            }
            mysubs::fetch_all(&req.title, req.year, req.season, req.episode)
                .map(|e| json!({ "entries": e }))
        }
        other => return json!({ "error": format!("unknown action: {other}") }).to_string(),
    };

    match entries_result {
        Ok(v) => serde_json::to_string(&v).unwrap_or_else(|_| "{}".into()),
        Err(e) => json!({ "error": e }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::subtitlecat;

    #[test]
    fn subtitlecat_build_query_movie() {
        assert_eq!(
            subtitlecat::build_query("Inception", Some(2010), None, None),
            "Inception 2010"
        );
    }

    #[test]
    fn subtitlecat_build_query_show() {
        assert_eq!(
            subtitlecat::build_query("The Walking Dead", None, Some(2), Some(12)),
            "The Walking Dead S02E12"
        );
    }
}
