//! Anikoto.tv watch-page Ajax → MegaPlay / VidTube embeds → HLS (Anilili-style).
//!
//! Cascade (per slug + episode + sub/dub):
//! 1. GET `/watch/{slug}/ep-{n}` → `data-anime-id`
//! 2. GET `/ajax/episode/list/{id}` → episode `data-ids` token
//! 3. GET `/ajax/server/list?servers={token}` → server `data-link-id`s
//! 4. Prefer Vidstream (`e54`), then others in the matching audio section
//! 5. GET `/ajax/server?get={linkId}` → embed URL
//! 6. Unwrap via [`direct_embed_extract`] (getSources)

use std::collections::HashMap;

use regex::Regex;
use serde_json::Value;

use crate::extractors::common::{anime_get, StreamResultOut, DEFAULT_UA};
use crate::resolve::direct_embed::direct_embed_extract;

fn anikoto_tv() -> String {
    utils::provider_runtime::api_base("anikotoTv")
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "https://anikototv.to".to_string())
}

fn xhr_headers(referer: &str) -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), DEFAULT_UA.into()),
        ("Accept".into(), "application/json, text/plain, */*".into()),
        ("X-Requested-With".into(), "XMLHttpRequest".into()),
        ("Referer".into(), referer.into()),
    ])
}

fn html_headers(referer: &str) -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), DEFAULT_UA.into()),
        (
            "Accept".into(),
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".into(),
        ),
        ("Referer".into(), referer.into()),
    ])
}

fn html_attr(tag: &str, name: &str) -> String {
    let re = Regex::new(&format!(r#"(?i){name}\s*=\s*["']([^"']*)["']"#)).ok();
    re.and_then(|r| r.captures(tag))
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().to_string())
        .unwrap_or_default()
}

fn ajax_html_result(body: &str) -> Option<String> {
    let v: Value = serde_json::from_str(body).ok()?;
    match v.get("result") {
        Some(Value::String(s)) => Some(s.clone()),
        Some(Value::Object(o)) => o
            .get("html")
            .and_then(|h| h.as_str())
            .map(|s| s.to_string()),
        _ => None,
    }
}

/// Resolve playable streams from Anikoto.tv site servers for one episode.
///
/// Returns Megaplay / VidTube HLS hits (native). Empty when the site miss.
pub fn anikoto_site_streams(
    slug: &str,
    episode: i32,
    category: &str,
) -> Result<Vec<StreamResultOut>, String> {
    let slug = slug.trim().trim_matches('/');
    if slug.is_empty() || episode <= 0 {
        return Ok(vec![]);
    }
    let audio = if category.eq_ignore_ascii_case("dub") {
        "dub"
    } else {
        "sub"
    };
    let base = anikoto_tv();
    let watch_url = format!("{base}/watch/{slug}/ep-{episode}");

    let watch = anime_get(&watch_url, &html_headers(&format!("{base}/")), 15)?;
    if watch.status != 200 {
        return Ok(vec![]);
    }
    let anime_id = Regex::new(r#"(?i)data-anime-id\s*=\s*"(\d+)""#)
        .ok()
        .and_then(|r| r.captures(&watch.body))
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().to_string())
        .or_else(|| {
            // Fallback: `#watch-main data-id` / show_id (same numeric id).
            Regex::new(r#"id="watch-main"[^>]*data-id\s*=\s*"(\d+)""#)
                .ok()
                .and_then(|r| r.captures(&watch.body))
                .and_then(|c| c.get(1))
                .map(|m| m.as_str().to_string())
        });
    let Some(anime_id) = anime_id else {
        return Ok(vec![]);
    };

    let eps = anime_get(
        &format!("{base}/ajax/episode/list/{anime_id}"),
        &xhr_headers(&watch_url),
        15,
    )?;
    if eps.status != 200 {
        return Ok(vec![]);
    }
    let Some(ep_html) = ajax_html_result(&eps.body) else {
        return Ok(vec![]);
    };
    let Some(server_token) = episode_server_token(&ep_html, episode, audio) else {
        return Ok(vec![]);
    };

    let enc_token = urlencoding::encode(&server_token);
    let servers = anime_get(
        &format!("{base}/ajax/server/list?servers={enc_token}"),
        &xhr_headers(&watch_url),
        15,
    )?;
    if servers.status != 200 {
        return Ok(vec![]);
    }
    let Some(srv_html) = ajax_html_result(&servers.body) else {
        return Ok(vec![]);
    };
    let link_ids = server_link_ids(&srv_html, audio);
    if link_ids.is_empty() {
        return Ok(vec![]);
    }

    let mut out = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for link_id in link_ids {
        let enc = urlencoding::encode(&link_id);
        let resolved = anime_get(
            &format!("{base}/ajax/server?get={enc}"),
            &xhr_headers(&watch_url),
            15,
        );
        let Ok(resolved) = resolved else { continue };
        if resolved.status != 200 {
            continue;
        }
        let Ok(json) = serde_json::from_str::<Value>(&resolved.body) else {
            continue;
        };
        let url = json
            .pointer("/result/url")
            .or_else(|| json.get("url"))
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .trim();
        if url.is_empty() || !url.starts_with("http") {
            continue;
        }
        // Native unwrap for MegaPlay / VidWish / VidTube family only.
        if !is_unwrap_host(url) {
            continue;
        }
        let Ok(Some(mut hit)) = direct_embed_extract(url, Some(&format!("{base}/"))) else {
            continue;
        };
        if hit.url.is_empty() || !seen.insert(hit.url.clone()) {
            continue;
        }
        hit.provider = "anikoto".into();
        out.push(hit);
        // First playable (Vidstream-first order) is enough for the race winner;
        // still collect a couple more for the Source panel.
        if out.len() >= 3 {
            break;
        }
    }
    Ok(out)
}

fn is_unwrap_host(url: &str) -> bool {
    let u = url.to_lowercase();
    u.contains("megaplay")
        || u.contains("vidwish")
        || u.contains("vidtube")
        || u.contains("/stream/s-2/")
}

fn episode_server_token(ep_html: &str, episode: i32, audio: &str) -> Option<String> {
    let audio_attr = if audio == "dub" { "data-dub" } else { "data-sub" };
    let re = Regex::new(r"(?i)<a\b[^>]*>").ok()?;
    let mut fallback = None;
    for cap in re.captures_iter(ep_html) {
        let tag = cap.get(0)?.as_str();
        let num = html_attr(tag, "data-num").parse::<i32>().ok();
        let slug = html_attr(tag, "data-slug").parse::<i32>().ok();
        if num != Some(episode) && slug != Some(episode) {
            continue;
        }
        let flag = html_attr(tag, audio_attr);
        if !flag.is_empty() && flag != "1" {
            continue;
        }
        let ids = html_attr(tag, "data-ids");
        if ids.is_empty() {
            continue;
        }
        // Prefer exact audio flag when present.
        if flag == "1" {
            return Some(ids);
        }
        if fallback.is_none() {
            fallback = Some(ids);
        }
    }
    fallback
}

/// Ordered link ids: Vidstream (`e54`) first, then the rest in the audio section.
fn server_link_ids(srv_html: &str, audio: &str) -> Vec<String> {
    let section = audio_section(srv_html, audio).unwrap_or(srv_html);
    let re = Regex::new(
        r#"(?is)<li\b[^>]*\bdata-link-id=["'][^"']+["'][^>]*>.*?</li>"#,
    )
    .ok();
    let Some(re) = re else {
        return vec![];
    };
    let mut preferred = Vec::new();
    let mut rest = Vec::new();
    for cap in re.captures_iter(section) {
        let item = cap.get(0).map(|m| m.as_str()).unwrap_or("");
        let link = html_attr(item, "data-link-id");
        if link.is_empty() {
            continue;
        }
        let sv = html_attr(item, "data-sv-id").to_lowercase();
        let is_vidstream = sv == "e54" || item.to_lowercase().contains("vidstream");
        if is_vidstream {
            preferred.push(link);
        } else {
            rest.push(link);
        }
    }
    preferred.extend(rest);
    preferred
}

fn audio_section<'a>(html: &'a str, audio: &str) -> Option<&'a str> {
    let want = if audio == "dub" { "dub" } else { "sub" };
    let lower = html.to_lowercase();
    let marker = format!(r#"data-type="{want}""#);
    let marker_alt = format!(r#"data-type='{want}'"#);
    let start_rel = lower
        .find(&marker)
        .or_else(|| lower.find(&marker_alt))?;
    let after_tag = html[start_rel..].find('>')? + start_rel + 1;
    // Next sibling section starts at the next data-type= div (or EOF).
    let rest = &html[after_tag..];
    let rest_lower = rest.to_lowercase();
    let end_rel = ["data-type=\"", "data-type='"]
        .iter()
        .filter_map(|m| rest_lower.find(m))
        .min()
        .unwrap_or(rest.len());
    // Include only until the '<' before that next marker when present.
    let end = if end_rel < rest.len() {
        after_tag + rest[..end_rel].rfind('<').unwrap_or(end_rel)
    } else {
        after_tag + end_rel
    };
    Some(&html[after_tag..end])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn prefers_vidstream_link_order() {
        let html = r#"
        <div data-type="sub">
          <li data-link-id="aaa" data-sv-id="8e4">VidPlay-1</li>
          <li data-link-id="bbb" data-sv-id="e54">Vidstream-2</li>
          <li data-link-id="ccc" data-sv-id="323">HD-1</li>
        </div>
        <div data-type="dub">
          <li data-link-id="ddd" data-sv-id="e54">Vidstream-2</li>
        </div>
        "#;
        assert_eq!(server_link_ids(html, "sub"), vec!["bbb", "aaa", "ccc"]);
        assert_eq!(server_link_ids(html, "dub"), vec!["ddd"]);
    }

    #[test]
    fn episode_token_from_tag() {
        let html = r##"<a href="#" data-num="1" data-slug="1" data-sub="1" data-dub="1" data-ids="TOKEN1" class="active">
<a href="#" data-num="2" data-slug="2" data-sub="1" data-ids="TOKEN2">"##;
        assert_eq!(
            episode_server_token(html, 1, "sub").as_deref(),
            Some("TOKEN1")
        );
        assert_eq!(
            episode_server_token(html, 2, "sub").as_deref(),
            Some("TOKEN2")
        );
    }

    #[test]
    #[ignore = "network — Anikoto site scrape + Megaplay getSources"]
    fn dandadan_ep1_sub_resolves() {
        let out = anikoto_site_streams("dandadan-lzcmw", 1, "sub").expect("ok");
        assert!(!out.is_empty(), "expected at least one HLS hit");
        assert!(out[0].url.contains("m3u8") || !out[0].url.is_empty());
    }
}
