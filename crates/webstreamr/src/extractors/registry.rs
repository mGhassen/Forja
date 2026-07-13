use crate::config::{self, Config};
use crate::extractors::{
    dropload_supports, extract_embed_html, extract_hubcloud_links,
    extract_mfp_embed_html, extract_vidsrc_chain_json, filemoon_supports, fsst_supports,
    hubcloud_supports, hubdrive_supports, kinoger_supports, rgshows_supports,
    savefiles_supports, streamembed_supports, supervideo_supports, vidora_supports,
    vixsrc_supports, youtube_supports,
};
use crate::fetcher::{fetch_text, FetchConfig};
use crate::types::{ExtractResult, StreamFormat};
use regex::Regex;
use scraper::{Html, Selector};
use std::sync::LazyLock;

static HUBCLOUD_SRC_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"src:\s*'(.*)'").unwrap());
use std::collections::HashMap;
use url::Url;

#[derive(Debug, Clone)]
#[derive(Default)]
pub struct EmbedMeta {
    pub bytes: Option<u64>,
    pub country_codes: Vec<String>,
    pub extractor_id: Option<String>,
    pub height: Option<u32>,
    pub priority: Option<i32>,
    pub referer: Option<String>,
    pub source_id: Option<String>,
    pub source_label: Option<String>,
    pub title: Option<String>,
}


#[derive(Debug, Clone)]
pub struct UrlResult {
    pub url: String,
    pub format: StreamFormat,
    pub is_external: bool,
    pub yt_id: Option<String>,
    pub error: Option<String>,
    pub label: String,
    pub meta: EmbedMeta,
    pub request_headers: Option<HashMap<String, String>>,
}

struct ExtractorDef {
    id: &'static str,
    label: &'static str,
    via_mfp: bool,
}

const EXTRACTORS: &[ExtractorDef] = &[
    ExtractorDef {
        id: "streamembed",
        label: "StreamEmbed",
        via_mfp: false,
    },
    ExtractorDef {
        id: "savefiles",
        label: "SaveFiles",
        via_mfp: false,
    },
    ExtractorDef {
        id: "dropload",
        label: "Dropload",
        via_mfp: false,
    },
    ExtractorDef {
        id: "supervideo",
        label: "SuperVideo",
        via_mfp: false,
    },
    ExtractorDef {
        id: "vidora",
        label: "Vidora",
        via_mfp: false,
    },
    ExtractorDef {
        id: "fsst",
        label: "FSST",
        via_mfp: false,
    },
    ExtractorDef {
        id: "vixsrc",
        label: "VixSrc",
        via_mfp: false,
    },
    ExtractorDef {
        id: "kinoger",
        label: "KinoGer",
        via_mfp: false,
    },
    ExtractorDef {
        id: "youtube",
        label: "YouTube",
        via_mfp: false,
    },
    ExtractorDef {
        id: "filemoon",
        label: "FileMoon",
        via_mfp: true,
    },
    ExtractorDef {
        id: "hubdrive",
        label: "HubDrive",
        via_mfp: false,
    },
    ExtractorDef {
        id: "hubcloud",
        label: "HubCloud",
        via_mfp: false,
    },
    ExtractorDef {
        id: "rgshows",
        label: "RGShows",
        via_mfp: false,
    },
    ExtractorDef {
        id: "vidsrc",
        label: "VidSrc",
        via_mfp: false,
    },
    ExtractorDef {
        id: "mixdrop",
        label: "Mixdrop",
        via_mfp: true,
    },
    ExtractorDef {
        id: "streamtape",
        label: "Streamtape",
        via_mfp: true,
    },
    ExtractorDef {
        id: "uqload",
        label: "Uqload",
        via_mfp: true,
    },
    ExtractorDef {
        id: "doodstream",
        label: "DoodStream",
        via_mfp: true,
    },
    ExtractorDef {
        id: "filelions",
        label: "FileLions",
        via_mfp: true,
    },
    ExtractorDef {
        id: "lulustream",
        label: "LuluStream",
        via_mfp: true,
    },
    ExtractorDef {
        id: "fastream",
        label: "Fastream",
        via_mfp: true,
    },
    ExtractorDef {
        id: "voe",
        label: "Voe",
        via_mfp: true,
    },
    ExtractorDef {
        id: "external",
        label: "External",
        via_mfp: false,
    },
];

pub fn find_extractor_for_url(url: &str, config: &Config) -> Option<&'static str> {
    let parsed = Url::parse(url).ok()?;
    let host = parsed.host_str()?;

    for def in EXTRACTORS {
        if config::is_extractor_disabled(config, def.id) {
            continue;
        }
        if host_matches(def.id, host, &parsed, config) {
            return Some(def.id);
        }
    }
    None
}

fn host_matches(id: &str, host: &str, url: &Url, config: &Config) -> bool {
    let mfp_ok = !extractor_via_mfp(id) || config::supports_media_flow_proxy(config);
    if !mfp_ok {
        return false;
    }
    match id {
        "streamembed" => streamembed_supports(host),
        "savefiles" => savefiles_supports(host),
        "dropload" => dropload_supports(host),
        "supervideo" => supervideo_supports(host),
        "vidora" => vidora_supports(host),
        "fsst" => fsst_supports(host),
        "vixsrc" => vixsrc_supports(host),
        "kinoger" => kinoger_supports(host),
        "youtube" => youtube_supports(host) && url.query_pairs().any(|(k, _)| k == "v"),
        "filemoon" => filemoon_supports(host),
        "hubdrive" => hubdrive_supports(host),
        "hubcloud" => hubcloud_supports(host),
        "rgshows" => rgshows_supports(host),
        "vidsrc" => Regex::new(r"vidsrc|vsrc|vsembed").unwrap().is_match(host),
        "mixdrop" => Regex::new(r"mixdrop|mixdrp|mixdroop|m1xdrop").unwrap().is_match(host),
        "streamtape" => {
            host.contains("streamtape")
                || matches!(
                    host,
                    "strtape.cloud"
                        | "streamta.pe"
                        | "strcloud.link"
                        | "strcloud.club"
                        | "strtpe.link"
                        | "scloud.online"
                        | "stape.fun"
                )
        }
        "uqload" => host.contains("uqload"),
        "doodstream" => Regex::new(
            r"dood|do[0-9]go|doood|dooood|ds2play|ds2video|dsvplay|d0o0d|do0od|d0000d|d000d|myvidplay|vidply|all3do|doply|vide0|vvide0|d-s",
        )
        .unwrap()
        .is_match(host),
        "filelions" => Regex::new(r".*lions?").unwrap().is_match(host),
        "lulustream" => host.contains("lulu"),
        "fastream" => host.contains("fastream"),
        "voe" => host.contains("voe"),
        "external" => config::show_external_urls(config),
        _ => false,
    }
}

fn extractor_via_mfp(id: &str) -> bool {
    EXTRACTORS
        .iter()
        .find(|d| d.id == id)
        .is_some_and(|d| d.via_mfp)
}

fn extractor_label(id: &str) -> String {
    EXTRACTORS
        .iter()
        .find(|d| d.id == id)
        .map(|d| d.label.to_string())
        .unwrap_or_else(|| id.to_string())
}

fn format_label(id: &str, label: &str) -> String {
    if extractor_via_mfp(id) {
        format!("{label} (MFP)")
    } else {
        label.to_string()
    }
}

pub fn normalize_url(extractor_id: &str, url: &str) -> String {
    match extractor_id {
        "mixdrop" => url.replace("/f/", "/e/"),
        "streamtape" => url.replace("/e/", "/v/"),
        "filemoon" => url.replace("/e/", "/d/"),
        "filelions" => url
            .replace("/v/", "/f/")
            .replace("/download/", "/f/")
            .replace("/file/", "/f/"),
        _ => url.to_string(),
    }
}

fn fetch_cfg(referer: Option<&str>) -> FetchConfig {
    let mut headers = HashMap::new();
    if let Some(r) = referer {
        headers.insert("Referer".into(), r.into());
    }
    FetchConfig {
        headers,
        ..Default::default()
    }
}

fn map_extract(result: ExtractResult, extractor_id: &str, meta: &EmbedMeta, label: &str) -> Option<UrlResult> {
    if result.url.is_empty() && result.next_url.is_none() && result.yt_id.is_none() {
        return None;
    }
    let mut out_meta = meta.clone();
    if let Some(t) = result.title {
        out_meta.title = Some(t);
    }
    if let Some(h) = result.height {
        out_meta.height = Some(h);
    }
    if let Some(b) = result.bytes {
        out_meta.bytes = Some(b);
    }
    if let Some(e) = result.meta_extractor_id {
        out_meta.extractor_id = Some(e);
    } else {
        out_meta.extractor_id = Some(extractor_id.into());
    }
    let display_label = result
        .label
        .unwrap_or_else(|| label.to_string());
    Some(UrlResult {
        url: result.url,
        format: result.format,
        is_external: result.is_external,
        yt_id: result.yt_id,
        error: None,
        label: format_label(extractor_id, &display_label),
        meta: out_meta,
        request_headers: result.request_headers,
    })
}

fn extract_html_step(
    extractor_id: &str,
    html: &str,
    page_url: &str,
    meta: &EmbedMeta,
    config: &Config,
    extra_html: &str,
) -> Option<ExtractResult> {
    if extractor_via_mfp(extractor_id) {
        let headers = HashMap::from([(
            "Referer".into(),
            meta.referer.clone().unwrap_or_else(|| page_url.into()),
        )]);
        let mfp_json = config::mfp_config_json(config, headers)?;
        return extract_mfp_embed_html(extractor_id, html, page_url, &mfp_json, extra_html);
    }
    extract_embed_html(extractor_id, html, page_url)
}

pub fn run_extractor(embed_url: &str, meta: &EmbedMeta, config: &Config) -> Vec<UrlResult> {
    let Some(extractor_id) = find_extractor_for_url(embed_url, config) else {
        return Vec::new();
    };

    let normalized = normalize_url(extractor_id, embed_url);
    let label = extractor_label(extractor_id);

    match extractor_id {
        "vidsrc" => return run_vidsrc_extractor(&normalized, meta, &label),
        "hubcloud" => return run_hubcloud_extractor(&normalized, meta, config, &label),
        "hubdrive" => return run_hubdrive_extractor(&normalized, meta, config, &label),
        "external" => {
            if let Some(r) = extract_embed_html("external", "", &normalized) {
                return map_extract(r, extractor_id, meta, &label)
                    .into_iter()
                    .collect();
            }
            return Vec::new();
        }
        _ => {}
    }

    run_fetch_chain(extractor_id, &normalized, meta, config, &label, 0)
}

fn run_fetch_chain(
    extractor_id: &str,
    page_url: &str,
    meta: &EmbedMeta,
    config: &Config,
    label: &str,
    depth: u8,
) -> Vec<UrlResult> {
    if depth > 8 {
        return Vec::new();
    }

    let referer = meta.referer.as_deref().unwrap_or(page_url);
    let cfg = fetch_cfg(Some(referer));

    if extractor_id == "mixdrop" {
        let file_url = page_url.replace("/e/", "/f/");
        let _ = fetch_text(&file_url, &cfg);
    } else if extractor_id == "streamtape" {
        let embed_url = page_url.replace("/v/", "/e/");
        let _ = fetch_text(&embed_url, &cfg);
    }

    let html = match fetch_text(page_url, &cfg) {
        Ok(h) => h,
        Err(e) => {
            return vec![UrlResult {
                url: page_url.into(),
                format: StreamFormat::Unknown,
                is_external: true,
                yt_id: None,
                error: Some(e),
                label: format_label(extractor_id, label),
                meta: meta.clone(),
                request_headers: None,
            }];
        }
    };

    if extractor_id == "filelions" && html.contains("This video can be watched as embed only") {
        let next = page_url.replace("/f/", "/v/");
        return run_fetch_chain(extractor_id, &next, meta, config, label, depth + 1);
    }

    if let Some(step) = extract_embed_html(extractor_id, &html, page_url) {
        if let Some(next) = step.next_url.as_ref().filter(|n| !n.is_empty()) {
            return run_fetch_chain(extractor_id, next, meta, config, label, depth + 1);
        }
        if !step.url.is_empty() || step.yt_id.is_some() {
            return map_extract(step, extractor_id, meta, label)
                .into_iter()
                .collect();
        }
    }

    if extractor_via_mfp(extractor_id) {
        let extra = if extractor_id == "doodstream" || extractor_id == "lulustream" || extractor_id == "fastream" {
            fetch_text(
                &page_url.replace("/e/", "/d/").replace("/v/", "/d/"),
                &cfg,
            )
            .unwrap_or_default()
        } else {
            String::new()
        };
        if let Some(step) = extract_html_step(extractor_id, &html, page_url, meta, config, &extra) {
            if step.next_url.is_none() && (!step.url.is_empty() || step.yt_id.is_some()) {
                return map_extract(step, extractor_id, meta, label)
                    .into_iter()
                    .collect();
            }
        }
    }

    Vec::new()
}

fn run_hubcloud_extractor(
    page_url: &str,
    meta: &EmbedMeta,
    _config: &Config,
    label: &str,
) -> Vec<UrlResult> {
    let referer = meta.referer.as_deref().unwrap_or(page_url);
    let Ok(redirect_html) = fetch_text(page_url, &fetch_cfg(Some(referer))) else {
        return Vec::new();
    };
    let Some(next) = extract_embed_html("hubcloud", &redirect_html, page_url) else {
        return Vec::new();
    };
    let Some(links_url) = next.next_url else {
        return Vec::new();
    };
    let Ok(links_html) = fetch_text(&links_url, &fetch_cfg(Some(page_url))) else {
        return Vec::new();
    };
    let title = Html::parse_document(&links_html)
        .select(&Selector::parse("title").unwrap())
        .next()
        .map(|el| el.text().collect::<String>().trim().to_string())
        .unwrap_or_default();
    let extra_cc = crate::language::find_country_codes(&title);
    extract_hubcloud_links(&links_html, page_url)
        .into_iter()
        .filter_map(|r| {
            let mut m = meta.clone();
            m.extractor_id = Some("hubcloud".into());
            for cc in &extra_cc {
                if !m.country_codes.contains(cc) {
                    m.country_codes.push(cc.clone());
                }
            }
            if let Some(h) = r.height {
                m.height = Some(h);
            }
            if let Some(b) = r.bytes {
                m.bytes = Some(b);
            }
            if let Some(t) = r.title.clone() {
                m.title = Some(t);
            }
            let row_label = r.label.clone();
            map_extract(r, "hubcloud", &m, row_label.as_deref().unwrap_or(label))
        })
        .collect()
}

fn run_hubdrive_extractor(
    page_url: &str,
    meta: &EmbedMeta,
    config: &Config,
    label: &str,
) -> Vec<UrlResult> {
    let referer = meta.referer.as_deref().unwrap_or(page_url);
    let Ok(html) = fetch_text(page_url, &fetch_cfg(Some(referer))) else {
        return Vec::new();
    };
    let Some(next) = extract_embed_html("hubdrive", &html, page_url) else {
        return Vec::new();
    };
    let Some(hub_url) = next.next_url else {
        return Vec::new();
    };
    run_hubcloud_extractor(&hub_url, meta, config, label)
}

fn run_vidsrc_extractor(page_url: &str, meta: &EmbedMeta, _label: &str) -> Vec<UrlResult> {
    let Ok(html) = fetch_text(page_url, &FetchConfig::default()) else {
        return Vec::new();
    };
    let cleaned = html.replacen("<!--", "", 1).replacen("-->", "", 1);
    let doc = Html::parse_document(&cleaned);
    let iframe_sel = Selector::parse("#player_iframe").unwrap();
    let server_sel = Selector::parse(".server").unwrap();
    let iframe_src = match doc
        .select(&iframe_sel)
        .next()
        .and_then(|el| el.value().attr("src"))
    {
        Some(s) => s,
        None => return Vec::new(),
    };
    let iframe_url = if iframe_src.starts_with("//") {
        format!("https:{iframe_src}")
    } else {
        iframe_src.to_string()
    };
    let iframe_origin = Url::parse(&iframe_url)
        .ok()
        .map(|u| format!("{}://{}", u.scheme(), u.host_str().unwrap_or("")))
        .unwrap_or_default();
    let referer_host = Url::parse(page_url)
        .ok()
        .map(|u| format!("{}://{}", u.scheme(), u.host_str().unwrap_or("")))
        .unwrap_or_default();

    let mut out = Vec::new();
    for el in doc.select(&server_sel) {
        let server_name: String = el.text().collect();
        if !server_name.contains("CloudStream Pro") {
            continue;
        }
        let Some(data_hash) = el.value().attr("data-hash") else {
            continue;
        };
        let rcp_url = format!("{iframe_origin}/rcp/{data_hash}");
        let Ok(iframe_html) = fetch_text(&rcp_url, &fetch_cfg(Some(&referer_host))) else {
            continue;
        };
        let src_re = &*HUBCLOUD_SRC_RE;
        let Some(player_path) = src_re
            .captures(&iframe_html)
            .and_then(|c| c.get(1))
            .map(|m| m.as_str())
        else {
            continue;
        };
        let player_url = if player_path.starts_with("http") {
            player_path.to_string()
        } else {
            format!("{iframe_origin}{player_path}")
        };
        let Ok(player_html) = fetch_text(&player_url, &fetch_cfg(Some(&rcp_url))) else {
            continue;
        };
        let chain_json = extract_vidsrc_chain_json(&html, &iframe_html, &player_html, Some(&rcp_url));
        let Ok(decoded) = serde_json::from_str::<serde_json::Value>(&chain_json) else {
            continue;
        };
        if decoded.get("error").is_some() {
            continue;
        }
        let Some(url) = decoded.get("url").and_then(|v| v.as_str()) else {
            continue;
        };
        let request_headers = decoded.get("headers").and_then(|h| {
            h.as_object().map(|obj| {
                obj.iter()
                    .filter_map(|(k, v)| Some((k.clone(), v.as_str()?.to_string())))
                    .collect::<HashMap<String, String>>()
            })
        });
        let mut m = meta.clone();
        m.extractor_id = Some("vidsrc".into());
        out.push(UrlResult {
            url: url.to_string(),
            format: StreamFormat::Hls,
            is_external: false,
            yt_id: None,
            error: None,
            label: format_label("vidsrc", "CloudStream Pro"),
            meta: m,
            request_headers,
        });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn finds_streamembed_extractor() {
        let config = config::default_config();
        let id = find_extractor_for_url("https://bullstream.example/embed/x", &config);
        assert_eq!(id, Some("streamembed"));
    }

    #[test]
    fn streamembed_fixture_yields_hls() {
        let html = fs::read_to_string("tests/fixtures/streamembed.html").unwrap();
        let meta = EmbedMeta {
            referer: Some("https://ref.example/".into()),
            ..Default::default()
        };
        let result = extract_embed_html("streamembed", &html, "https://bullstream.example/v/1").unwrap();
        let mapped = map_extract(result, "streamembed", &meta, "StreamEmbed").unwrap();
        assert_eq!(mapped.format, StreamFormat::Hls);
        assert!(!mapped.url.is_empty());
    }

    #[test]
    fn mixdrop_requires_mfp() {
        let config = config::default_config();
        assert!(find_extractor_for_url("https://mixdrop.example/e/x", &config).is_none());
        let mut c = config;
        c.insert("mediaFlowProxyUrl".into(), "https://mfp.example".into());
        assert_eq!(
            find_extractor_for_url("https://mixdrop.example/e/x", &c),
            Some("mixdrop")
        );
    }
}
