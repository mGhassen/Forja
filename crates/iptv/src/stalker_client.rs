//! Stalker / Ministra portal client — handshake → catalog → create_link.

use crate::xtream::{
    merge_orphan_categories, parse_section, ParsedCategory, ParsedSeriesEpisode, XtreamSection,
    XtreamStreamRow,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::time::Duration;

const UA: &str = "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3";
const X_UA: &str = "Model: MAG250; Link: WiFi";

#[derive(Debug, Deserialize)]
struct StalkerRequest {
    action: String,
    #[serde(default)]
    url: String,
    /// MAC address stored as username on the host.
    #[serde(default)]
    username: String,
    /// Optional serial / device_id (password slot).
    #[serde(default)]
    password: String,
    #[serde(default)]
    section: String,
    #[serde(default)]
    category_id: String,
    #[serde(default)]
    series_id: String,
    /// Raw `cmd` from get_ordered_list for create_link.
    #[serde(default)]
    cmd: String,
    #[serde(default)]
    timeout_secs: u64,
}

struct Session {
    portal_url: String,
    mac: String,
    serial: String,
    token: String,
    client: reqwest::Client,
}

pub fn request_json(request_json: &str) -> String {
    utils::engine_cancel::enter_job();
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        return handle.block_on(request_json_async(request_json));
    }
    match tokio::runtime::Runtime::new() {
        Ok(rt) => rt.block_on(request_json_async(request_json)),
        Err(e) => json!({ "error": e.to_string() }).to_string(),
    }
}

pub async fn request_json_async(request_json: &str) -> String {
    utils::engine_cancel::enter_job();
    match handle(request_json).await {
        Ok(v) => v.to_string(),
        Err(e) => json!({ "error": e }).to_string(),
    }
}

async fn handle(request_json: &str) -> Result<Value, String> {
    let req: StalkerRequest =
        serde_json::from_str(request_json).map_err(|e| format!("invalid request: {e}"))?;
    let timeout = Duration::from_secs(if req.timeout_secs == 0 {
        20
    } else {
        req.timeout_secs.clamp(1, 180)
    });
    let mut session = Session::connect(&req.url, &req.username, &req.password, timeout).await?;

    match req.action.as_str() {
        "login" => session.login().await,
        "catalog" => session.catalog(&req.section, timeout).await,
        "categories" => session.categories_only(&req.section, timeout).await,
        "streams" => {
            session
                .streams(&req.section, &req.category_id, timeout)
                .await
        }
        "series_episodes" => session.series_episodes(&req.series_id, timeout).await,
        "create_link" => session.create_link(&req.cmd, &req.section, timeout).await,
        other => Err(format!("unknown action: {other}")),
    }
}

impl Session {
    async fn connect(
        url: &str,
        mac: &str,
        serial: &str,
        timeout: Duration,
    ) -> Result<Self, String> {
        let portal_url = normalize_portal_url(url)?;
        let mac = normalize_mac(mac)?;
        let serial = if serial.trim().is_empty() {
            derive_serial(&mac)
        } else {
            serial.trim().to_string()
        };
        let client = reqwest::Client::builder()
            .timeout(timeout)
            .redirect(reqwest::redirect::Policy::limited(8))
            .cookie_store(true)
            .build()
            .map_err(|e| e.to_string())?;
        let mut session = Self {
            portal_url,
            mac,
            serial,
            token: String::new(),
            client,
        };
        session.handshake(timeout).await?;
        Ok(session)
    }

    fn cookie_header(&self) -> String {
        format!(
            "mac={}; stb_lang=en; timezone=Europe/London",
            urlencoding::encode(&self.mac)
        )
    }

    fn headers(&self) -> reqwest::header::HeaderMap {
        let mut h = reqwest::header::HeaderMap::new();
        h.insert(
            reqwest::header::USER_AGENT,
            UA.parse().unwrap_or_else(|_| reqwest::header::HeaderValue::from_static("MAG250")),
        );
        h.insert(
            reqwest::header::HeaderName::from_static("x-user-agent"),
            X_UA.parse().unwrap_or_else(|_| reqwest::header::HeaderValue::from_static("MAG250")),
        );
        if let Ok(v) = self.cookie_header().parse() {
            h.insert(reqwest::header::COOKIE, v);
        }
        if !self.token.is_empty() {
            if let Ok(v) = format!("Bearer {}", self.token).parse() {
                h.insert(reqwest::header::AUTHORIZATION, v);
            }
        }
        h
    }

    async fn get_js(&self, query: &str, timeout: Duration) -> Result<Value, String> {
        if utils::engine_cancel::is_requested() {
            return Err(utils::engine_cancel::cancelled_message().into());
        }
        let url = format!("{}?{}&JsHttpRequest=1-xml", self.portal_url, query);
        let resp = self
            .client
            .get(&url)
            .headers(self.headers())
            .timeout(timeout)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        let status = resp.status().as_u16();
        if !(200..300).contains(&status) {
            return Err(format!("HTTP {status}"));
        }
        let body = resp.text().await.map_err(|e| e.to_string())?;
        let root: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
        Ok(root.get("js").cloned().unwrap_or(root))
    }

    async fn handshake(&mut self, timeout: Duration) -> Result<(), String> {
        let js = self
            .get_js("type=stb&action=handshake", timeout)
            .await?;
        let token = js
            .get("token")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        if token.is_empty() {
            return Err("handshake_failed".into());
        }
        self.token = token;
        Ok(())
    }

    async fn login(&mut self) -> Result<Value, String> {
        let timeout = Duration::from_secs(15);
        let sn = urlencoding::encode(&self.serial);
        let js = self
            .get_js(
                &format!(
                    "type=stb&action=get_profile&hd=1&ver=ImageDescription:%200.2.18-250;\
                     ImageDate:%20Fri%20Feb%2015%2015:32:44%20EET%202018;\
                     PORTAL%20version:%205.1.0;API%20Version:%20JS%20API%20version:%20328;\
                     STB%20API%20version:%20134;Player%20Engine%20version:%200x566&\
                     num_banks=2&sn={sn}&stb_type=MAG250&client_type=STB&\
                     image_version=218&video_out=hdmi&device_id=&device_id2=&auth_second_step=0&\
                     hw_version=1.7-BD-00&not_valid_token=0"
                ),
                timeout,
            )
            .await?;
        let name = js
            .get("name")
            .or_else(|| js.get("fname"))
            .and_then(|v| v.as_str())
            .unwrap_or(&self.mac)
            .to_string();
        let expiry = js
            .get("expire_date")
            .or_else(|| js.get("phone"))
            .map(|v| match v {
                Value::String(s) => s.clone(),
                Value::Number(n) => n.to_string(),
                _ => String::new(),
            })
            .unwrap_or_default();
        Ok(json!({
            "user_info": {
                "username": name,
                "auth": "1",
                "status": "Active",
                "exp_date": expiry,
                "max_connections": "1",
                "active_cons": "0",
            }
        }))
    }

    async fn catalog(&mut self, section: &str, timeout: Duration) -> Result<Value, String> {
        let section = parse_section(section).ok_or_else(|| "invalid_section".to_string())?;
        let cats = self.fetch_categories(section, timeout).await?;
        let streams = self.fetch_all_streams(section, &cats, timeout).await?;
        let cats = merge_orphan_categories(cats, &streams);
        Ok(json!({ "categories": cats, "streams": streams }))
    }

    async fn categories_only(&mut self, section: &str, timeout: Duration) -> Result<Value, String> {
        let section = parse_section(section).ok_or_else(|| "invalid_section".to_string())?;
        let cats = self.fetch_categories(section, timeout).await?;
        Ok(json!({ "categories": cats }))
    }

    async fn streams(
        &mut self,
        section: &str,
        category_id: &str,
        timeout: Duration,
    ) -> Result<Value, String> {
        let section = parse_section(section).ok_or_else(|| "invalid_section".to_string())?;
        let streams = if category_id.is_empty() {
            let cats = self.fetch_categories(section, timeout).await?;
            self.fetch_all_streams(section, &cats, timeout).await?
        } else {
            self.fetch_ordered_list(section, category_id, timeout)
                .await?
        };
        Ok(json!({ "streams": streams }))
    }

    async fn fetch_categories(
        &mut self,
        section: XtreamSection,
        timeout: Duration,
    ) -> Result<Vec<ParsedCategory>, String> {
        let (ty, action) = match section {
            XtreamSection::Live => ("itv", "get_genres"),
            XtreamSection::Vod => ("vod", "get_categories"),
            XtreamSection::Series => ("series", "get_categories"),
        };
        let js = self
            .get_js(&format!("type={ty}&action={action}"), timeout)
            .await?;
        Ok(parse_stalker_categories(&js))
    }

    async fn fetch_all_streams(
        &mut self,
        section: XtreamSection,
        cats: &[ParsedCategory],
        timeout: Duration,
    ) -> Result<Vec<XtreamStreamRow>, String> {
        match section {
            XtreamSection::Live => {
                // Prefer get_all_channels when available.
                match self.get_js("type=itv&action=get_all_channels", timeout).await {
                    Ok(js) => {
                        let rows = parse_stalker_streams(&js, section);
                        if !rows.is_empty() {
                            return Ok(rows);
                        }
                    }
                    Err(_) => {}
                }
                let mut all = Vec::new();
                for c in cats {
                    if c.id.is_empty() || c.id == "*" {
                        continue;
                    }
                    let rows = self.fetch_ordered_list(section, &c.id, timeout).await?;
                    all.extend(rows);
                }
                Ok(all)
            }
            XtreamSection::Vod | XtreamSection::Series => {
                let mut all = Vec::new();
                let ids: Vec<String> = if cats.is_empty() {
                    vec!["*".into()]
                } else {
                    cats.iter().map(|c| c.id.clone()).collect()
                };
                for id in ids {
                    let rows = self.fetch_ordered_list(section, &id, timeout).await?;
                    all.extend(rows);
                }
                Ok(all)
            }
        }
    }

    async fn fetch_ordered_list(
        &mut self,
        section: XtreamSection,
        category_id: &str,
        timeout: Duration,
    ) -> Result<Vec<XtreamStreamRow>, String> {
        let (ty, cat_key) = match section {
            XtreamSection::Live => ("itv", "genre"),
            XtreamSection::Vod => ("vod", "category"),
            XtreamSection::Series => ("series", "category"),
        };
        let mut out = Vec::new();
        let mut page = 1u32;
        loop {
            let q = format!(
                "type={ty}&action=get_ordered_list&{cat_key}={}&force_ch_link_check=&fav=0&sortby=number&hd=0&p={page}",
                urlencoding::encode(category_id)
            );
            let js = self.get_js(&q, timeout).await?;
            let rows = parse_stalker_streams(&js, section);
            let total = js
                .get("total_items")
                .and_then(|v| v.as_u64().or_else(|| v.as_str().and_then(|s| s.parse().ok())))
                .unwrap_or(0);
            let max_page = js
                .get("max_page_items")
                .and_then(|v| v.as_u64().or_else(|| v.as_str().and_then(|s| s.parse().ok())))
                .unwrap_or(0);
            out.extend(rows);
            if max_page == 0 || out.len() as u64 >= total || page >= 50 {
                break;
            }
            page += 1;
        }
        Ok(out)
    }

    async fn series_episodes(
        &mut self,
        series_id: &str,
        timeout: Duration,
    ) -> Result<Value, String> {
        if series_id.is_empty() {
            return Ok(json!({ "episodes": [] }));
        }
        // series get_ordered_list with movie_id often returns seasons; try get_ordered_list seasons.
        let q = format!(
            "type=series&action=get_ordered_list&movie_id={}&season_id=0&episode_id=0&p=1",
            urlencoding::encode(series_id)
        );
        let js = self.get_js(&q, timeout).await?;
        let episodes = parse_stalker_episodes(&js);
        Ok(json!({ "episodes": episodes }))
    }

    async fn create_link(
        &mut self,
        cmd: &str,
        section: &str,
        timeout: Duration,
    ) -> Result<Value, String> {
        if cmd.trim().is_empty() {
            return Err("empty_cmd".into());
        }
        let ty = match parse_section(section).unwrap_or(XtreamSection::Live) {
            XtreamSection::Live => "itv",
            XtreamSection::Vod => "vod",
            XtreamSection::Series => "series",
        };
        let q = format!(
            "type={ty}&action=create_link&cmd={}&series=&forced_storage=undefined&disable_ad=0&download=0",
            urlencoding::encode(cmd)
        );
        let js = self.get_js(&q, timeout).await?;
        let stream_url = extract_stream_url(&js, cmd);
        if stream_url.is_empty() {
            return Err("create_link_failed".into());
        }
        Ok(json!({ "url": stream_url }))
    }
}

fn normalize_portal_url(url: &str) -> Result<String, String> {
    let mut u = url.trim().trim_end_matches('/').to_string();
    if u.is_empty() {
        return Err("empty url".into());
    }
    if !u.contains("://") {
        u = format!("http://{u}");
    }
    // Accept bare host, /c/, stalker_portal, or direct portal.php / load.php.
    let lower = u.to_ascii_lowercase();
    if lower.ends_with("portal.php") || lower.ends_with("load.php") {
        return Ok(u);
    }
    if lower.contains("/stalker_portal") {
        if lower.ends_with("/c") || lower.contains("/c/") {
            // strip /c/... → stalker_portal base + server/load.php
            if let Some(idx) = lower.find("/stalker_portal") {
                let base = &u[..idx + "/stalker_portal".len()];
                return Ok(format!("{base}/server/load.php"));
            }
        }
        return Ok(format!("{u}/server/load.php"));
    }
    if lower.ends_with("/c") || lower.contains("/c/") {
        let base = u
            .trim_end_matches('/')
            .trim_end_matches("/c")
            .trim_end_matches("/C");
        return Ok(format!("{base}/portal.php"));
    }
    Ok(format!("{u}/portal.php"))
}

fn normalize_mac(mac: &str) -> Result<String, String> {
    let cleaned: String = mac
        .chars()
        .filter(|c| c.is_ascii_hexdigit())
        .collect::<String>()
        .to_ascii_uppercase();
    if cleaned.len() != 12 {
        // Allow already-colon MAC of any length after filter fail — keep colon form if looks ok.
        let with_colons = mac.trim().to_ascii_uppercase();
        if with_colons.len() >= 17 {
            return Ok(with_colons);
        }
        return Err("invalid_mac".into());
    }
    let parts: Vec<&str> = cleaned
        .as_bytes()
        .chunks(2)
        .map(|c| std::str::from_utf8(c).unwrap_or(""))
        .collect();
    Ok(parts.join(":"))
}

fn derive_serial(mac: &str) -> String {
    let hex: String = mac.chars().filter(|c| c.is_ascii_hexdigit()).collect();
    format!("012{hex}N")
}

fn parse_stalker_categories(js: &Value) -> Vec<ParsedCategory> {
    let arr = if let Some(a) = js.as_array() {
        a.clone()
    } else if let Some(a) = js.get("data").and_then(|v| v.as_array()) {
        a.clone()
    } else {
        return vec![];
    };
    arr.iter()
        .filter_map(|v| {
            let o = v.as_object()?;
            let id = field_string(o, "id");
            if id.is_empty() || id == "*" {
                return None;
            }
            let name = {
                let n = field_string(o, "title");
                if n.is_empty() {
                    field_string(o, "caption")
                } else {
                    n
                }
            };
            Some(ParsedCategory {
                id,
                name: if name.is_empty() {
                    "Group".into()
                } else {
                    name
                },
            })
        })
        .collect()
}

fn parse_stalker_streams(js: &Value, section: XtreamSection) -> Vec<XtreamStreamRow> {
    let arr = js
        .get("data")
        .and_then(|v| v.as_array())
        .cloned()
        .or_else(|| js.as_array().cloned())
        .unwrap_or_default();
    arr.iter()
        .filter_map(|v| {
            let o = v.as_object()?;
            let id = {
                let i = field_string(o, "id");
                if i.is_empty() {
                    field_string(o, "ch_id")
                } else {
                    i
                }
            };
            if id.is_empty() {
                return None;
            }
            let name = {
                let n = field_string(o, "name");
                if n.is_empty() {
                    field_string(o, "title")
                } else {
                    n
                }
            };
            let icon = {
                let i = field_string(o, "logo");
                if i.is_empty() {
                    field_string(o, "screenshot_uri")
                } else {
                    i
                }
            };
            let category_id = {
                let g = field_string(o, "tv_genre_id");
                if g.is_empty() {
                    let c = field_string(o, "category_id");
                    if c.is_empty() {
                        field_string(o, "genre_id")
                    } else {
                        c
                    }
                } else {
                    g
                }
            };
            let cmd = field_string(o, "cmd");
            // Prefer cmd as stream_id for create_link; fall back to numeric id.
            let stream_id = if cmd.is_empty() { id } else { cmd.clone() };
            Some(XtreamStreamRow {
                stream_id,
                name,
                icon,
                category_id,
                container_ext: match section {
                    XtreamSection::Live => "ts".into(),
                    XtreamSection::Vod => "mp4".into(),
                    XtreamSection::Series => String::new(),
                },
                epg_channel_id: String::new(),
                kind: match section {
                    XtreamSection::Live => "live",
                    XtreamSection::Vod => "vod",
                    XtreamSection::Series => "series",
                }
                .into(),
            })
        })
        .collect()
}

fn parse_stalker_episodes(js: &Value) -> Vec<ParsedSeriesEpisode> {
    let arr = js
        .get("data")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let mut out = Vec::new();
    for (idx, v) in arr.iter().enumerate() {
        let Some(o) = v.as_object() else { continue };
        let id = {
            let cmd = field_string(o, "cmd");
            if !cmd.is_empty() {
                cmd
            } else {
                field_string(o, "id")
            }
        };
        if id.is_empty() {
            continue;
        }
        let title = {
            let t = field_string(o, "name");
            if t.is_empty() {
                field_string(o, "title")
            } else {
                t
            }
        };
        let season = field_string(o, "season_number").parse().unwrap_or(1);
        let ep_raw = {
            let s = field_string(o, "series_number");
            if s.is_empty() {
                field_string(o, "number")
            } else {
                s
            }
        };
        let episode = ep_raw.parse().unwrap_or((idx + 1) as i32);
        out.push(ParsedSeriesEpisode {
            id,
            title: if title.is_empty() {
                format!("Episode {episode}")
            } else {
                title
            },
            container_ext: "mp4".into(),
            season,
            episode,
            plot: field_string(o, "description"),
            image: field_string(o, "screenshot_uri"),
        });
    }
    out
}

fn extract_stream_url(js: &Value, fallback_cmd: &str) -> String {
    let cmd = js
        .get("cmd")
        .and_then(|v| v.as_str())
        .unwrap_or(fallback_cmd);
    let mut url = cmd.trim().to_string();
    for prefix in ["ffmpeg ", "ffrt ", "rtp "] {
        if let Some(rest) = url.strip_prefix(prefix) {
            url = rest.trim().to_string();
            break;
        }
    }
    // Some portals return "cmd URL" with space-separated options.
    if let Some(idx) = url.find("http://").or_else(|| url.find("https://")) {
        url = url[idx..].to_string();
    }
    url
}

fn field_string(o: &serde_json::Map<String, Value>, key: &str) -> String {
    o.get(key)
        .map(|v| match v {
            Value::String(s) => s.clone(),
            Value::Number(n) => n.to_string(),
            _ => v.to_string().trim_matches('"').to_string(),
        })
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_mac_colons() {
        assert_eq!(
            normalize_mac("00:1a:79:18:05:75").unwrap(),
            "00:1A:79:18:05:75"
        );
    }

    #[test]
    fn normalize_portal_c_path() {
        let u = normalize_portal_url("http://example.com:8080/c/").unwrap();
        assert_eq!(u, "http://example.com:8080/portal.php");
    }

    #[test]
    fn extract_ffmpeg_cmd() {
        let js = json!({ "cmd": "ffmpeg http://cdn/live.ts" });
        assert_eq!(
            extract_stream_url(&js, ""),
            "http://cdn/live.ts"
        );
    }

    #[test]
    fn parse_genres() {
        let js = json!([
            { "id": "1", "title": "News" },
            { "id": "*", "title": "All" }
        ]);
        let cats = parse_stalker_categories(&js);
        assert_eq!(cats.len(), 1);
        assert_eq!(cats[0].name, "News");
    }
}
