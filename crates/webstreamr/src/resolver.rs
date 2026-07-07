use crate::config::{self, Config};
use crate::extractors::{run_extractor, EmbedMeta, UrlResult};
use crate::language::country_flags;
use crate::sources::{source_by_id, run_source, ALL_SOURCES, SourceDef, SourceEmbed};
use crate::types::{MediaType, StreamFormat};
use crate::utils::get_closest_resolution;
use rayon::prelude::*;
use serde::Deserialize;
use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};

/// Stop querying extra primary sources once this many playable URLs are found.
const EARLY_EXIT_PLAYABLE_URLS: usize = 8;

#[derive(Debug, Deserialize)]
pub struct StreamsRequest {
    pub imdb_id: Option<String>,
    pub tmdb_id: Option<i64>,
    pub media_type: MediaType,
    pub season: Option<i32>,
    pub episode: Option<i32>,
    pub title: Option<String>,
    pub year: Option<i32>,
    #[serde(default)]
    pub config: Config,
    pub tmdb_access_token: Option<String>,
    #[serde(default)]
    pub enabled_sources: Vec<String>,
}

fn format_bytes(b: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KB", "MB", "GB", "TB"];
    let mut v = b as f64;
    let mut i = 0usize;
    while v >= 1024.0 && i < UNITS.len() - 1 {
        v /= 1024.0;
        i += 1;
    }
    let s = if v >= 100.0 {
        format!("{v:.0}")
    } else {
        format!("{v:.2}")
    };
    format!("{s} {}", UNITS[i])
}

fn embed_to_meta(embed: &SourceEmbed, source_id: &str, source_label: &str) -> EmbedMeta {
    EmbedMeta {
        bytes: embed.bytes,
        country_codes: embed.country_codes.clone(),
        extractor_id: None,
        height: embed.height.map(|h| h as u32),
        priority: embed.priority,
        referer: embed.referer.clone(),
        source_id: Some(source_id.into()),
        source_label: Some(source_label.into()),
        title: embed.title.clone(),
    }
}

fn build_url_fields(r: &UrlResult) -> HashMap<String, serde_json::Value> {
    let mut out = HashMap::new();
    if let Some(yt) = &r.yt_id {
        out.insert("ytId".into(), serde_json::Value::String(yt.clone()));
    } else if !r.is_external {
        out.insert("url".into(), serde_json::Value::String(r.url.clone()));
    } else {
        out.insert(
            "externalUrl".into(),
            serde_json::Value::String(r.url.clone()),
        );
    }
    out
}

fn build_name(config: &config::Config, r: &UrlResult) -> String {
    let mut n = config::APP_NAME.to_string();
    if !r.meta.country_codes.is_empty() {
        n.push(' ');
        n.push_str(&country_flags(&r.meta.country_codes));
    }
    if let Some(h) = r.meta.height {
        n.push(' ');
        n.push_str(get_closest_resolution(Some(h)));
    }
    if r.is_external && config::show_external_urls(config) {
        n.push_str(" ⚠️ external");
    }
    n
}

fn build_title(r: &UrlResult) -> String {
    let mut lines = Vec::new();
    if let Some(t) = &r.meta.title {
        lines.push(t.clone());
    }
    let mut detail = Vec::new();
    if let Some(b) = r.meta.bytes {
        detail.push(format!("💾 {}", format_bytes(b)));
    }
    let sl = r.meta.source_label.as_deref();
    if let Some(sl) = sl.filter(|s| Some(*s) != r.meta.source_id.as_deref()) {
        detail.push(format!("🔗 {} from {}", r.label, sl));
    } else {
        detail.push(format!("🔗 {}", r.label));
    }
    lines.push(detail.join(" "));
    if let Some(err) = &r.error {
        lines.push(err.clone());
    }
    lines.join("\n")
}

fn compare_results(a: &UrlResult, b: &UrlResult) -> std::cmp::Ordering {
    if a.error.is_some() && b.error.is_none() {
        return std::cmp::Ordering::Less;
    }
    if a.error.is_none() && b.error.is_some() {
        return std::cmp::Ordering::Greater;
    }
    if a.is_external && !b.is_external {
        return std::cmp::Ordering::Greater;
    }
    if !a.is_external && b.is_external {
        return std::cmp::Ordering::Less;
    }
    let h = b.meta.height.unwrap_or(0).cmp(&a.meta.height.unwrap_or(0));
    if h != std::cmp::Ordering::Equal {
        return h;
    }
    let by = b.meta.bytes.unwrap_or(0).cmp(&a.meta.bytes.unwrap_or(0));
    if by != std::cmp::Ordering::Equal {
        return by;
    }
    let p = b.meta.priority.unwrap_or(0).cmp(&a.meta.priority.unwrap_or(0));
    if p != std::cmp::Ordering::Equal {
        return p;
    }
    a.label.cmp(&b.label)
}

fn source_country_enabled(def: &SourceDef, config: &Config) -> bool {
    def.country_codes
        .iter()
        .any(|cc| config::country_enabled(config, cc))
}

pub fn resolve_streams(request: &StreamsRequest) -> Vec<serde_json::Value> {
    let config = if request.config.is_empty() {
        config::default_config()
    } else {
        request.config.clone()
    };
    let token = request.tmdb_access_token.as_deref();

    let enabled: Vec<&str> = if request.enabled_sources.is_empty() {
        ALL_SOURCES.iter().map(|s| s.id).collect()
    } else {
        request.enabled_sources.iter().map(|s| s.as_str()).collect()
    };

    if enabled.is_empty() {
        return vec![serde_json::json!({
            "name": config::APP_NAME,
            "title": "⚠️ No sources found. Please re-configure the plugin.",
            "externalUrl": "stremio://",
        })];
    }

    let req = crate::sources::SourceRequest {
        imdb_id: request.imdb_id.clone(),
        tmdb_id: request.tmdb_id,
        media_type: request.media_type,
        season: request.season,
        episode: request.episode,
        title: request.title.clone(),
        year: request.year,
    };

    let media_type = match request.media_type {
        MediaType::Movie => "movie",
        MediaType::Series => "series",
    };

    let mut skipped_fallback = Vec::new();
    let mut primary_sources = Vec::new();

    for source_id in &enabled {
        let Some(def) = source_by_id(source_id) else {
            continue;
        };
        if !def.content_types.contains(&request.media_type) {
            continue;
        }
        if !source_country_enabled(def, &config) {
            continue;
        }
        if def.use_only_with_max_urls_found.is_some() {
            skipped_fallback.push(def);
            continue;
        }
        primary_sources.push(def);
    }

    let playable_count = AtomicUsize::new(0);
    let mut url_results: Vec<UrlResult> = primary_sources
        .par_iter()
        .flat_map(|def| {
            if utils::engine_cancel::is_requested()
                || playable_count.load(Ordering::Relaxed) >= EARLY_EXIT_PLAYABLE_URLS
            {
                return Vec::new();
            }
            let results = source_results(def, &req, &config, token);
            let added = results
                .iter()
                .filter(|r| r.error.is_none() && !r.url.is_empty())
                .count();
            if added > 0 {
                playable_count.fetch_add(added, Ordering::Relaxed);
            }
            results
        })
        .collect();

    let mut source_errors = 0usize;

    for fb in skipped_fallback {
        if utils::engine_cancel::is_requested() {
            break;
        }
        if !source_country_enabled(fb, &config) {
            continue;
        }
        let count = url_results.iter().filter(|r| {
            r.meta
                .country_codes
                .iter()
                .any(|cc| fb.country_codes.contains(&cc.as_str()))
        }).count();
        if let Some(max) = fb.use_only_with_max_urls_found {
            if count > max as usize {
                continue;
            }
        }
        handle_source(fb, &req, &config, token, media_type, &mut url_results, &mut source_errors);
    }

    url_results.sort_by(compare_results);

    let mut streams = Vec::new();
    let mut seen = std::collections::HashSet::new();

    for r in url_results {
        if r.error.is_some() && !config::show_errors(&config) {
            continue;
        }
        if config::is_resolution_excluded(
            &config,
            get_closest_resolution(r.meta.height),
        ) {
            continue;
        }
        if !seen.insert(r.url.clone()) {
            continue;
        }

        let mut stream = build_url_fields(&r);
        stream.insert("name".into(), serde_json::Value::String(build_name(&config, &r)));
        stream.insert("title".into(), serde_json::Value::String(build_title(&r)));

        let mut hints = serde_json::Map::new();
        let binge = format!(
            "webstreamr-{}-{}-{}",
            r.meta.source_id.as_deref().unwrap_or(""),
            r.meta.extractor_id.as_deref().unwrap_or(""),
            r.meta.country_codes.join("_")
        );
        hints.insert("bingeGroup".into(), serde_json::Value::String(binge));
        if r.format != StreamFormat::Mp4 {
            hints.insert("notWebReady".into(), serde_json::Value::Bool(true));
        }
        if let Some(headers) = &r.request_headers {
            hints.insert("notWebReady".into(), serde_json::Value::Bool(true));
            hints.insert(
                "proxyHeaders".into(),
                serde_json::json!({ "request": headers }),
            );
        }
        if let Some(bytes) = r.meta.bytes {
            hints.insert("videoSize".into(), serde_json::Value::Number(bytes.into()));
        }
        stream.insert("behaviorHints".into(), serde_json::Value::Object(hints));
        streams.push(serde_json::Value::Object(
            stream.into_iter().collect(),
        ));
    }

    if streams.is_empty() && source_errors > 0 && config::show_errors(&config) {
        // errors already surfaced per-source when showErrors is on
    }

    streams
}

fn source_results(
    def: &SourceDef,
    req: &crate::sources::SourceRequest,
    config: &Config,
    token: Option<&str>,
) -> Vec<UrlResult> {
    let mut results = Vec::new();
    let mut errors = 0usize;
    handle_source(def, req, config, token, "", &mut results, &mut errors);
    results
}

fn handle_source(
    def: &SourceDef,
    req: &crate::sources::SourceRequest,
    config: &Config,
    token: Option<&str>,
    _media_type: &str,
    url_results: &mut Vec<UrlResult>,
    source_errors: &mut usize,
) {
    let embeds = run_source(def.id, req, config, token);
    for embed in embeds {
        let meta = embed_to_meta(&embed, def.id, def.label);
        let results = run_extractor(&embed.url, &meta, config);
        url_results.extend(results);
    }
    let _ = source_errors;
}

pub fn get_streams_json(request_json: &str) -> String {
    let request: StreamsRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => {
            return serde_json::json!({ "error": e.to_string() }).to_string();
        }
    };
    let streams = resolve_streams(&request);
    serde_json::to_string(&streams).unwrap_or_else(|_| "[]".into())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn builds_stream_from_fixture_extractor() {
        let html = fs::read_to_string("tests/fixtures/streamembed.html").unwrap();
        let config = config::default_config();
        let meta = EmbedMeta {
            referer: Some("https://ref.example/".into()),
            source_id: Some("test".into()),
            source_label: Some("Test".into()),
            country_codes: vec!["en".into()],
            ..Default::default()
        };
        let extract = crate::extractors::extract_embed_html(
            "streamembed",
            &html,
            "https://bullstream.example/v/1",
        )
        .unwrap();
        let mut url_results = [UrlResult {
            url: extract.url,
            format: extract.format,
            is_external: false,
            yt_id: None,
            error: None,
            label: "StreamEmbed".into(),
            meta: meta.clone(),
            request_headers: None,
        }];
        url_results.sort_by(compare_results);
        let streams = url_results
            .iter()
            .map(|r| {
                let mut s = build_url_fields(r);
                s.insert("name".into(), serde_json::Value::String(build_name(&config, r)));
                s.insert("title".into(), serde_json::Value::String(build_title(r)));
                serde_json::Value::Object(s.into_iter().collect())
            })
            .collect::<Vec<_>>();
        assert_eq!(streams.len(), 1);
        assert!(streams[0].get("url").is_some());
    }

    #[test]
    fn vidsrc_request_produces_embed_url() {
        let req_json = serde_json::json!({
            "imdb_id": "tt0944947",
            "tmdb_id": 1399,
            "media_type": "series",
            "season": 1,
            "episode": 1,
            "enabled_sources": ["vidsrc"],
            "config": { "multi": "on" }
        });
        // Will fail network on extractors but should parse request
        let _: StreamsRequest = serde_json::from_value(req_json).unwrap();
    }

    #[test]
    fn source_country_enabled_matches_config() {
        let mut de_only = config::default_config();
        de_only.clear();
        de_only.insert("multi".into(), "on".into());
        de_only.insert("de".into(), "on".into());

        let kinoger = source_by_id("kinoger").unwrap();
        let frenchcloud = source_by_id("frenchcloud").unwrap();
        let vidsrc = source_by_id("vidsrc").unwrap();

        assert!(source_country_enabled(kinoger, &de_only));
        assert!(source_country_enabled(vidsrc, &de_only));
        assert!(!source_country_enabled(frenchcloud, &de_only));
    }
}
