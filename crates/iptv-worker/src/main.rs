//! Central IPTV catalog worker (RFC-040).
//! Scrapes Reddit via `iptv::reddit_catalog` (`scrape_page_ops`), writes L1/L2
//! funnel rows + pool candidates to Supabase.
//!
//! Env:
//!   SUPABASE_URL
//!   SUPABASE_SERVICE_ROLE_KEY
//!
//! Examples:
//!   cargo run -p iptv-worker -- scrape --dry-run --max-pages 3
//!   cargo run -p iptv-worker -- scrape --max-pages 20 --verify
//!   cargo run -p iptv-worker -- verify --limit 100

use clap::{Parser, Subcommand};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::env;
use std::time::Duration;

#[derive(Parser, Debug)]
#[command(name = "iptv-worker", about = "Forja IPTV catalog ops worker (RFC-040)")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand, Debug)]
enum Cmd {
    /// Scrape Reddit catalog pages into pool + L1/L2 funnel tables.
    Scrape {
        #[arg(long, default_value_t = 10)]
        max_pages: usize,
        #[arg(long, default_value_t = 50)]
        max_results: usize,
        #[arg(long)]
        dry_run: bool,
        #[arg(long)]
        verify: bool,
    },
    /// Re-verify existing pool candidates (plaintext passwords only).
    Verify {
        #[arg(long, default_value_t = 100)]
        limit: usize,
        #[arg(long)]
        dry_run: bool,
    },
}

#[derive(Debug, Clone, Deserialize)]
struct ScrapedPortal {
    url: String,
    username: String,
    password: String,
    #[serde(default)]
    source: String,
}

#[derive(Debug, Deserialize)]
struct OpsPage {
    #[serde(default)]
    portals: Vec<ScrapedPortal>,
    #[serde(default)]
    posts: Vec<Value>,
    next_after: Option<String>,
    error: Option<String>,
}

#[derive(Clone)]
struct PortalMeta {
    portal: ScrapedPortal,
    layer: &'static str,
    post_id: Option<String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    match cli.cmd {
        Cmd::Scrape {
            max_pages,
            max_results,
            dry_run,
            verify,
        } => scrape(max_pages, max_results, dry_run, verify).await?,
        Cmd::Verify { limit, dry_run } => verify_pool(limit, dry_run).await?,
    }
    Ok(())
}

async fn scrape(
    max_pages: usize,
    max_results: usize,
    dry_run: bool,
    do_verify: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(25))
        .build()?;

    let mut after: Option<String> = None;
    let mut portals: BTreeMap<String, PortalMeta> = BTreeMap::new();
    let mut post_rows: Vec<Value> = Vec::new();
    let mut pages = 0usize;
    let mut sum_l1 = 0usize;
    let mut sum_deep = 0usize;
    let mut sum_l2 = 0usize;
    let mut sum_l2_ok = 0usize;
    let mut sum_l2_fail = 0usize;

    while pages < max_pages {
        pages += 1;
        let req = json!({
            "action": "scrape_page_ops",
            "max_results": max_results,
            "after": after,
        });
        let raw = iptv::reddit_catalog::catalog_json(&req.to_string());
        let parsed: OpsPage = serde_json::from_str(&raw)?;
        if let Some(err) = parsed.error {
            eprintln!("scrape_page_ops error: {err}");
            break;
        }

        for post in &parsed.posts {
            sum_l1 += post
                .get("l1_extract_count")
                .and_then(|v| v.as_u64())
                .unwrap_or(0) as usize;
            sum_deep += post
                .get("deep_ref_count")
                .and_then(|v| v.as_u64())
                .unwrap_or(0) as usize;
            sum_l2 += post
                .get("l2_extract_count")
                .and_then(|v| v.as_u64())
                .unwrap_or(0) as usize;
            if let Some(refs) = post.get("deep_refs").and_then(|v| v.as_array()) {
                for r in refs {
                    match r.get("fetch_ok").and_then(|v| v.as_bool()) {
                        Some(true) => sum_l2_ok += 1,
                        Some(false) => sum_l2_fail += 1,
                        None => {}
                    }
                }
            }
            let post_id = post
                .get("post_id")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            if let Some(l1p) = post.get("l1_portals").and_then(|v| v.as_array()) {
                for p in l1p {
                    if let Ok(sp) = serde_json::from_value::<ScrapedPortal>(p.clone()) {
                        let key = portal_key(&sp);
                        portals.entry(key).or_insert(PortalMeta {
                            portal: sp,
                            layer: "l1",
                            post_id: Some(post_id.clone()),
                        });
                    }
                }
            }
            post_rows.push(post.clone());
        }

        for p in parsed.portals {
            let key = portal_key(&p);
            portals.entry(key).or_insert(PortalMeta {
                portal: p,
                layer: "l2",
                post_id: None,
            });
        }

        println!(
            "page {pages}: posts={} unique_portals={}",
            parsed.posts.len(),
            portals.len()
        );
        match parsed.next_after.filter(|s| !s.is_empty() && s != "null") {
            Some(next) => after = Some(next),
            None => break,
        }
    }

    println!(
        "done pages={pages} portals={} posts={} l1={} deep={} l2={}",
        portals.len(),
        post_rows.len(),
        sum_l1,
        sum_deep,
        sum_l2
    );

    if dry_run {
        for meta in portals.values().take(15) {
            println!(
                "  [{}] {} | {} | {}",
                meta.layer,
                meta.portal.url,
                meta.portal.username,
                mask(&meta.portal.password)
            );
        }
        let misses = post_rows
            .iter()
            .filter(|p| p.get("miss").and_then(|v| v.as_bool()).unwrap_or(false))
            .count();
        println!("miss samples: {misses}");
        return Ok(());
    }

    let sb = Supabase::from_env()?;
    let run_id = sb
        .insert_run(json!({
            "status": "running",
            "source": "reddit",
            "posts_seen": post_rows.len(),
        }))
        .await?;

    for post in &post_rows {
        let post_id = post.get("post_id").and_then(|v| v.as_str()).unwrap_or("");
        if post_id.is_empty() {
            continue;
        }
        let row = json!({
            "post_id": post_id,
            "subreddit": post.get("subreddit").and_then(|v| v.as_str()).unwrap_or(""),
            "scrape_run_id": run_id,
        });
        if let Err(e) = sb.upsert_post(&row).await {
            eprintln!("upsert post: {e}");
        }
    }

    let mut upserted = 0usize;
    let mut alive = 0usize;
    for meta in portals.values() {
        let p = &meta.portal;
        let mut row = json!({
            "url": p.url,
            "username": p.username,
            "password": p.password,
            "source": if p.source.is_empty() { "catalog" } else { &p.source },
            "layer": meta.layer,
            "post_id": meta.post_id,
            "region_primary": "UNKNOWN",
            "region_tags": [],
            "region_confidence": 0.0,
        });
        if do_verify {
            match verify_portal(&client, &p.url, &p.username, &p.password).await {
                Ok(info) => {
                    row["alive"] = json!(info.alive);
                    row["expiry"] = json!(info.expiry);
                    row["max_connections"] = json!(info.max_connections);
                    row["timezone"] = json!(info.timezone);
                    let guess = iptv::region::classify_region(
                        info.timezone.as_deref(),
                        &info.category_names,
                    );
                    row["region_primary"] = json!(guess.primary);
                    row["region_tags"] = json!(guess.tags);
                    row["region_confidence"] = json!(guess.confidence);
                    if info.alive {
                        alive += 1;
                    }
                }
                Err(e) => {
                    row["alive"] = json!(false);
                    eprintln!("verify fail {} {}: {e}", p.url, p.username);
                }
            }
        }
        match sb
            .rpc_upsert_candidate(&p.url, &p.username, &p.password, &row)
            .await
        {
            Ok(()) => upserted += 1,
            Err(e) => eprintln!("upsert fail: {e}"),
        }
    }

    sb.patch_run(
        &run_id,
        json!({
            "status": "ok",
            "posts_seen": post_rows.len(),
            "l1_extract_count": sum_l1,
            "deep_ref_count": sum_deep,
            "l2_fetch_ok": sum_l2_ok,
            "l2_fetch_fail": sum_l2_fail,
            "l2_extract_count": sum_l2,
            "candidates_upserted": upserted,
            "alive_count": alive,
        }),
    )
    .await?;

    println!("run {run_id}: upserted={upserted} alive={alive}");
    Ok(())
}

async fn verify_pool(limit: usize, dry_run: bool) -> Result<(), Box<dyn std::error::Error>> {
    let sb = Supabase::from_env()?;
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(20))
        .build()?;
    let rows = sb.list_candidates(limit).await?;
    println!("verifying {} candidates", rows.len());
    for row in rows {
        let id = row.get("id").and_then(|v| v.as_str()).unwrap_or("");
        let url = row.get("url").and_then(|v| v.as_str()).unwrap_or("");
        let user = row.get("username").and_then(|v| v.as_str()).unwrap_or("");
        let pass = row.get("password").and_then(|v| v.as_str()).unwrap_or("");
        if pass.starts_with("v1:") {
            eprintln!("skip {id}: encrypted password (use scrape --verify)");
            continue;
        }
        if dry_run {
            println!("would verify {url} {user}");
            continue;
        }
        match verify_portal(&client, url, user, pass).await {
            Ok(info) => {
                let guess =
                    iptv::region::classify_region(info.timezone.as_deref(), &info.category_names);
                sb.patch_candidate(
                    id,
                    json!({
                        "alive": info.alive,
                        "expiry": info.expiry,
                        "max_connections": info.max_connections,
                        "timezone": info.timezone,
                        "region_primary": guess.primary,
                        "region_tags": guess.tags,
                        "region_confidence": guess.confidence,
                    }),
                )
                .await?;
                println!(
                    "{} {} alive={} region={}",
                    url, user, info.alive, guess.primary
                );
            }
            Err(e) => {
                sb.patch_candidate(id, json!({ "alive": false })).await?;
                eprintln!("{} {} err={e}", url, user);
            }
        }
    }
    Ok(())
}

struct VerifyInfo {
    alive: bool,
    expiry: Option<String>,
    max_connections: Option<String>,
    timezone: Option<String>,
    category_names: Vec<String>,
}

async fn verify_portal(
    client: &reqwest::Client,
    base: &str,
    user: &str,
    pass: &str,
) -> Result<VerifyInfo, Box<dyn std::error::Error>> {
    let base = base.trim_end_matches('/');
    let u = urlencoding_user(user);
    let p = urlencoding_user(pass);
    let url = format!("{base}/player_api.php?username={u}&password={p}");
    let body = client.get(&url).send().await?.text().await?;
    let root: Value = serde_json::from_str(&body).unwrap_or(json!({}));
    let info = root
        .get("user_info")
        .cloned()
        .unwrap_or_else(|| root.clone());
    let server = root.get("server_info").cloned().unwrap_or(json!({}));
    let auth = info.get("auth").and_then(|v| v.as_str()).unwrap_or("");
    let status = info
        .get("status")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_lowercase();
    let alive = auth == "1" || status == "active" || root.get("user_info").is_some();

    let mut category_names = Vec::new();
    if alive {
        let cat_url =
            format!("{base}/player_api.php?username={u}&password={p}&action=get_live_categories");
        if let Ok(resp) = client.get(&cat_url).send().await {
            if let Ok(text) = resp.text().await {
                if let Ok(arr) = serde_json::from_str::<Vec<Value>>(&text) {
                    for c in arr.into_iter().take(80) {
                        if let Some(n) = c.get("category_name").and_then(|v| v.as_str()) {
                            category_names.push(n.to_string());
                        }
                    }
                }
            }
        }
    }

    Ok(VerifyInfo {
        alive,
        expiry: info
            .get("exp_date")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        max_connections: info
            .get("max_connections")
            .map(|v| v.to_string().trim_matches('"').to_string()),
        timezone: server
            .get("timezone")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        category_names,
    })
}

fn portal_key(p: &ScrapedPortal) -> String {
    format!(
        "{}|{}|{}",
        p.url.to_lowercase(),
        p.username.to_lowercase(),
        p.password.to_lowercase()
    )
}

fn urlencoding_user(s: &str) -> String {
    s.replace('%', "%25")
        .replace('&', "%26")
        .replace('+', "%2B")
        .replace(' ', "%20")
        .replace('@', "%40")
}

fn mask(s: &str) -> String {
    if s.len() <= 3 {
        "***".into()
    } else {
        format!("{}***", &s[..2])
    }
}

struct Supabase {
    url: String,
    key: String,
    http: reqwest::Client,
}

impl Supabase {
    fn from_env() -> Result<Self, Box<dyn std::error::Error>> {
        let url = env::var("SUPABASE_URL").map_err(|_| "SUPABASE_URL required")?;
        let key = env::var("SUPABASE_SERVICE_ROLE_KEY")
            .map_err(|_| "SUPABASE_SERVICE_ROLE_KEY required")?;
        Ok(Self {
            url: url.trim_end_matches('/').to_string(),
            key,
            http: reqwest::Client::new(),
        })
    }

    fn headers(&self) -> reqwest::header::HeaderMap {
        let mut h = reqwest::header::HeaderMap::new();
        h.insert("apikey", self.key.parse().unwrap());
        h.insert(
            "Authorization",
            format!("Bearer {}", self.key).parse().unwrap(),
        );
        h.insert("Content-Type", "application/json".parse().unwrap());
        h.insert("Prefer", "return=representation".parse().unwrap());
        h
    }

    async fn insert_run(&self, body: Value) -> Result<String, Box<dyn std::error::Error>> {
        let res = self
            .http
            .post(format!("{}/rest/v1/iptv_scrape_runs", self.url))
            .headers(self.headers())
            .json(&body)
            .send()
            .await?;
        let status = res.status();
        let text = res.text().await?;
        if !status.is_success() {
            return Err(format!("insert_run {status}: {text}").into());
        }
        let rows: Vec<Value> = serde_json::from_str(&text)?;
        Ok(rows[0]["id"].as_str().unwrap_or_default().to_string())
    }

    async fn patch_run(&self, id: &str, body: Value) -> Result<(), Box<dyn std::error::Error>> {
        let res = self
            .http
            .patch(format!(
                "{}/rest/v1/iptv_scrape_runs?id=eq.{}",
                self.url, id
            ))
            .headers(self.headers())
            .json(&body)
            .send()
            .await?;
        if !res.status().is_success() {
            return Err(format!("patch_run {}: {}", res.status(), res.text().await?).into());
        }
        Ok(())
    }

    async fn upsert_post(&self, row: &Value) -> Result<(), Box<dyn std::error::Error>> {
        let mut h = self.headers();
        h.insert(
            "Prefer",
            "resolution=merge-duplicates,return=minimal".parse().unwrap(),
        );
        let res = self
            .http
            .post(format!(
                "{}/rest/v1/iptv_scrape_posts?on_conflict=post_id",
                self.url
            ))
            .headers(h)
            .json(&vec![row])
            .send()
            .await?;
        if !res.status().is_success() {
            return Err(format!("upsert_post {}: {}", res.status(), res.text().await?).into());
        }
        Ok(())
    }

    async fn rpc_upsert_candidate(
        &self,
        url: &str,
        username: &str,
        password: &str,
        row: &Value,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let body = json!({
            "p_url": url,
            "p_username": username,
            "p_password": password,
            "p_source": row.get("source").and_then(|v| v.as_str()).unwrap_or("catalog"),
            "p_layer": row.get("layer").and_then(|v| v.as_str()).unwrap_or("l1"),
            "p_alive": row.get("alive"),
            "p_expiry": row.get("expiry"),
            "p_max_connections": row.get("max_connections"),
            "p_timezone": row.get("timezone"),
            "p_region_primary": row.get("region_primary").and_then(|v| v.as_str()).unwrap_or("UNKNOWN"),
            "p_post_id": row.get("post_id"),
            "p_region_tags": row.get("region_tags"),
            "p_region_confidence": row.get("region_confidence"),
        });
        let res = self
            .http
            .post(format!(
                "{}/rest/v1/rpc/upsert_iptv_catalog_candidate",
                self.url
            ))
            .headers(self.headers())
            .json(&body)
            .send()
            .await?;
        if !res.status().is_success() {
            return Err(format!(
                "upsert_iptv_catalog_candidate {}: {}",
                res.status(),
                res.text().await?
            )
            .into());
        }
        Ok(())
    }

    async fn list_candidates(&self, limit: usize) -> Result<Vec<Value>, Box<dyn std::error::Error>> {
        let res = self
            .http
            .get(format!(
                "{}/rest/v1/iptv_portals?select=id,url,username,password&catalog_pool=eq.true&order=updated_at.desc&limit={}",
                self.url, limit
            ))
            .headers(self.headers())
            .send()
            .await?;
        let status = res.status();
        let text = res.text().await?;
        if !status.is_success() {
            return Err(format!("list_candidates {status}: {text}").into());
        }
        Ok(serde_json::from_str(&text)?)
    }

    async fn patch_candidate(
        &self,
        id: &str,
        body: Value,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let res = self
            .http
            .patch(format!(
                "{}/rest/v1/iptv_portals?id=eq.{}&catalog_pool=eq.true",
                self.url, id
            ))
            .headers(self.headers())
            .json(&body)
            .send()
            .await?;
        if !res.status().is_success() {
            return Err(format!("patch_candidate {}: {}", res.status(), res.text().await?).into());
        }
        Ok(())
    }
}
