//! Process-wide provider runtime overlay (RFC-039).
//!
//! Dart fetches Supabase JSON, merges builtins, then pushes here via FFI so
//! `stream::build_*_url` and anime extractors can retarget hosts without a rebuild.

use std::sync::RwLock;

use serde_json::Value;

static OVERLAY: RwLock<Option<Value>> = RwLock::new(None);

pub fn set_overlay_json(json: &str) -> Result<(), String> {
    let v: Value = serde_json::from_str(json).map_err(|e| e.to_string())?;
    let schema = v.get("schema").and_then(|s| s.as_i64()).unwrap_or(0);
    if schema != 1 {
        return Err(format!("unsupported provider runtime schema {schema}"));
    }
    let mut g = OVERLAY.write().map_err(|e| e.to_string())?;
    *g = Some(v);
    Ok(())
}

pub fn clear_overlay() {
    if let Ok(mut g) = OVERLAY.write() {
        *g = None;
    }
}

fn with_overlay<T>(f: impl FnOnce(&Value) -> T) -> Option<T> {
    let g = OVERLAY.read().ok()?;
    let v = g.as_ref()?;
    Some(f(v))
}

/// Expand `{tmdb}` / `{season}` / `{episode}` in a template string.
pub fn expand_template(tpl: &str, tmdb: i64, season: i32, episode: i32) -> String {
    tpl.replace("{tmdb}", &tmdb.to_string())
        .replace("{season}", &season.to_string())
        .replace("{episode}", &episode.to_string())
}

pub fn movie_template(provider_id: &str) -> Option<String> {
    with_overlay(|v| {
        v.pointer(&format!("/templates/{provider_id}/movie"))
            .and_then(|x| x.as_str())
            .map(|s| s.to_string())
    })
    .flatten()
}

pub fn tv_template(provider_id: &str) -> Option<String> {
    with_overlay(|v| {
        v.pointer(&format!("/templates/{provider_id}/tv"))
            .and_then(|x| x.as_str())
            .map(|s| s.to_string())
    })
    .flatten()
}

pub fn api_base(key: &str) -> Option<String> {
    with_overlay(|v| {
        v.pointer(&format!("/apis/{key}"))
            .and_then(|x| x.as_str())
            .map(|s| s.to_string())
    })
    .flatten()
}

pub fn anime_string(path: &str) -> Option<String> {
    with_overlay(|v| {
        v.pointer(&format!("/anime/{path}"))
            .and_then(|x| x.as_str())
            .map(|s| s.to_string())
    })
    .flatten()
}

pub fn miruro_origins() -> Option<Vec<String>> {
    with_overlay(|v| {
        let arr = v.pointer("/anime/miruroOrigins")?.as_array()?;
        let out: Vec<String> = arr
            .iter()
            .filter_map(|x| x.as_str().map(|s| s.to_string()))
            .filter(|s| s.starts_with("http"))
            .collect();
        if out.is_empty() {
            None
        } else {
            Some(out)
        }
    })
    .flatten()
}

pub fn kisskh_mirrors() -> Option<Vec<String>> {
    with_overlay(|v| {
        let arr = v.pointer("/anime/kisskhMirrors")?.as_array()?;
        let out: Vec<String> = arr
            .iter()
            .filter_map(|x| x.as_str().map(|s| s.to_string()))
            .filter(|s| s.starts_with("http"))
            .collect();
        if out.is_empty() {
            None
        } else {
            Some(out)
        }
    })
    .flatten()
}

/// Scraper source base URL overlay (`/webstreamr/{source_id}` — legacy RFC-039 key).
pub fn source_host_base(source_id: &str) -> Option<String> {
    with_overlay(|v| {
        v.pointer(&format!("/webstreamr/{source_id}"))
            .and_then(|x| x.as_str())
            .map(|s| s.trim().to_string())
            .filter(|s| s.starts_with("http"))
    })
    .flatten()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    /// Process-wide overlay is shared; serialize tests that mutate it.
    static OVERLAY_TEST_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn overlay_movie_template() {
        let _guard = OVERLAY_TEST_LOCK
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        clear_overlay();
        set_overlay_json(
            r#"{
              "schema": 1,
              "templates": {
                "vidlink": { "movie": "https://example.test/movie/{tmdb}" }
              }
            }"#,
        )
        .unwrap();
        let tpl = movie_template("vidlink").unwrap();
        assert_eq!(expand_template(&tpl, 550, 0, 0), "https://example.test/movie/550");
        clear_overlay();
    }

    #[test]
    fn overlay_source_host_base() {
        let _guard = OVERLAY_TEST_LOCK
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        clear_overlay();
        set_overlay_json(
            r#"{
              "schema": 1,
              "webstreamr": { "kinoger": "https://ops.kinoger.test" }
            }"#,
        )
        .unwrap();
        assert_eq!(
            source_host_base("kinoger").as_deref(),
            Some("https://ops.kinoger.test")
        );
        clear_overlay();
    }
}
