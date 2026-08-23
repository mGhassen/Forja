//! Batch-audit Forja HTTP movie/TV plugins via engine-js.
//!
//!   cargo run -p engine-js --bin audit-engine-plugins -- \
//!     --tmdb=94997 --media=tv --season=1 --episode=1
//!
//! Or: ./scripts/audit-engine-plugins.sh --tmdb=94997 --media=tv --season=1 --episode=1

use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::time::Instant;

use engine_js::{extract, ExtractRequest, HopScript};
use serde::Deserialize;
use serde_json::{json, Value};

#[derive(Debug, Deserialize)]
struct Manifest {
    plugins: Vec<ManifestPlugin>,
}

#[derive(Debug, Deserialize)]
struct ManifestPlugin {
    id: String,
    #[serde(default)]
    entry: String,
    #[serde(default)]
    types: Vec<String>,
    #[serde(default)]
    kind: String,
    #[serde(default)]
    hosts: Vec<String>,
    #[serde(default)]
    config: Value,
}

#[derive(Debug, Clone)]
struct Flags {
    crypto: bool,
    cheerio: bool,
    redirect_manual: bool,
    host: bool,
}

impl Flags {
    fn scan(code: &str) -> Self {
        let lower = code.to_ascii_lowercase();
        Self {
            crypto: code.contains("CryptoJS")
                || code.contains("AES.decrypt")
                || code.contains("AES.encrypt"),
            cheerio: lower.contains("cheerio") || code.contains("require('cheerio"),
            redirect_manual: code.contains("redirect") && code.contains("manual"),
            host: code.contains("ctx.host(") || code.contains("ctx.host ("),
        }
    }

    fn label(&self) -> String {
        let mut parts = Vec::new();
        if self.crypto {
            parts.push("crypto");
        }
        if self.cheerio {
            parts.push("cheerio");
        }
        if self.redirect_manual {
            parts.push("redirectManual");
        }
        if self.host {
            parts.push("host");
        }
        if parts.is_empty() {
            "-".into()
        } else {
            parts.join(",")
        }
    }
}

fn usage() {
    eprintln!(
        "audit-engine-plugins — Forja engine-js provider matrix\n\
         \n\
         Usage:\n\
           audit-engine-plugins [--tmdb=ID] [--media=tv|movie] [--season=N] [--episode=N]\n\
                                [--timeout-ms=N] [--plugin=ID]... [--json] [--assets=DIR]\n\
         \n\
         Defaults: tmdb=94997 media=tv season=1 episode=1 timeout-ms=60000\n\
         Assets default: <repo>/apps/forja/assets/plugins\n"
    );
}

fn repo_root() -> PathBuf {
    let manifest = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    // crates/engine-js → crates → repo
    manifest
        .parent()
        .and_then(|p| p.parent())
        .map(|p| p.to_path_buf())
        .unwrap_or(manifest)
}

fn classify(
    n: usize,
    needs_host: Option<&str>,
    error: Option<&str>,
    unsupported: bool,
) -> &'static str {
    if n > 0 {
        return "ok";
    }
    if unsupported {
        return "engine_gap";
    }
    if let Some(err) = error {
        let lower = err.to_ascii_lowercase();
        if lower.contains("timeout") || lower.contains("timed out") {
            return "timeout";
        }
        return "runtime";
    }
    if needs_host.is_some() {
        return "host";
    }
    "provider_empty"
}

#[tokio::main]
async fn main() -> ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.iter().any(|a| a == "-h" || a == "--help") {
        usage();
        return ExitCode::SUCCESS;
    }

    let mut tmdb = "94997".to_string();
    let mut media = "tv".to_string();
    let mut season: u32 = 1;
    let mut episode: u32 = 1;
    let mut timeout_ms: u64 = 60_000;
    let mut json_out = false;
    let mut only: BTreeSet<String> = BTreeSet::new();
    let mut assets: Option<PathBuf> = None;

    let mut i = 0;
    while i < args.len() {
        let a = &args[i];
        if let Some(v) = a.strip_prefix("--tmdb=") {
            tmdb = v.to_string();
        } else if a == "--tmdb" {
            i += 1;
            tmdb = args.get(i).cloned().unwrap_or_default();
        } else if let Some(v) = a.strip_prefix("--media=") {
            media = v.to_string();
        } else if a == "--media" {
            i += 1;
            media = args.get(i).cloned().unwrap_or_default();
        } else if let Some(v) = a.strip_prefix("--season=") {
            season = v.parse().unwrap_or(1);
        } else if a == "--season" {
            i += 1;
            season = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(1);
        } else if let Some(v) = a.strip_prefix("--episode=") {
            episode = v.parse().unwrap_or(1);
        } else if a == "--episode" {
            i += 1;
            episode = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(1);
        } else if let Some(v) = a.strip_prefix("--timeout-ms=") {
            timeout_ms = v.parse().unwrap_or(60_000);
        } else if a == "--timeout-ms" {
            i += 1;
            timeout_ms = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(60_000);
        } else if let Some(v) = a.strip_prefix("--plugin=") {
            only.insert(v.to_string());
        } else if a == "-p" || a == "--plugin" {
            i += 1;
            if let Some(v) = args.get(i) {
                only.insert(v.clone());
            }
        } else if let Some(v) = a.strip_prefix("--assets=") {
            assets = Some(PathBuf::from(v));
        } else if a == "--assets" {
            i += 1;
            assets = args.get(i).map(PathBuf::from);
        } else if a == "--json" {
            json_out = true;
        } else {
            eprintln!("unknown arg: {a}");
            usage();
            return ExitCode::FAILURE;
        }
        i += 1;
    }

    let assets_dir = assets.unwrap_or_else(|| {
        repo_root().join("apps/forja/assets/plugins")
    });
    let manifest_path = assets_dir.join("engine.json");
    let raw = match fs::read_to_string(&manifest_path) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("failed to read {}: {e}", manifest_path.display());
            return ExitCode::FAILURE;
        }
    };
    let manifest: Manifest = match serde_json::from_str(&raw) {
        Ok(m) => m,
        Err(e) => {
            eprintln!("invalid engine.json: {e}");
            return ExitCode::FAILURE;
        }
    };

    let hops: Vec<HopScript> = manifest
        .plugins
        .iter()
        .filter(|p| p.kind == "hop")
        .filter_map(|p| {
            let code = read_entry(&assets_dir, &p.entry)?;
            Some(HopScript {
                id: p.id.clone(),
                hosts: p.hosts.clone(),
                code,
            })
        })
        .collect();

    let targets: Vec<&ManifestPlugin> = manifest
        .plugins
        .iter()
        .filter(|p| p.kind == "http")
        .filter(|p| p.types.iter().any(|t| t == "movie" || t == "tv"))
        .filter(|p| only.is_empty() || only.contains(&p.id))
        .collect();

    if targets.is_empty() {
        eprintln!("no matching http movie/tv plugins");
        return ExitCode::FAILURE;
    }

    eprintln!(
        "audit-engine-plugins tmdb={tmdb} media={media} S{season}E{episode} \
         plugins={} hops={} timeout_ms={timeout_ms} assets={}",
        targets.len(),
        hops.len(),
        assets_dir.display()
    );

    let mut rows: Vec<Value> = Vec::new();
    let mut bucket_counts: std::collections::BTreeMap<&'static str, usize> =
        std::collections::BTreeMap::new();

    if !json_out {
        println!(
            "{:<20} {:>5} {:<14} {:<12} {:<8} {:>6} {}",
            "id", "n", "bucket", "needs_host", "unsup", "ms", "flags"
        );
        println!("{}", "-".repeat(90));
    }

    for plugin in targets {
        let code = match read_entry(&assets_dir, &plugin.entry) {
            Some(c) => c,
            None => {
                let bucket = "runtime";
                *bucket_counts.entry(bucket).or_default() += 1;
                let row = json!({
                    "id": plugin.id,
                    "n_streams": 0,
                    "bucket": bucket,
                    "needs_host": Value::Null,
                    "error": format!("missing entry {}", plugin.entry),
                    "unsupported": false,
                    "ms": 0,
                    "flags": "-",
                });
                print_row(&row, json_out);
                rows.push(row);
                continue;
            }
        };
        let flags = Flags::scan(&code);
        let ctx = json!({
            "tmdbId": tmdb,
            "imdbId": "",
            "malId": "",
            "anilistId": "",
            "mappedEpisode": episode,
            "type": media,
            "season": season,
            "episode": episode,
            "title": "",
            "year": "",
            "url": "",
            "config": plugin.config.clone(),
        });

        let sw = Instant::now();
        let result = extract(ExtractRequest {
            plugin_id: plugin.id.clone(),
            code,
            ctx,
            timeout_ms,
            allow_host_fallback: true,
            hops: hops.clone(),
            hop_depth: 0,
        })
        .await;
        let ms = sw.elapsed().as_millis() as u64;

        let n = result.streams.len();
        let unsupported = result.unsupported.unwrap_or(false);
        let needs = result.needs_host.clone();
        let err = result.error.clone();
        let bucket = classify(n, needs.as_deref(), err.as_deref(), unsupported);
        *bucket_counts.entry(bucket).or_default() += 1;

        let row = json!({
            "id": plugin.id,
            "n_streams": n,
            "bucket": bucket,
            "needs_host": needs,
            "error": err,
            "unsupported": unsupported,
            "ms": ms,
            "flags": flags.label(),
        });
        print_row(&row, json_out);
        rows.push(row);
    }

    if json_out {
        println!(
            "{}",
            serde_json::to_string_pretty(&json!({
                "tmdb": tmdb,
                "media": media,
                "season": season,
                "episode": episode,
                "timeout_ms": timeout_ms,
                "rows": rows,
                "buckets": bucket_counts,
            }))
            .unwrap_or_default()
        );
    } else {
        println!("{}", "-".repeat(90));
        println!("buckets:");
        for (k, v) in &bucket_counts {
            println!("  {k}: {v}");
        }
        let crypto_empty: Vec<_> = rows
            .iter()
            .filter(|r| {
                r.get("bucket").and_then(|b| b.as_str()).unwrap_or("ok") != "ok"
                    && r.get("flags")
                        .and_then(|f| f.as_str())
                        .unwrap_or("")
                        .contains("crypto")
            })
            .filter_map(|r| r.get("id").and_then(|i| i.as_str()).map(|s| s.to_string()))
            .collect();
        if !crypto_empty.is_empty() {
            println!("crypto-flagged non-ok: {}", crypto_empty.join(", "));
        }
    }

    ExitCode::SUCCESS
}

fn read_entry(assets: &Path, entry: &str) -> Option<String> {
    if entry.is_empty() {
        return None;
    }
    let path = assets.join(entry);
    fs::read_to_string(path).ok()
}

fn print_row(row: &Value, json_out: bool) {
    if json_out {
        return;
    }
    let id = row.get("id").and_then(|v| v.as_str()).unwrap_or("?");
    let n = row.get("n_streams").and_then(|v| v.as_u64()).unwrap_or(0);
    let bucket = row.get("bucket").and_then(|v| v.as_str()).unwrap_or("?");
    let needs = row
        .get("needs_host")
        .and_then(|v| v.as_str())
        .unwrap_or("-");
    let unsup = if row.get("unsupported").and_then(|v| v.as_bool()).unwrap_or(false) {
        "yes"
    } else {
        "-"
    };
    let ms = row.get("ms").and_then(|v| v.as_u64()).unwrap_or(0);
    let flags = row.get("flags").and_then(|v| v.as_str()).unwrap_or("-");
    let err = row.get("error").and_then(|v| v.as_str()).unwrap_or("");
    let err_short = if err.is_empty() {
        String::new()
    } else {
        format!("  err={}", truncate(err, 60))
    };
    println!(
        "{id:<20} {n:>5} {bucket:<14} {needs:<12} {unsup:<8} {ms:>6} {flags}{err_short}"
    );
}

fn truncate(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        s.to_string()
    } else {
        let t: String = s.chars().take(max.saturating_sub(1)).collect();
        format!("{t}…")
    }
}
