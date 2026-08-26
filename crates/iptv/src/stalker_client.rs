//! Stalker / Ministra portal client — handshake → catalog → create_link.
//!
//! Mirrors the shape of Lume's Swift `StalkerClient`: candidate middleware
//! endpoints are tried in order until one handshakes, the winning
//! (endpoint, token) pair is cached per `portal_origin|mac` for the life of
//! the process (catalog sync issues many separate `request_json` calls —
//! login / categories / streams / create_link — and re-handshaking every
//! one would be both slow and rude to the portal), a 401/403 clears the
//! cache and re-handshakes once before failing the request, and transient
//! gateway / transport failures (HTTP 5xx, timeouts, connection drops)
//! retry with short backoff so flaky CDNs don't surface as a Reload prompt.

use crate::xtream::{
    merge_orphan_categories, parse_section, ParsedCategory, ParsedSeriesEpisode, XtreamSection,
    XtreamStreamRow,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::sync::{Arc, LazyLock, Mutex};
use std::time::Duration;
use tokio::sync::RwLock;
use tokio::task::JoinSet;

const UA: &str = "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3";
const X_UA: &str = "Model: MAG250; Link: WiFi";

/// Ordered-list pages fetched concurrently during a VOD/series catalog
/// walk. Portals serve a fixed ~14-item page, so a large catalog is
/// hundreds to thousands of ~1-2s requests — only parallelism keeps that
/// inside a usable sync duration. Empirically portals tolerate ~8 parallel
/// middleware requests and start 503-rejecting above ~10; 6 leaves
/// headroom.
const WALK_CONCURRENCY: usize = 6;

/// Safety valve so a portal reporting a bogus `total_items` (or none at
/// all) can't page forever.
const MAX_WALK_PAGES: u32 = 2000;

/// Lume `StalkerClient.maxAttempts` — handshake and authorized requests
/// retry this many times on retriable failures before surfacing the error.
const TRANSIENT_MAX_ATTEMPTS: u32 = 3;

/// Backoff after failed attempt 1 / 2 (ms) before the next try. Short on
/// purpose: Cloudflare 520 / origin 502 usually recover in under a second,
/// and the Flutter catalog open keeps its spinner across the whole wait.
const TRANSIENT_BACKOFF_MS: [u64; 2] = [300, 800];

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
    /// Numeric ITV channel id (`ch_id`) for EPG — not the create_link cmd.
    #[serde(default)]
    channel_id: String,
    /// `get_short_epg` size; 0 → default 8.
    #[serde(default)]
    limit: u32,
    /// Bulk `get_epg_info` period in hours (guide). 0 → default 72.
    #[serde(default)]
    period: u32,
    #[serde(default)]
    timeout_secs: u64,
}

/// A successful handshake: the middleware endpoint that answered and the
/// bearer token it issued.
#[derive(Debug, Clone)]
struct Endpoint {
    url: String,
    token: String,
}

/// In-memory session cache keyed by `portal_origin|mac`, shared by every
/// `Session` in this process. A handshake pins both the winning endpoint
/// path (`portal.php` vs `server/load.php` vs `stalker_portal/...`) and the
/// bearer token; both are reused across the separate login / catalog /
/// streams / create_link calls a single sync issues. Tokens are
/// session-scoped and intentionally not persisted to disk — they expire,
/// and re-handshaking is cheap.
static SESSION_CACHE: LazyLock<Mutex<HashMap<String, Endpoint>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

#[derive(Clone)]
struct Session {
    /// `scheme://host:port` — no path.
    origin: String,
    /// `scheme://host:port/c/` — the `Referer` portals expect.
    referer: String,
    mac: String,
    serial: String,
    client: reqwest::Client,
    /// `origin|mac` — the session cache key.
    cache_key: String,
    /// Candidate middleware paths, ordered by how the user pasted the URL.
    candidate_paths: Arc<Vec<String>>,
    endpoint: Arc<RwLock<Option<Endpoint>>>,
}

struct OrderedPage {
    items: Vec<XtreamStreamRow>,
    total: Option<u64>,
    page_size: u32,
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
    let session = Session::connect(&req.url, &req.username, &req.password, timeout).await?;

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
        "epg" | "short_epg" => {
            session
                .epg(&req.channel_id, req.limit, timeout)
                .await
        }
        "epg_table" | "epg_bulk" => {
            session
                .epg_table(&req.channel_id, req.period, timeout)
                .await
        }
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
        let (origin, pasted_path) = split_origin_and_path(url)?;
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
        let cache_key = format!("{origin}|{mac}");
        let session = Self {
            referer: format!("{origin}/c/"),
            origin,
            mac,
            serial,
            client,
            cache_key,
            candidate_paths: Arc::new(candidate_paths(&pasted_path)),
            endpoint: Arc::new(RwLock::new(None)),
        };
        session.ensure_session(timeout, false).await?;
        Ok(session)
    }

    fn cookie_header(&self) -> String {
        format!(
            "mac={}; stb_lang=en; timezone=Europe/London",
            urlencoding::encode(&self.mac)
        )
    }

    // ── Session / handshake ────────────────────────────────────────────

    /// Returns the cached (endpoint, token), handshaking if none is cached
    /// (or `force_refresh` discards one first — used after a 401/403).
    async fn ensure_session(&self, timeout: Duration, force_refresh: bool) -> Result<Endpoint, String> {
        if !force_refresh {
            if let Some(ep) = self.cached_endpoint().await {
                return Ok(ep);
            }
        }
        self.clear_cached_endpoint();
        let ep = self.handshake(timeout).await?;
        self.store_endpoint(ep.clone()).await;
        Ok(ep)
    }

    async fn cached_endpoint(&self) -> Option<Endpoint> {
        if let Some(ep) = self.endpoint.read().await.clone() {
            return Some(ep);
        }
        let global = SESSION_CACHE.lock().unwrap().get(&self.cache_key).cloned();
        if let Some(ep) = &global {
            *self.endpoint.write().await = Some(ep.clone());
        }
        global
    }

    fn clear_cached_endpoint(&self) {
        SESSION_CACHE.lock().unwrap().remove(&self.cache_key);
    }

    async fn store_endpoint(&self, ep: Endpoint) {
        *self.endpoint.write().await = Some(ep.clone());
        SESSION_CACHE.lock().unwrap().insert(self.cache_key.clone(), ep);
    }

    /// Handshakes against each candidate endpoint in order until one
    /// returns a token, then primes the session with `get_profile` (some
    /// portals only activate the token once the profile is fetched).
    /// Each path retries on transient 5xx / transport errors before the
    /// next candidate is tried.
    async fn handshake(&self, timeout: Duration) -> Result<Endpoint, String> {
        let mut last_err = "handshake_failed".to_string();
        for path in self.candidate_paths.iter() {
            if utils::engine_cancel::is_requested() {
                return Err(utils::engine_cancel::cancelled_message().into());
            }
            let endpoint_url = format!("{}{path}", self.origin);
            let mut attempt = 0u32;
            loop {
                attempt += 1;
                if utils::engine_cancel::is_requested() {
                    return Err(utils::engine_cancel::cancelled_message().into());
                }
                match self
                    .perform_get(
                        &endpoint_url,
                        "type=stb&action=handshake&token=&JsHttpRequest=1-xml",
                        None,
                        timeout,
                    )
                    .await
                {
                    Ok(js) => {
                        let token = js
                            .get("token")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string();
                        if token.is_empty() {
                            last_err = "handshake_failed".into();
                            break;
                        }
                        // Prime the profile; ignore failures — many portals
                        // don't require it and some return a sparse profile
                        // that still authorizes.
                        let _ = self
                            .perform_get(
                                &endpoint_url,
                                "type=stb&action=get_profile&JsHttpRequest=1-xml",
                                Some(&token),
                                timeout,
                            )
                            .await;
                        return Ok(Endpoint {
                            url: endpoint_url,
                            token,
                        });
                    }
                    Err(e) => {
                        last_err = e.clone();
                        if is_retriable(&e) && attempt < TRANSIENT_MAX_ATTEMPTS {
                            tokio::time::sleep(Duration::from_millis(
                                transient_backoff_ms(attempt),
                            ))
                            .await;
                            continue;
                        }
                        break;
                    }
                }
            }
        }
        Err(last_err)
    }

    // ── Request plumbing ────────────────────────────────────────────────

    /// A single request attempt against a resolved endpoint. Sets the MAC
    /// cookie, bearer token and MAG headers the portal requires.
    /// `auth_failed` on a 401/403 lets the caller decide whether to
    /// re-handshake.
    async fn perform_get(
        &self,
        endpoint_url: &str,
        query: &str,
        token: Option<&str>,
        timeout: Duration,
    ) -> Result<Value, String> {
        if utils::engine_cancel::is_requested() {
            return Err(utils::engine_cancel::cancelled_message().into());
        }
        let url = format!("{endpoint_url}?{query}");
        let mut req = self
            .client
            .get(&url)
            .timeout(timeout)
            .header("User-Agent", UA)
            .header("X-User-Agent", X_UA)
            .header("Referer", self.referer.as_str())
            .header("Cookie", self.cookie_header());
        if let Some(t) = token {
            if !t.is_empty() {
                req = req.header("Authorization", format!("Bearer {t}"));
            }
        }
        let resp = req.send().await.map_err(|e| e.to_string())?;
        let status = resp.status().as_u16();
        if status == 401 || status == 403 {
            return Err("auth_failed".into());
        }
        if !(200..300).contains(&status) {
            return Err(format!("HTTP {status}"));
        }
        let body = resp.text().await.map_err(|e| e.to_string())?;
        let root: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
        Ok(root.get("js").cloned().unwrap_or(root))
    }

    /// Issues an authorized request, retrying once with a fresh handshake
    /// on a 401/403, and with short backoff on transient gateway / transport
    /// errors (Lume `StalkerClient.request` parity).
    async fn get_js(&self, query: &str, timeout: Duration) -> Result<Value, String> {
        let mut refreshed_auth = false;
        let mut attempt = 0u32;
        loop {
            attempt += 1;
            let ep = self.ensure_session(timeout, refreshed_auth).await?;
            match self
                .perform_get(&ep.url, query, Some(&ep.token), timeout)
                .await
            {
                Ok(v) => return Ok(v),
                Err(e) if e == "auth_failed" && !refreshed_auth => {
                    refreshed_auth = true;
                    continue;
                }
                Err(e) if is_retriable(&e) && attempt < TRANSIENT_MAX_ATTEMPTS => {
                    tokio::time::sleep(Duration::from_millis(transient_backoff_ms(attempt)))
                        .await;
                    continue;
                }
                Err(e) => return Err(e),
            }
        }
    }

    // MARK: - Profile / login

    async fn login(&self) -> Result<Value, String> {
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
        // Lume: `exp_date`; some panels misuse `phone` for the sub end date.
        // `expire_date` kept as a rare alias.
        let expiry = profile_expiry_raw(&js);
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

    // MARK: - Catalog

    async fn catalog(&self, section: &str, timeout: Duration) -> Result<Value, String> {
        let section = parse_section(section).ok_or_else(|| "invalid_section".to_string())?;
        let cats = self.fetch_categories(section, timeout).await?;
        let streams = self.fetch_all_streams(section, &cats, timeout).await?;
        let cats = merge_orphan_categories(cats, &streams);
        Ok(json!({ "categories": cats, "streams": streams }))
    }

    async fn categories_only(&self, section: &str, timeout: Duration) -> Result<Value, String> {
        let section = parse_section(section).ok_or_else(|| "invalid_section".to_string())?;
        let cats = self.fetch_categories(section, timeout).await?;
        Ok(json!({ "categories": cats }))
    }

    async fn streams(
        &self,
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

    /// Per-channel EPG — `get_short_epg` first, then `get_epg_info` fallback.
    /// Returns Xtream-shaped `{ epg_listings: [...] }` for the Dart parser.
    async fn epg(
        &self,
        channel_id: &str,
        limit: u32,
        timeout: Duration,
    ) -> Result<Value, String> {
        let ch = channel_id.trim();
        if ch.is_empty() {
            return Ok(json!({ "epg_listings": [] }));
        }
        let size = if limit == 0 { 8 } else { limit.clamp(1, 128) };
        let ch_enc = urlencoding::encode(ch);

        let short_q = format!(
            "type=itv&action=get_short_epg&ch_id={ch_enc}&size={size}&JsHttpRequest=1-xml"
        );
        if let Ok(js) = self.get_js(&short_q, timeout).await {
            let listings = parse_stalker_epg(&js, ch);
            if !listings.is_empty() {
                return Ok(json!({ "epg_listings": listings }));
            }
        }

        // Fall through to the period table (still per-channel extract).
        self.epg_table(ch, 72, timeout).await
    }

    /// Full guide listings via Mag `get_epg_info&period=` (short EPG is only
    /// a handful of near-now rows). When [channel_id] is set, returns that
    /// channel's rows as `epg_listings`. When empty, returns the whole map as
    /// `channels: { "<ch_id>": [ listings... ] }` for session caching.
    async fn epg_table(
        &self,
        channel_id: &str,
        period: u32,
        timeout: Duration,
    ) -> Result<Value, String> {
        let hours = if period == 0 {
            72
        } else {
            period.clamp(6, 168)
        };
        let bulk_q = format!(
            "type=itv&action=get_epg_info&period={hours}&JsHttpRequest=1-xml"
        );
        let js = self.get_js(&bulk_q, timeout).await?;
        let ch = channel_id.trim();
        if !ch.is_empty() {
            let listings = parse_stalker_epg(&js, ch);
            return Ok(json!({ "epg_listings": listings }));
        }
        let map = extract_stalker_epg_channel_map(&js);
        let mut channels = serde_json::Map::new();
        for (id, items) in map {
            let listings = parse_stalker_epg(&Value::Array(items), &id);
            if !listings.is_empty() {
                channels.insert(id, Value::Array(listings));
            }
        }
        Ok(json!({ "channels": channels }))
    }

    async fn fetch_categories(
        &self,
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
        &self,
        section: XtreamSection,
        cats: &[ParsedCategory],
        timeout: Duration,
    ) -> Result<Vec<XtreamStreamRow>, String> {
        match section {
            XtreamSection::Live => {
                // Prefer get_all_channels when available.
                if let Ok(js) = self.get_js("type=itv&action=get_all_channels", timeout).await {
                    let rows = parse_stalker_streams(&js, section);
                    if !rows.is_empty() {
                        return Ok(rows);
                    }
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

    /// Fetches every page of a `get_ordered_list` (used by itv/vod/series
    /// alike). The first page is fetched alone — it validates the session
    /// and reports the totals that size the walk — then the remaining
    /// pages are fetched `WALK_CONCURRENCY` at a time.
    async fn fetch_ordered_list(
        &self,
        section: XtreamSection,
        category_id: &str,
        timeout: Duration,
    ) -> Result<Vec<XtreamStreamRow>, String> {
        let (ty, cat_key) = match section {
            XtreamSection::Live => ("itv", "genre"),
            XtreamSection::Vod => ("vod", "category"),
            XtreamSection::Series => ("series", "category"),
        };
        let first = self.fetch_ordered_page(ty, cat_key, category_id, 1, timeout).await?;
        if first.items.is_empty() {
            return Ok(first.items);
        }
        let page_size = if first.page_size > 0 { first.page_size } else { 14 };

        let Some(total) = first.total else {
            // No reported total (rare): page serially until a short page.
            return self
                .sequential_walk_tail(ty, cat_key, category_id, page_size, first.items, timeout)
                .await;
        };

        let last_page = ((total as f64) / (page_size as f64)).ceil().max(1.0) as u32;
        let last_page = last_page.min(MAX_WALK_PAGES);
        if last_page <= 1 {
            return Ok(first.items);
        }
        let tail = self
            .parallel_walk_tail(ty, cat_key, category_id, 2, last_page, timeout)
            .await?;
        let mut out = first.items;
        out.extend(tail);
        Ok(out)
    }

    async fn fetch_ordered_page(
        &self,
        ty: &str,
        cat_key: &str,
        category_id: &str,
        page: u32,
        timeout: Duration,
    ) -> Result<OrderedPage, String> {
        let q = format!(
            "type={ty}&action=get_ordered_list&{cat_key}={}&force_ch_link_check=&fav=0&sortby=number&hd=0&p={page}",
            urlencoding::encode(category_id)
        );
        let js = self.get_js(&q, timeout).await?;
        let section = match ty {
            "itv" => XtreamSection::Live,
            "vod" => XtreamSection::Vod,
            _ => XtreamSection::Series,
        };
        let items = parse_stalker_streams(&js, section);
        let total = js.get("total_items").and_then(|v| {
            v.as_u64()
                .or_else(|| v.as_str().and_then(|s| s.parse().ok()))
        });
        let page_size = js
            .get("max_page_items")
            .and_then(|v| {
                v.as_u64()
                    .or_else(|| v.as_str().and_then(|s| s.parse().ok()))
            })
            .unwrap_or(0) as u32;
        Ok(OrderedPage {
            items,
            total,
            page_size,
        })
    }

    /// Fetches pages `first_page..=last_page`, `WALK_CONCURRENCY` at a
    /// time, and reassembles them in page order. A page failing mid-walk
    /// (after `get_js`'s own auth-retry) doesn't discard pages already
    /// fetched — a large catalog is hundreds of requests deep by then — it
    /// just leaves a gap, matching Lume's "keep what we got" behavior.
    async fn parallel_walk_tail(
        &self,
        ty: &str,
        cat_key: &str,
        category_id: &str,
        first_page: u32,
        last_page: u32,
        timeout: Duration,
    ) -> Result<Vec<XtreamStreamRow>, String> {
        fn spawn_page(
            set: &mut JoinSet<(u32, Result<OrderedPage, String>)>,
            session: &Session,
            ty: &str,
            cat_key: &str,
            category_id: &str,
            page: u32,
            timeout: Duration,
        ) {
            let session = session.clone();
            let ty = ty.to_string();
            let cat_key = cat_key.to_string();
            let category_id = category_id.to_string();
            set.spawn(async move {
                let r = session
                    .fetch_ordered_page(&ty, &cat_key, &category_id, page, timeout)
                    .await;
                (page, r)
            });
        }

        let mut set: JoinSet<(u32, Result<OrderedPage, String>)> = JoinSet::new();
        let mut next_page = first_page;
        let initial = WALK_CONCURRENCY.min((last_page - first_page + 1) as usize);
        for _ in 0..initial {
            spawn_page(&mut set, self, ty, cat_key, category_id, next_page, timeout);
            next_page += 1;
        }

        let mut pages_out: BTreeMap<u32, Vec<XtreamStreamRow>> = BTreeMap::new();
        while let Some(joined) = set.join_next().await {
            if utils::engine_cancel::is_requested() {
                set.abort_all();
                return Err(utils::engine_cancel::cancelled_message().into());
            }
            if let Ok((page, Ok(result))) = joined {
                pages_out.insert(page, result.items);
            }
            // A page error (network / join panic) just leaves that page's
            // slice out of the walk instead of failing the whole catalog.
            if next_page <= last_page {
                spawn_page(&mut set, self, ty, cat_key, category_id, next_page, timeout);
                next_page += 1;
            }
        }
        Ok(pages_out.into_values().flatten().collect())
    }

    /// Serial page walk used when the portal doesn't report `total_items`,
    /// so the end of the list is only discoverable by hitting a short page.
    async fn sequential_walk_tail(
        &self,
        ty: &str,
        cat_key: &str,
        category_id: &str,
        page_size: u32,
        seed: Vec<XtreamStreamRow>,
        timeout: Duration,
    ) -> Result<Vec<XtreamStreamRow>, String> {
        let mut all = seed;
        let mut page = 2u32;
        while page <= MAX_WALK_PAGES {
            if utils::engine_cancel::is_requested() {
                return Err(utils::engine_cancel::cancelled_message().into());
            }
            let result = match self
                .fetch_ordered_page(ty, cat_key, category_id, page, timeout)
                .await
            {
                Ok(r) => r,
                Err(_) => break,
            };
            let got = result.items.len() as u32;
            all.extend(result.items);
            if got < page_size.max(1) {
                break;
            }
            page += 1;
        }
        Ok(all)
    }

    // MARK: - Series episodes

    async fn series_episodes(&self, series_id: &str, timeout: Duration) -> Result<Value, String> {
        if series_id.is_empty() {
            return Ok(json!({ "episodes": [] }));
        }
        let q = format!(
            "type=series&action=get_ordered_list&movie_id={}&season_id=0&episode_id=0&p=1",
            urlencoding::encode(series_id)
        );
        let js = self.get_js(&q, timeout).await?;
        let episodes = parse_stalker_episodes(&js);
        Ok(json!({ "episodes": episodes }))
    }

    // MARK: - Stream resolution

    async fn create_link(&self, cmd: &str, section: &str, timeout: Duration) -> Result<Value, String> {
        if cmd.trim().is_empty() {
            return Err("empty_cmd".into());
        }
        let ty = match parse_section(section).unwrap_or(XtreamSection::Live) {
            XtreamSection::Live => "itv",
            XtreamSection::Vod => "vod",
            XtreamSection::Series => "series",
        };
        let mut q = format!(
            "type={ty}&action=create_link&cmd={}&series=&forced_storage=undefined&disable_ad=0&download=0",
            urlencoding::encode(cmd)
        );
        for (k, v) in forwarded_query_items(cmd) {
            q.push('&');
            q.push_str(&urlencoding::encode(&k));
            q.push('=');
            q.push_str(&urlencoding::encode(&v));
        }
        let js = self.get_js(&q, timeout).await?;
        let stream_url = extract_stream_url(&js, cmd);
        if stream_url.is_empty() {
            return Err("create_link_failed".into());
        }
        if has_empty_stream_param(&stream_url) {
            // The portal minted a link without a channel id — unplayable
            // (405s). Fail here rather than letting every engine burn
            // through it.
            return Err("no_stream_url".into());
        }
        Ok(json!({ "url": stream_url }))
    }
}

// ── URL / endpoint helpers ───────────────────────────────────────────────

/// Reduces a user-pasted portal URL to `scheme://host:port` plus the
/// (lowercased) path they pasted — the path is only used as a hint for
/// [`candidate_paths`], never dereferenced directly, since portals expose
/// the API at a handful of well-known paths regardless of what page the
/// user copied the URL from.
fn split_origin_and_path(raw: &str) -> Result<(String, String), String> {
    let mut s = raw.trim().to_string();
    if s.is_empty() {
        return Err("empty url".into());
    }
    if !s.contains("://") {
        s = format!("http://{s}");
    }
    let scheme_end = s.find("://").ok_or_else(|| "invalid_url".to_string())?;
    let scheme = &s[..scheme_end];
    let after_scheme = &s[scheme_end + 3..];
    let path_start = after_scheme
        .find(['/', '?', '#'])
        .unwrap_or(after_scheme.len());
    let host_port = after_scheme[..path_start].trim_end_matches('/');
    if host_port.is_empty() {
        return Err("invalid_url".into());
    }
    let rest = &after_scheme[path_start..];
    let path_only = rest.split(['?', '#']).next().unwrap_or("");
    let origin = format!("{scheme}://{host_port}");
    Ok((origin, path_only.to_string()))
}

/// Candidate middleware endpoint paths, in the order the handshake should
/// try them. If the pasted path already names an exact `portal.php` /
/// `load.php` endpoint, that exact path is tried first; otherwise (or in
/// addition), the standard Ministra layouts are tried in an order picked
/// by whether the pasted path hints at a `/stalker_portal/` install.
fn candidate_paths(pasted_path: &str) -> Vec<String> {
    let lower = pasted_path.to_ascii_lowercase();
    let mut out = Vec::new();
    if !pasted_path.is_empty() && (lower.ends_with("portal.php") || lower.ends_with("load.php")) {
        out.push(pasted_path.to_string());
    }
    let defaults: [&str; 3] = if lower.contains("stalker_portal") {
        ["/stalker_portal/server/load.php", "/portal.php", "/server/load.php"]
    } else {
        ["/portal.php", "/server/load.php", "/stalker_portal/server/load.php"]
    };
    for p in defaults {
        if !out.iter().any(|existing| existing.as_str() == p) {
            out.push(p.to_string());
        }
    }
    out
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

/// Milliseconds to sleep after a failed attempt before the next try.
fn transient_backoff_ms(failed_attempt: u32) -> u64 {
    let idx = (failed_attempt.saturating_sub(1) as usize).min(TRANSIENT_BACKOFF_MS.len() - 1);
    TRANSIENT_BACKOFF_MS[idx]
}

/// Whether a `perform_get` error is worth retrying — Lume `StalkerError.isRetriable`
/// (`networkError` + HTTP ≥ 500). Auth / empty-token / cancel / JSON decode are not.
fn is_retriable(err: &str) -> bool {
    if let Some(code) = err
        .strip_prefix("HTTP ")
        .and_then(|s| s.parse::<u16>().ok())
    {
        return code >= 500;
    }
    if err == "auth_failed"
        || err == "handshake_failed"
        || err == "cancelled"
        || err.contains("cancel")
    {
        return false;
    }
    // serde_json::Error Display is typically "… at line N column M"
    if err.contains(" at line ") || err.contains("expected ") || err.contains("EOF while parsing")
    {
        return false;
    }
    // reqwest transport / timeout / DNS / TLS
    let lower = err.to_ascii_lowercase();
    lower.contains("timeout")
        || lower.contains("timed out")
        || lower.contains("connection")
        || lower.contains("dns")
        || lower.contains("tls")
        || lower.contains("reset")
        || lower.contains("broken pipe")
        || lower.contains("error sending request")
        || lower.contains("error decoding response body")
}

// ── create_link helpers ───────────────────────────────────────────────────

/// Query parameters excluded when forwarding a direct-URL `cmd`'s query
/// string onto `create_link` — the portal derives these itself (a stale
/// `mac`/token by playback time), or they'd collide with `create_link`'s
/// own request parameters.
const EXCLUDED_FORWARD_PARAMS: [&str; 7] = [
    "mac",
    "play_token",
    "token",
    "type",
    "action",
    "cmd",
    "jshttprequest",
];

/// Extracts a playable URL from a `create_link` `cmd` (or a raw cmd used
/// as its own probe target). Portals commonly prefix the URL with an
/// engine token (`ffmpeg `, `ffrt `, `rtp `) and may append params after a
/// space, so the first `http(s)` token is taken rather than trusting the
/// whole string.
fn resolved_url_from_cmd(raw: &str) -> Option<String> {
    let trimmed = raw.trim();
    let idx = trimmed.find("http://").or_else(|| trimmed.find("https://"))?;
    let rest = &trimmed[idx..];
    let url = rest.split_whitespace().next().unwrap_or(rest);
    Some(url.to_string())
}

/// Query parameters embedded in a direct-URL `cmd`, re-exposed as
/// top-level `create_link` parameters. Xtream-UI-style Stalker emulations
/// hand out channel cmds that are full stream URLs
/// (`ffmpeg http://host/play/live.php?mac=…&stream=933136&extension=ts&play_token=…`)
/// and their `create_link` never parses the percent-encoded `cmd` it
/// receives — it reads `stream` / `extension` from the request's own query
/// string and answers with an empty `stream=` (an unplayable URL) when
/// they're missing. Forwarding the embedded parameters satisfies those
/// portals, while genuine Ministra portals resolve the full `cmd` and
/// ignore the extras.
fn forwarded_query_items(cmd: &str) -> Vec<(String, String)> {
    let Some(url) = resolved_url_from_cmd(cmd) else {
        return vec![];
    };
    if !(url.starts_with("http://") || url.starts_with("https://")) {
        return vec![];
    }
    let Some(q_idx) = url.find('?') else {
        return vec![];
    };
    let query = &url[q_idx + 1..];
    let excluded: HashSet<&str> = EXCLUDED_FORWARD_PARAMS.into_iter().collect();
    let mut out = Vec::new();
    for pair in query.split('&') {
        let Some((k, v)) = pair.split_once('=') else {
            continue;
        };
        if excluded.contains(k.to_ascii_lowercase().as_str()) {
            continue;
        }
        let key = urlencoding::decode(k).map(|c| c.into_owned()).unwrap_or_else(|_| k.to_string());
        let value = urlencoding::decode(v).map(|c| c.into_owned()).unwrap_or_else(|_| v.to_string());
        out.push((key, value));
    }
    out
}

/// True when a resolved stream URL carries an empty `stream=` query param
/// — the portal minted a link without a channel id, which the server
/// answers with HTTP 405.
fn has_empty_stream_param(url: &str) -> bool {
    let Some(idx) = url.find('?') else { return false };
    url[idx + 1..]
        .split('&')
        .any(|pair| pair == "stream=" || pair.split_once('=') == Some(("stream", "")))
}

/// Pull subscription end from `get_profile` — Lume reads `exp_date`; some
/// Ministra panels only put the date in `phone`.
fn profile_expiry_raw(js: &Value) -> String {
    for key in ["exp_date", "expire_date"] {
        if let Some(s) = json_scalar_string(js.get(key)) {
            if !s.trim().is_empty() {
                return s;
            }
        }
    }
    json_scalar_string(js.get("phone"))
        .filter(|s| looks_like_expiry(s))
        .unwrap_or_default()
}

fn json_scalar_string(v: Option<&Value>) -> Option<String> {
    match v? {
        Value::String(s) => Some(s.clone()),
        Value::Number(n) => Some(n.to_string()),
        _ => None,
    }
}

/// Avoid treating a literal phone number as an end date.
fn looks_like_expiry(raw: &str) -> bool {
    let s = raw.trim();
    if s.is_empty() {
        return false;
    }
    if s.chars().all(|c| c.is_ascii_digit()) {
        return s.len() >= 9; // unix seconds / millis
    }
    let lower = s.to_ascii_lowercase();
    if lower.contains('/') || lower.contains('-') {
        return true;
    }
    const MONTHS: &[&str] = &[
        "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct",
        "nov", "dec", "january", "february", "march", "april", "june", "july",
        "august", "september", "october", "november", "december",
    ];
    MONTHS.iter().any(|m| lower.contains(m))
}

// ── Response parsing ───────────────────────────────────────────────────────

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
            // Keep the numeric ITV id in epg_channel_id for get_short_epg.
            let stream_id = if cmd.is_empty() {
                id.clone()
            } else {
                cmd.clone()
            };
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
                epg_channel_id: id,
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

/// Normalize Stalker EPG payloads into Xtream-shaped listing objects.
fn parse_stalker_epg(js: &Value, channel_id: &str) -> Vec<Value> {
    let items = extract_stalker_epg_items(js, channel_id);
    let mut out = Vec::with_capacity(items.len());
    for item in items {
        let Some(o) = item.as_object() else { continue };
        let title = {
            let t = field_string(o, "name");
            if !t.is_empty() {
                t
            } else {
                let t = field_string(o, "title");
                if !t.is_empty() {
                    t
                } else {
                    field_string(o, "progname")
                }
            }
        };
        let description = {
            let d = field_string(o, "descr");
            if !d.is_empty() {
                d
            } else {
                let d = field_string(o, "description");
                if !d.is_empty() {
                    d
                } else {
                    let d = field_string(o, "desc");
                    if !d.is_empty() {
                        d
                    } else {
                        field_string(o, "short_description")
                    }
                }
            }
        };
        // Prefer real epochs — Mag `time` is often `YYYY-MM-DD HH:MM:SS`.
        let start_epoch =
            stalker_epg_ts(o, &["start_timestamp", "from", "start", "time"]);
        let mut stop_epoch =
            stalker_epg_ts(o, &["stop_timestamp", "to", "end", "stop", "time_to"]);
        if stop_epoch.is_none() {
            if let (Some(s), Some(dur)) = (start_epoch, stalker_epg_duration(o)) {
                stop_epoch = Some(s + dur);
            }
        }

        let start_str = stalker_epg_time_str(o, &["time", "start_time", "correct", "start"]);
        let stop_str = stalker_epg_time_str(o, &["time_to", "end_time", "stop", "end"]);

        let mut listing = json!({
            "title": title,
            "description": description,
        });
        let obj = listing.as_object_mut().unwrap();
        match (start_epoch, stop_epoch) {
            (Some(start), Some(stop)) if stop > start => {
                obj.insert("start_timestamp".into(), json!(start.to_string()));
                obj.insert("stop_timestamp".into(), json!(stop.to_string()));
            }
            _ => match (start_str, stop_str) {
                (Some(start), Some(stop)) if start != stop => {
                    // Wall-clock strings — Dart parses as local (Mag convention).
                    obj.insert("start".into(), json!(start));
                    obj.insert("stop".into(), json!(stop));
                }
                (Some(start), None) => {
                    if let Some(dur) = stalker_epg_duration(o) {
                        // Keep start string; Dart needs stop — fall back to epoch math
                        // only when start was also numeric (handled above).
                        let _ = (start, dur);
                    }
                    continue;
                }
                _ => continue,
            },
        }
        out.push(listing);
    }
    out.sort_by(|a, b| {
        let sa = epg_sort_key(a);
        let sb = epg_sort_key(b);
        sa.cmp(&sb)
    });
    out
}

fn epg_sort_key(v: &Value) -> String {
    v.get("start_timestamp")
        .and_then(|x| x.as_str())
        .or_else(|| v.get("start").and_then(|x| x.as_str()))
        .unwrap_or("")
        .to_string()
}

fn extract_stalker_epg_items(js: &Value, channel_id: &str) -> Vec<Value> {
    if let Some(arr) = js.as_array() {
        return arr.clone();
    }
    let Some(obj) = js.as_object() else {
        return Vec::new();
    };
    if let Some(arr) = obj.get("epg").and_then(|v| v.as_array()) {
        return arr.clone();
    }
    // `get_epg_info` often wraps a channel→rows map in `data`.
    if let Some(data) = obj.get("data") {
        if let Some(arr) = data.as_array() {
            return arr.clone();
        }
        if let Some(map) = data.as_object() {
            if !channel_id.is_empty() {
                if let Some(arr) = map.get(channel_id).and_then(|v| v.as_array()) {
                    return arr.clone();
                }
            }
        }
    }
    // Bulk map at root: `{ "<ch_id>": [ ... ], ... }`
    if !channel_id.is_empty() {
        if let Some(arr) = obj.get(channel_id).and_then(|v| v.as_array()) {
            return arr.clone();
        }
    }
    Vec::new()
}

fn extract_stalker_epg_channel_map(js: &Value) -> Vec<(String, Vec<Value>)> {
    let mut out = Vec::new();
    let Some(obj) = js.as_object() else {
        return out;
    };
    let map = obj
        .get("data")
        .and_then(|v| v.as_object())
        .unwrap_or(obj);
    for (k, v) in map {
        if let Some(arr) = v.as_array() {
            if !arr.is_empty() {
                out.push((k.clone(), arr.clone()));
            }
        }
    }
    out
}

fn stalker_epg_ts(o: &serde_json::Map<String, Value>, keys: &[&str]) -> Option<i64> {
    for key in keys {
        let Some(v) = o.get(*key) else { continue };
        if let Some(n) = v.as_i64() {
            return Some(normalize_epoch(n));
        }
        if let Some(n) = v.as_u64() {
            return Some(normalize_epoch(n as i64));
        }
        if let Some(s) = v.as_str() {
            let t = s.trim();
            if let Ok(n) = t.parse::<i64>() {
                return Some(normalize_epoch(n));
            }
        }
    }
    None
}

fn stalker_epg_time_str(o: &serde_json::Map<String, Value>, keys: &[&str]) -> Option<String> {
    for key in keys {
        let s = field_string(o, key);
        let t = s.trim();
        if t.is_empty() {
            continue;
        }
        // Skip pure epochs — those go through stalker_epg_ts.
        if t.chars().all(|c| c.is_ascii_digit()) {
            continue;
        }
        if t.contains('-') || t.contains(':') {
            return Some(t.to_string());
        }
    }
    None
}

fn stalker_epg_duration(o: &serde_json::Map<String, Value>) -> Option<i64> {
    for key in ["duration", "prog_duration", "length"] {
        let Some(v) = o.get(key) else { continue };
        let n = v
            .as_i64()
            .or_else(|| v.as_u64().map(|u| u as i64))
            .or_else(|| v.as_str().and_then(|s| s.trim().parse().ok()))?;
        if n > 0 && n < 86_400 {
            return Some(n);
        }
    }
    None
}

fn normalize_epoch(n: i64) -> i64 {
    if n > 10_000_000_000 {
        n / 1000
    } else {
        n
    }
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
    if let Some(idx) = url.find("http://").or_else(|| url.find("https://")) {
        url = url[idx..].to_string();
    }
    // Params after a space aren't part of the URL.
    url.split_whitespace().next().unwrap_or("").to_string()
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
    fn extract_ffmpeg_cmd() {
        let js = json!({ "cmd": "ffmpeg http://cdn/live.ts" });
        assert_eq!(extract_stream_url(&js, ""), "http://cdn/live.ts");
    }

    #[test]
    fn extract_cmd_drops_trailing_params_after_space() {
        let js = json!({ "cmd": "ffmpeg http://cdn/live.ts extra=1" });
        assert_eq!(extract_stream_url(&js, ""), "http://cdn/live.ts");
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

    #[test]
    fn live_stream_keeps_numeric_epg_channel_id() {
        let js = json!({
            "data": [{
                "id": "42",
                "name": "BBC",
                "cmd": "ffmpeg http://cdn/live.ts",
                "tv_genre_id": "1",
                "logo": "http://i"
            }]
        });
        let rows = parse_stalker_streams(&js, XtreamSection::Live);
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].stream_id, "ffmpeg http://cdn/live.ts");
        assert_eq!(rows[0].epg_channel_id, "42");
    }

    #[test]
    fn parse_short_epg_array() {
        let js = json!([
            {
                "name": "News at Ten",
                "descr": "Tonight",
                "start_timestamp": 1_700_000_000i64,
                "stop_timestamp": 1_700_003_600i64
            }
        ]);
        let listings = parse_stalker_epg(&js, "42");
        assert_eq!(listings.len(), 1);
        assert_eq!(listings[0]["title"], "News at Ten");
        assert_eq!(listings[0]["description"], "Tonight");
        assert_eq!(listings[0]["start_timestamp"], "1700000000");
        assert_eq!(listings[0]["stop_timestamp"], "1700003600");
    }

    #[test]
    fn parse_mag_time_strings() {
        let js = json!([{
            "name": "Petits plats",
            "descr": "Recettes",
            "time": "2026-08-26 10:45:00",
            "time_to": "2026-08-26 10:50:00",
            "duration": 300
        }]);
        let listings = parse_stalker_epg(&js, "526153");
        assert_eq!(listings.len(), 1);
        assert_eq!(listings[0]["title"], "Petits plats");
        assert_eq!(listings[0]["start"], "2026-08-26 10:45:00");
        assert_eq!(listings[0]["stop"], "2026-08-26 10:50:00");
    }

    #[test]
    fn parse_epg_info_data_map_by_channel() {
        let js = json!({
            "data": {
                "526153": [{
                    "name": "TF1 Now",
                    "start_timestamp": 1_700_000_000i64,
                    "stop_timestamp": 1_700_003_600i64
                }],
                "99": [{
                    "name": "Other",
                    "start_timestamp": 1_700_000_000i64,
                    "stop_timestamp": 1_700_001_800i64
                }]
            }
        });
        let listings = parse_stalker_epg(&js, "526153");
        assert_eq!(listings.len(), 1);
        assert_eq!(listings[0]["title"], "TF1 Now");
    }

    #[test]
    fn parse_bulk_epg_keyed_by_channel() {
        let js = json!({
            "42": [{
                "title": "Match",
                "start_timestamp": "1700000000",
                "duration": 7200
            }],
            "99": [{
                "title": "Other",
                "start_timestamp": "1700000000",
                "duration": 3600
            }]
        });
        let listings = parse_stalker_epg(&js, "42");
        assert_eq!(listings.len(), 1);
        assert_eq!(listings[0]["title"], "Match");
        assert_eq!(listings[0]["stop_timestamp"], "1700007200");
    }

    #[test]
    fn parse_epg_ms_epoch_normalizes() {
        let js = json!([{
            "name": "Late",
            "from": 1_700_000_000_000i64,
            "to": 1_700_003_600_000i64
        }]);
        let listings = parse_stalker_epg(&js, "");
        assert_eq!(listings[0]["start_timestamp"], "1700000000");
        assert_eq!(listings[0]["stop_timestamp"], "1700003600");
    }

    #[test]
    fn profile_expiry_prefers_exp_date_over_phone() {
        let js = json!({
            "exp_date": "1790000000",
            "phone": "February 16, 2027",
        });
        assert_eq!(profile_expiry_raw(&js), "1790000000");
    }

    #[test]
    fn profile_expiry_falls_back_to_phone_when_date_like() {
        let js = json!({ "phone": "February 16, 2027" });
        assert_eq!(profile_expiry_raw(&js), "February 16, 2027");
    }

    #[test]
    fn profile_expiry_ignores_literal_phone_number() {
        let js = json!({ "phone": "+44 7700 900123" });
        assert_eq!(profile_expiry_raw(&js), "");
    }

    #[test]
    fn profile_expiry_accepts_expire_date_alias() {
        let js = json!({ "expire_date": "16 Feb 2027" });
        assert_eq!(profile_expiry_raw(&js), "16 Feb 2027");
    }

    // ── candidate endpoint ordering ──────────────────────────────────

    #[test]
    fn split_origin_strips_path_and_query() {
        let (origin, path) = split_origin_and_path("http://example.com:8080/c/?x=1").unwrap();
        assert_eq!(origin, "http://example.com:8080");
        assert_eq!(path, "/c/");
    }

    #[test]
    fn split_origin_defaults_to_http_scheme() {
        let (origin, _path) = split_origin_and_path("example.com:8080/c/").unwrap();
        assert_eq!(origin, "http://example.com:8080");
    }

    #[test]
    fn referer_is_origin_slash_c_slash() {
        let (origin, _) = split_origin_and_path("http://example.com:8080/c/").unwrap();
        assert_eq!(format!("{origin}/c/"), "http://example.com:8080/c/");
    }

    #[test]
    fn candidate_paths_default_order() {
        let paths = candidate_paths("/c/");
        assert_eq!(
            paths,
            vec![
                "/portal.php".to_string(),
                "/server/load.php".to_string(),
                "/stalker_portal/server/load.php".to_string(),
            ]
        );
    }

    #[test]
    fn candidate_paths_stalker_portal_hint_reorders() {
        let paths = candidate_paths("/stalker_portal/c/");
        assert_eq!(
            paths,
            vec![
                "/stalker_portal/server/load.php".to_string(),
                "/portal.php".to_string(),
                "/server/load.php".to_string(),
            ]
        );
    }

    #[test]
    fn candidate_paths_exact_match_tried_first() {
        let paths = candidate_paths("/custom/portal.php");
        assert_eq!(paths[0], "/custom/portal.php");
        assert_eq!(paths.len(), 4);
    }

    #[test]
    fn candidate_paths_exact_load_php_match_tried_first() {
        let paths = candidate_paths("/stalker_portal/server/load.php");
        // Already equal to the first default — no duplicate entry.
        assert_eq!(paths[0], "/stalker_portal/server/load.php");
        assert_eq!(paths.len(), 3);
    }

    // ── create_link forwarding ────────────────────────────────────────

    #[test]
    fn forwards_non_excluded_query_items() {
        let cmd = "ffmpeg http://host/play/live.php?mac=00:1A&stream=933136&extension=ts&play_token=xyz";
        let items = forwarded_query_items(cmd);
        assert_eq!(
            items,
            vec![
                ("stream".to_string(), "933136".to_string()),
                ("extension".to_string(), "ts".to_string()),
            ]
        );
    }

    #[test]
    fn forwards_nothing_for_non_url_cmd() {
        assert!(forwarded_query_items("533").is_empty());
    }

    #[test]
    fn forwards_nothing_when_cmd_has_no_query() {
        assert!(forwarded_query_items("ffmpeg http://host/live.ts").is_empty());
    }

    #[test]
    fn detects_empty_stream_param() {
        assert!(has_empty_stream_param("http://host/live.php?stream=&extension=ts"));
        assert!(!has_empty_stream_param("http://host/live.php?stream=5"));
        assert!(!has_empty_stream_param("http://host/live.php"));
    }

    // ── transient retry classification ────────────────────────────────

    #[test]
    fn retriable_http_5xx() {
        assert!(is_retriable("HTTP 502"));
        assert!(is_retriable("HTTP 503"));
        assert!(is_retriable("HTTP 520"));
        assert!(is_retriable("HTTP 524"));
        assert!(!is_retriable("HTTP 404"));
        assert!(!is_retriable("HTTP 401"));
    }

    #[test]
    fn retriable_network_not_auth_or_decode() {
        assert!(is_retriable("error sending request for url (http://x): connection reset"));
        assert!(is_retriable("operation timed out"));
        assert!(!is_retriable("auth_failed"));
        assert!(!is_retriable("handshake_failed"));
        assert!(!is_retriable("cancelled"));
        assert!(!is_retriable("expected value at line 1 column 1"));
    }

    #[test]
    fn transient_backoff_schedule() {
        assert_eq!(transient_backoff_ms(1), 300);
        assert_eq!(transient_backoff_ms(2), 800);
        assert_eq!(transient_backoff_ms(3), 800);
    }
}
