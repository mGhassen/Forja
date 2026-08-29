use stremio::fetch_get_catalog;

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
    match fetch_get_catalog(&url, timeout_secs) {
        Ok(resp) if resp.status == 200 => resp.body,
        Ok(resp) => serde_json::json!({
            "error": format!("TMDB HTTP {}", resp.status),
            "status": resp.status,
        })
        .to_string(),
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}

const IMAGE_BASE: &str = "https://image.tmdb.org/t/p";

/// Catalog hub enrich — match a title (+ optional year) to a TMDB movie/tv.
///
/// Request JSON: `{ "title": "...", "year": 2024, "type": "tv"|"movie"|"" }`.
/// Response JSON: hit object or `null`. Hit shape:
/// `{ "id", "mediaType", "name", "year", "poster", "backdrop" }`.
pub fn match_json(request_json: &str) -> String {
    let Ok(req) = serde_json::from_str::<serde_json::Value>(request_json) else {
        return "null".into();
    };
    let title = req
        .get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .trim();
    if title.is_empty() {
        return "null".into();
    }
    let year = req
        .get("year")
        .and_then(|v| v.as_i64())
        .or_else(|| {
            req.get("year")
                .and_then(|v| v.as_str())
                .and_then(|s| s.parse().ok())
        });
    let prefer = req
        .get("type")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .trim()
        .to_ascii_lowercase();

    let encoded = urlencoding_lite(title);
    let primary = if prefer == "movie" { "movie" } else { "tv" };
    let secondary = if primary == "movie" { "tv" } else { "movie" };

    let mut hit = search_pick(primary, &encoded, year);
    if hit.is_none() {
        hit = search_pick(secondary, &encoded, year);
    }
    match hit {
        Some(v) => v.to_string(),
        None => "null".into(),
    }
}

fn search_pick(media: &str, encoded_title: &str, year: Option<i64>) -> Option<serde_json::Value> {
    let path = format!("search/{media}?query={encoded_title}&include_adult=false");
    let body = get_json(&path, 12);
    let Ok(json) = serde_json::from_str::<serde_json::Value>(&body) else {
        return None;
    };
    if json.get("error").is_some() {
        return None;
    }
    let results = json.get("results")?.as_array()?;
    pick_result(results, media, year)
}

fn pick_result(
    results: &[serde_json::Value],
    media: &str,
    year: Option<i64>,
) -> Option<serde_json::Value> {
    let year_of = |m: &serde_json::Value| -> Option<i64> {
        let date = m
            .get(if media == "movie" {
                "release_date"
            } else {
                "first_air_date"
            })
            .and_then(|v| v.as_str())
            .unwrap_or("");
        if date.len() >= 4 {
            date[..4].parse().ok()
        } else {
            None
        }
    };
    fn with_backdrop<'a>(list: &[&'a serde_json::Value]) -> Option<&'a serde_json::Value> {
        for m in list {
            let path = m.get("backdrop_path").and_then(|v| v.as_str()).unwrap_or("");
            if !path.is_empty() && path != "null" {
                return Some(*m);
            }
        }
        list.first().copied()
    }

    let candidates: Vec<&serde_json::Value> = results.iter().collect();
    let chosen = if let Some(y) = year {
        let exact: Vec<_> = candidates
            .iter()
            .copied()
            .filter(|m| year_of(m) == Some(y))
            .collect();
        with_backdrop(&exact)
            .or_else(|| {
                let near: Vec<_> = candidates
                    .iter()
                    .copied()
                    .filter(|m| year_of(m).is_some_and(|yy| (yy - y).abs() <= 1))
                    .collect();
                with_backdrop(&near)
            })
            .or_else(|| with_backdrop(&candidates))
    } else {
        with_backdrop(&candidates)
    }?;

    let id = chosen.get("id")?.as_i64()?;
    let name = chosen
        .get(if media == "movie" { "title" } else { "name" })
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let poster_path = chosen
        .get("poster_path")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    let backdrop_path = chosen
        .get("backdrop_path")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    let y = year_of(chosen);

    Some(serde_json::json!({
        "id": id,
        "mediaType": media,
        "name": name,
        "year": y,
        "poster": if poster_path.is_empty() {
            serde_json::Value::Null
        } else {
            serde_json::Value::String(format!("{IMAGE_BASE}/w500{poster_path}"))
        },
        "backdrop": if backdrop_path.is_empty() {
            serde_json::Value::Null
        } else {
            serde_json::Value::String(format!("{IMAGE_BASE}/w1280{backdrop_path}"))
        },
    }))
}

/// Minimal query encode — enough for TMDB search titles.
fn urlencoding_lite(s: &str) -> String {
    let mut out = String::with_capacity(s.len() * 3);
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char);
            }
            b' ' => out.push_str("%20"),
            _ => {
                out.push('%');
                out.push_str(&format!("{b:02X}"));
            }
        }
    }
    out
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

    #[test]
    fn match_json_empty_title_is_null() {
        assert_eq!(match_json(r#"{"title":""}"#), "null");
        assert_eq!(match_json("{}"), "null");
    }

    #[test]
    fn match_json_live() {
        if API_KEY.is_empty() {
            eprintln!("skip match_json_live: TMDB_API_KEY not set");
            return;
        }
        let raw = match_json(r#"{"title":"One Piece","year":1999,"type":"tv"}"#);
        assert_ne!(raw, "null");
        let v: serde_json::Value = serde_json::from_str(&raw).unwrap();
        assert!(v.get("id").and_then(|x| x.as_i64()).unwrap_or(0) > 0);
        assert_eq!(v.get("mediaType").and_then(|x| x.as_str()), Some("tv"));
    }
}
