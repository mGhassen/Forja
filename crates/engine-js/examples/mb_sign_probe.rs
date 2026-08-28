use engine_js::{extract, ExtractRequest, HopScript};
use serde_json::json;
use std::collections::HashMap;
use std::env;
use std::time::Instant;

fn manifest_url() -> String {
    env::var("FORJA_HQ_PROVIDERS_MANIFEST_URL")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| {
            eprintln!("FORJA_HQ_PROVIDERS_MANIFEST_URL missing — set in repo-root .env");
            std::process::exit(2);
        })
}

fn pack_base(manifest_url: &str) -> String {
    match manifest_url.rsplit_once('/') {
        Some((base, _)) => format!("{base}/"),
        None => format!("{manifest_url}/"),
    }
}

async fn fetch_text(client: &reqwest::Client, url: &str) -> Result<String, String> {
    let resp = client
        .get(url)
        .send()
        .await
        .map_err(|e| format!("GET {url}: {e}"))?;
    if !resp.status().is_success() {
        return Err(format!("HTTP {} for {url}", resp.status()));
    }
    resp.text()
        .await
        .map_err(|e| format!("body {url}: {e}"))
}

#[tokio::main]
async fn main() {
    if env::args().nth(1).as_deref() == Some("-h")
        || env::args().nth(1).as_deref() == Some("--help")
    {
        eprintln!("usage: mb_sign_probe");
        eprintln!("  Requires FORJA_HQ_PROVIDERS_MANIFEST_URL (repo-root .env).");
        std::process::exit(0);
    }

    let manifest_url = manifest_url();
    let base = pack_base(&manifest_url);
    eprintln!("manifest={manifest_url}");

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .unwrap();

    let raw = fetch_text(&client, &manifest_url)
        .await
        .unwrap_or_else(|e| {
            eprintln!("{e}");
            std::process::exit(1);
        });
    let manifest: serde_json::Value = serde_json::from_str(&raw).unwrap();
    let plugin = manifest["plugins"]
        .as_array()
        .unwrap()
        .iter()
        .find(|p| p["id"] == "movieblast")
        .unwrap();
    let entry = plugin["entry"].as_str().unwrap();
    let code = fetch_text(&client, &format!("{base}{entry}"))
        .await
        .unwrap_or_else(|e| {
            eprintln!("{e}");
            std::process::exit(1);
        });
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
