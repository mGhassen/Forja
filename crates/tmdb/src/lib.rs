use stremio::fetch_get;

pub const BASE_URL: &str = "https://api.themoviedb.org/3";

/// TMDB v3 API key from `TMDB_API_KEY` (repo `.env` or CI env) at compile time.
/// Empty when unset — catalog calls will fail until you configure `.env`.
pub const API_KEY: &str = match option_env!("TMDB_API_KEY") {
    Some(k) => k,
    None => "",
};

/// TMDB v4 read access token (Bearer). Optional; used by WebStreamr when set.
pub const READ_ACCESS_TOKEN: &str = match option_env!("TMDB_READ_ACCESS_TOKEN") {
    Some(t) => t,
    None => "",
};

/// `resource_path` is relative to v3 root, e.g. `movie/popular` or
/// `tv/123?append_to_response=images,external_ids`.
pub fn build_url(resource_path: &str) -> String {
    let path = resource_path.trim_start_matches('/');
    if path.contains('?') {
        format!("{BASE_URL}/{path}&api_key={API_KEY}")
    } else {
        format!("{BASE_URL}/{path}?api_key={API_KEY}")
    }
}

/// Fetches a TMDB v3 resource. On HTTP 200 returns the response body JSON string.
/// On failure returns `{"error":"..."}` (optional `"status"` for non-200).
pub fn get_json(resource_path: &str, timeout_secs: u64) -> String {
    if API_KEY.is_empty() {
        return serde_json::json!({
            "error": "TMDB_API_KEY missing — copy .env.example to .env and rebuild Rust",
        })
        .to_string();
    }
    let url = build_url(resource_path);
    match fetch_get(&url, timeout_secs) {
        Ok(resp) if resp.status == 200 => resp.body,
        Ok(resp) => serde_json::json!({
            "error": format!("TMDB HTTP {}", resp.status),
            "status": resp.status,
        })
        .to_string(),
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_url_without_query() {
        let url = build_url("movie/popular");
        assert_eq!(
            url,
            format!("https://api.themoviedb.org/3/movie/popular?api_key={API_KEY}")
        );
    }

    #[test]
    fn build_url_with_query() {
        let url = build_url("tv/42?append_to_response=images");
        assert!(url.starts_with(
            "https://api.themoviedb.org/3/tv/42?append_to_response=images&api_key="
        ));
    }

    #[test]
    fn get_json_trending() {
        if API_KEY.is_empty() {
            eprintln!("skip get_json_trending: TMDB_API_KEY not set");
            return;
        }
        let body = get_json("trending/movie/day", 15);
        assert!(!body.contains("\"error\""));
        assert!(body.contains("\"results\""));
    }
}
