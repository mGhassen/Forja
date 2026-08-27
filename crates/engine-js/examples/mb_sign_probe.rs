use engine_js::{extract, ExtractRequest, HopScript};
use serde_json::json;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::time::Instant;

#[tokio::main]
async fn main() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .to_path_buf();
    let assets = root.join("forjahq-plugin");
    let manifest: serde_json::Value =
        serde_json::from_str(&fs::read_to_string(assets.join("engine.json")).unwrap()).unwrap();
    let plugin = manifest["plugins"]
        .as_array()
        .unwrap()
        .iter()
        .find(|p| p["id"] == "movieblast")
        .unwrap();
    let entry = plugin["entry"].as_str().unwrap();
    let code = fs::read_to_string(assets.join(entry)).unwrap();
    let ctx = json!({
        "tmdbId": "27205",
        "imdbId": "",
        "malId": "",
        "anilistId": "",
        "mappedEpisode": 1,
        "type": "movie",
        "season": 1,
        "episode": 1,
        "title": "Inception",
        "year": "2010",
        "url": "",
        "config": plugin["config"].clone(),
    });
    let sw = Instant::now();
    let result = extract(ExtractRequest {
        plugin_id: "movieblast".into(),
        code,
        ctx,
        timeout_ms: 60_000,
        allow_host_fallback: true,
        hops: Vec::<HopScript>::new(),
        hop_depth: 0,
    })
    .await;
    eprintln!(
        "ms={} n={} err={:?}",
        sw.elapsed().as_millis(),
        result.streams.len(),
        result.error
    );
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(15))
        .build()
        .unwrap();
    for (i, s) in result.streams.iter().take(3).enumerate() {
        let url = s.get("url").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let mut headers: HashMap<String, String> = HashMap::new();
        if let Some(h) = s.get("headers").and_then(|v| v.as_object()) {
            for (k, v) in h {
                if let Some(vs) = v.as_str() {
                    headers.insert(k.clone(), vs.to_string());
                }
            }
        }
        eprintln!(
            "stream{i} host={} verify={} hdrs={:?}",
            url.split('/').nth(2).unwrap_or(""),
            url.contains("verify="),
            headers.keys().collect::<Vec<_>>()
        );
        if let Some(q) = url.split('?').nth(1) {
            for part in q.split('&') {
                if let Some(v) = part.strip_prefix("verify=") {
                    let (ts, sig) = v.split_once('-').unwrap_or((v, ""));
                    let prefix: String = sig.chars().take(12).collect();
                    eprintln!("  verify ts={ts} sig_len={} sig_prefix={prefix}", sig.len());
                }
            }
        }
        let mut req = client.head(&url);
        for (k, v) in &headers {
            req = req.header(k.as_str(), v.as_str());
        }
        match req.send().await {
            Ok(r) => eprintln!("  HEAD+streamHdrs => {}", r.status()),
            Err(e) => eprintln!("  HEAD+streamHdrs ERR {e}"),
        }
        match client.head(&url).send().await {
            Ok(r) => eprintln!("  HEAD bare => {}", r.status()),
            Err(e) => eprintln!("  HEAD bare ERR {e}"),
        }
        let mut req = client.get(&url).header("Range", "bytes=0-0");
        for (k, v) in &headers {
            req = req.header(k.as_str(), v.as_str());
        }
        match req.send().await {
            Ok(r) => eprintln!("  GET Range+hdrs => {}", r.status()),
            Err(e) => eprintln!("  GET Range ERR {e}"),
        }
    }
}
