use serde_json::{json, Value};

pub fn fetch(tmdb_id: i64, season: Option<i32>, episode: Option<i32>) -> Result<Vec<Value>, String> {
    let id_param = match (season, episode) {
        (Some(s), Some(e)) => format!("{tmdb_id}/{s}/{e}"),
        _ => tmdb_id.to_string(),
    };
    let url = format!("https://api.levrx.de/search?id={id_param}");
    let (status, body) = crate::fetch::get(&url, &Default::default(), 15)?;
    if status != 200 {
        return Err(format!("levrx HTTP {}", status));
    }
    let data: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    let subtitles = data
        .get("subtitles")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let mut out = Vec::new();
    for sub in subtitles {
        let category = sub
            .get("category")
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown");
        let urls = sub
            .get("urls")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        for (i, url) in urls.iter().enumerate() {
            let Some(url_str) = url.as_str() else { continue };
            out.push(json!({
                "url": url_str,
                "display": format!("{} {} - levrx", category, i + 1),
                "language": levrx_language_code(category),
                "sourceName": "levrx",
            }));
        }
    }
    Ok(out)
}

fn levrx_language_code(category: &str) -> String {
    const MAP: &[(&str, &str)] = &[
        ("Arabic", "ar"),
        ("Brazilian", "pt-BR"),
        ("Bulgarian", "bg"),
        ("Chinese", "zh"),
        ("Czech", "cs"),
        ("Danish", "da"),
        ("Dutch", "nl"),
        ("English", "en"),
        ("Finnish", "fi"),
        ("French", "fr"),
        ("German", "de"),
        ("Greek", "el"),
        ("Hebrew", "he"),
        ("Hungarian", "hu"),
        ("Indonesian", "id"),
        ("Italian", "it"),
        ("Japanese", "ja"),
        ("Korean", "ko"),
        ("Norwegian", "no"),
        ("Persian", "fa"),
        ("Polish", "pl"),
        ("Portuguese", "pt"),
        ("Romanian", "ro"),
        ("Russian", "ru"),
        ("Serbian", "sr"),
        ("Slovak", "sk"),
        ("Spanish", "es"),
        ("Swedish", "sv"),
        ("Thai", "th"),
        ("Turkish", "tr"),
        ("Ukrainian", "uk"),
        ("Vietnamese", "vi"),
    ];
    for (k, v) in MAP {
        if *k == category {
            return (*v).to_string();
        }
    }
    let lower = category.to_lowercase();
    let end = lower.len().min(2);
    lower.chars().take(end).collect()
}
