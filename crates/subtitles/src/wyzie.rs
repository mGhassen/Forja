use serde_json::{json, Value};

use crate::fetch;

/// Wyzie API key from `WYZIE_API_KEY` (repo `.env` or CI env) at compile time.
const WYZIE_KEY: &str = match option_env!("WYZIE_API_KEY") {
    Some(k) => k,
    None => "",
};

pub fn fetch(tmdb_id: i64, season: Option<i32>, episode: Option<i32>) -> Result<Vec<Value>, String> {
    if WYZIE_KEY.is_empty() {
        return Err(
            "WYZIE_API_KEY missing — copy .env.example to .env and rebuild Rust".into(),
        );
    }
    let mut url = format!("https://sub.wyzie.io/search?id={tmdb_id}&key={WYZIE_KEY}");
    if let (Some(s), Some(e)) = (season, episode) {
        url.push_str(&format!("&season={s}&episode={e}"));
    }
    let (status, body) = crate::fetch::get(&url, &Default::default(), 15)?;
    if status != 200 {
        let se = match (season, episode) {
            (Some(s), Some(e)) => format!(" season={s} episode={e}"),
            _ => String::new(),
        };
        let body_snip: String = body.chars().take(200).collect();
        return Err(format!(
            "wyzie HTTP {} (tmdb_id={tmdb_id}{se}){body}",
            status,
            body = if body_snip.is_empty() {
                String::new()
            } else {
                format!(" — {body_snip}")
            }
        ));
    }
    let data: Vec<Value> = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    let mut totals = std::collections::HashMap::new();
    for s in &data {
        let name = display_name(s);
        *totals.entry(name).or_insert(0) += 1;
    }
    let mut seen = std::collections::HashMap::new();
    let mut out = Vec::new();
    for s in data {
        let name = display_name(&s);
        let n = seen.entry(name.clone()).or_insert(0);
        *n += 1;
        let display = if totals.get(&name).copied().unwrap_or(0) > 1 {
            format!("{} {n} - wyzie", name)
        } else {
            format!("{} 1 - wyzie", name)
        };
        let mut entry = match s {
            Value::Object(map) => map,
            _ => continue,
        };
        if let Some(url) = entry.get("url").and_then(|v| v.as_str()) {
            let dl = if url.contains("wyzie.io") || url.contains("wyzie.ru") {
                if url.contains('?') {
                    format!("{url}&key={WYZIE_KEY}")
                } else {
                    format!("{url}?key={WYZIE_KEY}")
                }
            } else {
                url.to_string()
            };
            entry.insert("url".into(), json!(dl));
        }
        entry.insert("display".into(), json!(display));
        entry.insert("sourceName".into(), json!("wyzie"));
        out.push(Value::Object(entry));
    }
    Ok(out)
}

fn display_name(s: &Value) -> String {
    s.get("display")
        .or_else(|| s.get("language"))
        .and_then(|v| v.as_str())
        .unwrap_or("Unknown")
        .to_string()
}
