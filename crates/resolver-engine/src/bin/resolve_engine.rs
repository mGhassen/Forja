//! CLI: race playback providers the same way the app’s Resolver Engine does.
//!
//! Prefer the repo wrapper (no cargo -p / --bin clutter):
//! ```bash
//! ./scripts/resolve-engine.sh --tmdb=1083381
//! ./scripts/resolve-engine.sh -p webstreamr --tmdb=1083381
//! ```
//!
//! Or via cargo (package name ≠ binary name — that’s why it looks doubled):
//! ```bash
//! cargo run -p resolver-engine -- --tmdb=1083381
//! ```
//!
//! Host-required providers (Videasy, VidFast, …) need Flutter WebView continue —
//! use `--native-only` to skip them in this CLI.

use std::env;
use std::process::ExitCode;

use resolver_engine::{list_builtin_provider_ids, resolve};
use stream_core::SourceDomain;

fn usage() -> ! {
    eprintln!(
        "\
Usage:
  resolve-engine --tmdb=<id> [-p <provider>]... [options]

Options:
  --tmdb=<id>          TMDB id (required unless --imdb= is set)
  -p, --provider <id>  Only these providers (repeatable). Default: all built-in
  --imdb=tt…           IMDb id (looked up from TMDB when omitted)
  --name=…, --title=…  Title override (looked up from TMDB when omitted)
  --year=<n>           Year override
  --media=movie|tv     Default movie
  --season=<n>         TV season
  --episode=<n>        TV episode
  --native-only        Skip host-required providers (WebView / Nuvio / …)
  --json               Print full ResolveResponse JSON
  -h, --help           Help
"
    );
    std::process::exit(2);
}

fn main() -> ExitCode {
    let mut tmdb: Option<i64> = None;
    let mut imdb_arg: Option<String> = None;
    let mut title_arg: Option<String> = None;
    let mut year_arg: Option<i32> = None;
    let mut media = "movie".to_string();
    let mut season = 1i32;
    let mut episode = 1i32;
    let mut providers: Vec<String> = Vec::new();
    let mut native_only = false;
    let mut dump_json = false;

    let args: Vec<String> = env::args().skip(1).collect();
    let mut i = 0usize;
    while i < args.len() {
        let a = &args[i];
        if a == "-h" || a == "--help" {
            usage();
        } else if a == "--json" {
            dump_json = true;
        } else if a == "--native-only" {
            native_only = true;
        } else if let Some(v) = a.strip_prefix("--tmdb=") {
            tmdb = v.parse().ok();
        } else if a == "--tmdb" {
            i += 1;
            tmdb = args.get(i).and_then(|s| s.parse().ok());
        } else if let Some(v) = a.strip_prefix("--imdb=") {
            imdb_arg = Some(v.to_string());
        } else if a == "--imdb" {
            i += 1;
            imdb_arg = args.get(i).cloned();
        } else if let Some(v) = a.strip_prefix("--name=") {
            title_arg = Some(v.to_string());
        } else if let Some(v) = a.strip_prefix("--title=") {
            title_arg = Some(v.to_string());
        } else if a == "--name" || a == "--title" {
            i += 1;
            title_arg = args.get(i).cloned();
        } else if let Some(v) = a.strip_prefix("--year=") {
            year_arg = v.parse().ok();
        } else if a == "--year" {
            i += 1;
            year_arg = args.get(i).and_then(|s| s.parse().ok());
        } else if let Some(v) = a.strip_prefix("--media=") {
            media = v.to_string();
        } else if let Some(v) = a.strip_prefix("--season=") {
            season = v.parse().unwrap_or(1);
        } else if let Some(v) = a.strip_prefix("--episode=") {
            episode = v.parse().unwrap_or(1);
        } else if a == "-p" || a == "--provider" {
            i += 1;
            match args.get(i) {
                Some(id) if !id.starts_with('-') => providers.push(id.clone()),
                _ => {
                    eprintln!("missing provider id after {a}");
                    usage();
                }
            }
        } else if let Some(v) = a.strip_prefix("-p=") {
            providers.push(v.to_string());
        } else if let Some(v) = a.strip_prefix("--provider=") {
            providers.push(v.to_string());
        } else {
            eprintln!("unknown arg: {a}");
            usage();
        }
        i += 1;
    }

    let Some(tmdb_id) = tmdb.or_else(|| {
        // Allow --imdb=tt… alone: resolve TMDB from IMDb.
        let imdb = imdb_arg.as_deref()?;
        webstreamr::tmdb::get_tmdb_id_from_imdb(imdb, None, None, None)
            .ok()
            .and_then(|ids| ids.tmdb_id)
    }) else {
        eprintln!("--tmdb=<id> or --imdb=tt… is required");
        usage();
    };

    let is_tv = matches!(media.as_str(), "tv" | "series");
    let domain = if is_tv {
        SourceDomain::Series
    } else {
        SourceDomain::Movies
    };

    let ny = webstreamr::tmdb::get_tmdb_name_and_year(
        tmdb_id,
        if is_tv { Some(season) } else { None },
        None,
        None,
    )
    .ok();
    let imdb = imdb_arg
        .or_else(|| {
            webstreamr::tmdb::get_imdb_id_from_tmdb(
                tmdb_id,
                if is_tv { Some(season) } else { None },
                if is_tv { Some(episode) } else { None },
                None,
            )
            .ok()
            .and_then(|ids| ids.imdb_id)
        })
        .unwrap_or_default();
    let title = title_arg
        .or_else(|| ny.as_ref().map(|n| n.name.clone()))
        .unwrap_or_default();
    let year = year_arg.or_else(|| ny.as_ref().map(|n| n.year).filter(|y| *y > 0));

    let all = list_builtin_provider_ids();
    let enabled: Vec<String> = if providers.is_empty() {
        all.clone()
    } else {
        for p in &providers {
            if !all.iter().any(|id| id == p || p.starts_with("nuvio:")) {
                eprintln!("warning: unknown provider id {p:?} (still sending)");
            }
        }
        providers
    };
    let settings_order = enabled.clone();

    eprintln!(
        "resolve-engine domain={domain:?} tmdb={tmdb_id} imdb={imdb:?} title={title:?} year={year:?}"
    );
    eprintln!(
        "providers ({}){}: {}",
        enabled.len(),
        if native_only { " native-only" } else { "" },
        enabled.join(", ")
    );

    let mut req = serde_json::json!({
        "domain": match domain {
            SourceDomain::Movies => "movies",
            SourceDomain::Series => "series",
            _ => "movies",
        },
        "tmdbId": tmdb_id,
        "imdbId": imdb,
        "title": title,
        "mediaType": if is_tv { "tv" } else { "movie" },
        "settings": {
            "enabledProviderIds": enabled,
            "settingsOrder": settings_order,
            "preferred": "auto",
            "maxInFlight": 2,
            "skipHostOnTv": native_only,
        }
    });
    if let Some(y) = year {
        req["year"] = serde_json::json!(y);
    }
    if is_tv {
        req["season"] = serde_json::json!(season);
        req["episode"] = serde_json::json!(episode);
    }

    let raw = resolve(&req.to_string());
    let v: serde_json::Value =
        serde_json::from_str(&raw).unwrap_or(serde_json::json!({ "raw": raw }));

    if dump_json {
        println!("{}", serde_json::to_string_pretty(&v).unwrap());
    }

    let phase = v.get("phase").and_then(|x| x.as_str()).unwrap_or("?");
    let race_ms = v.get("raceMs").and_then(|x| x.as_u64()).unwrap_or(0);
    eprintln!("\nphase={phase} raceMs={race_ms}");

    if let Some(progress) = v.get("progress").and_then(|p| p.as_array()) {
        for ev in progress {
            let id = ev
                .get("providerId")
                .or_else(|| ev.get("provider_id"))
                .and_then(|x| x.as_str())
                .unwrap_or("?");
            let status = ev.get("status").and_then(|x| x.as_str()).unwrap_or("?");
            let msg = ev.get("message").and_then(|x| x.as_str()).unwrap_or("");
            if msg.is_empty() {
                eprintln!("  {id}: {status}");
            } else {
                eprintln!("  {id}: {status} — {msg}");
            }
        }
    }

    if let Some(hosts) = v.get("hostRequests").and_then(|h| h.as_array()) {
        if !hosts.is_empty() {
            eprintln!("\nhostRequests ({}) — need Flutter WebView continue:", hosts.len());
            for h in hosts {
                let id = h
                    .get("providerId")
                    .or_else(|| h.get("provider_id"))
                    .and_then(|x| x.as_str())
                    .unwrap_or("?");
                eprintln!("  - {id}");
            }
        }
    }

    let sources = v.get("sources").and_then(|s| s.as_array());
    let n = sources.map(|a| a.len()).unwrap_or(0);
    eprintln!("\n=== {n} sources ===");
    if let Some(arr) = sources {
        for (i, s) in arr.iter().enumerate() {
            let title = s.get("title").and_then(|x| x.as_str()).unwrap_or("?");
            let pid = s
                .get("provider_id")
                .or_else(|| s.get("providerId"))
                .and_then(|x| x.as_str())
                .unwrap_or("?");
            let url = s.get("url").and_then(|x| x.as_str()).unwrap_or("");
            eprintln!(
                "{}. [{}] {}",
                i + 1,
                pid,
                title.lines().take(2).collect::<Vec<_>>().join(" | ")
            );
            if !url.is_empty() {
                eprintln!("   {}", &url[..url.len().min(140)]);
            }
        }
    }

    if let Some(err) = v.get("error").and_then(|e| e.as_str()) {
        eprintln!("\nerror: {err}");
        return ExitCode::from(1);
    }
    if phase == "failed" || (n == 0 && phase != "awaiting_host") {
        return ExitCode::from(1);
    }
    ExitCode::SUCCESS
}
