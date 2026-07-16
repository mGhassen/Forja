//! Shared by `tmdb` / `webstreamr` `build.rs` — load repo-root `.env` into
//! `cargo:rustc-env` so `option_env!("TMDB_*")` works without committing keys.
//!
//! Priority: process env (CI secrets) wins over `.env` file values.

use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

const KEYS: &[&str] = &["TMDB_API_KEY", "TMDB_READ_ACCESS_TOKEN"];

pub fn emit_tmdb_env() {
    for key in KEYS {
        println!("cargo:rerun-if-env-changed={key}");
    }

    let file_vals = find_and_parse_dotenv();
    for key in KEYS {
        if let Ok(v) = env::var(key) {
            if !v.trim().is_empty() {
                println!("cargo:rustc-env={key}={v}");
                continue;
            }
        }
        if let Some(v) = file_vals.get(*key) {
            if !v.is_empty() {
                println!("cargo:rustc-env={key}={v}");
            }
        }
    }
}

fn find_and_parse_dotenv() -> HashMap<String, String> {
    let mut dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".into()));
    for _ in 0..6 {
        let candidate = dir.join(".env");
        if candidate.is_file() {
            println!("cargo:rerun-if-changed={}", candidate.display());
            return parse_dotenv(&candidate);
        }
        if !dir.pop() {
            break;
        }
    }
    HashMap::new()
}

fn parse_dotenv(path: &Path) -> HashMap<String, String> {
    let Ok(text) = fs::read_to_string(path) else {
        return HashMap::new();
    };
    let mut out = HashMap::new();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((k, v)) = line.split_once('=') else {
            continue;
        };
        let k = k.trim();
        let mut v = v.trim();
        if (v.starts_with('"') && v.ends_with('"')) || (v.starts_with('\'') && v.ends_with('\''))
        {
            v = &v[1..v.len() - 1];
        }
        if KEYS.contains(&k) {
            out.insert(k.to_string(), v.to_string());
        }
    }
    out
}
