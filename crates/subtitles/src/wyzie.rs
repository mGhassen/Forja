use serde_json::Value;

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
    let mut url = String::from("https://sub.wyzie.io/search?id=");
    url.push_str(&tmdb_id.to_string());
    url.push_str("&key=");
    url.push_str(WYZIE_KEY);
    if let (Some(s), Some(e)) = (season, episode) {
        url.push_str("&season=");
        url.push_str(&s.to_string());
        url.push_str("&episode=");
        url.push_str(&e.to_string());
    }
    let (status, body) = crate::fetch::get(&url, &Default::default(), 15)?;
    if status != 200 {
        let mut msg = String::from("wyzie HTTP ");
        msg.push_str(&status.to_string());
        msg.push_str(" (tmdb_id=");
        msg.push_str(&tmdb_id.to_string());
        if let (Some(s), Some(e)) = (season, episode) {
            msg.push_str(" season=");
            msg.push_str(&s.to_string());
            msg.push_str(" episode=");
            msg.push_str(&e.to_string());
        }
        msg.push(')');
        let body_snip: String = body.chars().take(200).collect();
        if !body_snip.is_empty() {
            msg.push_str(" — ");
            msg.push_str(&body_snip);
        }
        return Err(msg);
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
        let count = if totals.get(&name).copied().unwrap_or(0) > 1 {
            *n
        } else {
            1
        };
        let mut display = name;
        display.push(' ');
        display.push_str(&count.to_string());
        display.push_str(" - wyzie");
        let mut entry = match s {
            Value::Object(map) => map,
            _ => continue,
        };
        let url_owned = entry.get("url").and_then(Value::as_str).map(str::to_owned);
        if let Some(raw) = url_owned {
            entry.insert("url".into(), Value::String(wyzie_download_url(&raw)));
        }
        entry.insert("display".into(), Value::String(display));
        entry.insert("sourceName".into(), Value::String(String::from("wyzie")));
        out.push(Value::Object(entry));
    }
    Ok(out)
}

fn wyzie_download_url(url: &str) -> String {
    if !url.contains("wyzie.io") && !url.contains("wyzie.ru") {
        return url.to_string();
    }
    let mut out = String::with_capacity(url.len() + WYZIE_KEY.len() + 5);
    out.push_str(url);
    out.push_str(if url.contains('?') { "&key=" } else { "?key=" });
    out.push_str(WYZIE_KEY);
    out
}

fn display_name(s: &Value) -> String {
    s.get("display")
        .or_else(|| s.get("language"))
        .and_then(Value::as_str)
        .unwrap_or("Unknown")
        .to_string()
}
