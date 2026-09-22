//! Identity-scoped IPTV catalog SQLite (RFC-116).
//!
//! Host opens one DB path per account/profile. Packs page via `catalog_page`
//! without loading the full streams array into Dart.

use rusqlite::{params, Connection, OptionalExtension};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::sync::{LazyLock, Mutex};

static DB: LazyLock<Mutex<Option<Connection>>> = LazyLock::new(|| Mutex::new(None));

const SCHEMA_V1: &str = r#"
CREATE TABLE IF NOT EXISTS shelves (
  portal_hash TEXT NOT NULL,
  section TEXT NOT NULL,
  fetched_at INTEGER NOT NULL DEFAULT 0,
  meta_json TEXT,
  PRIMARY KEY (portal_hash, section)
);
CREATE TABLE IF NOT EXISTS categories (
  portal_hash TEXT NOT NULL,
  section TEXT NOT NULL,
  category_id TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  payload_json TEXT NOT NULL,
  PRIMARY KEY (portal_hash, section, category_id)
);
CREATE TABLE IF NOT EXISTS streams (
  portal_hash TEXT NOT NULL,
  section TEXT NOT NULL,
  stream_id TEXT NOT NULL,
  category_id TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  payload_json TEXT NOT NULL,
  PRIMARY KEY (portal_hash, section, stream_id)
);
CREATE INDEX IF NOT EXISTS idx_streams_cat
  ON streams (portal_hash, section, category_id);
CREATE INDEX IF NOT EXISTS idx_streams_name
  ON streams (portal_hash, section, name);
CREATE TABLE IF NOT EXISTS alive_meta (
  portal_hash TEXT PRIMARY KEY,
  checked_at INTEGER NOT NULL DEFAULT 0,
  live_only INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS alive_ids (
  portal_hash TEXT NOT NULL,
  stream_id TEXT NOT NULL,
  PRIMARY KEY (portal_hash, stream_id)
);
CREATE TABLE IF NOT EXISTS channel_hits (
  channel_id TEXT PRIMARY KEY,
  payload_json TEXT NOT NULL
);
"#;

fn portal_hash(portal_key: &str) -> String {
    let mut h = Sha256::new();
    h.update(portal_key.as_bytes());
    format!("{:x}", h.finalize())
}

fn with_conn<T>(f: impl FnOnce(&Connection) -> Result<T, String>) -> Result<T, String> {
    let guard = DB
        .lock()
        .map_err(|_| "catalog_db lock poisoned".to_string())?;
    let conn = guard
        .as_ref()
        .ok_or_else(|| "catalog_db not open".to_string())?;
    f(conn)
}

fn migrate(conn: &Connection) -> Result<(), String> {
    let ver: i32 = conn
        .query_row("PRAGMA user_version", [], |r| r.get(0))
        .map_err(|e| e.to_string())?;
    if ver < 1 {
        conn.execute_batch(SCHEMA_V1).map_err(|e| e.to_string())?;
        conn.execute_batch("PRAGMA user_version = 1")
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}

pub fn open(path: &str) -> Result<(), String> {
    let conn = Connection::open(path).map_err(|e| e.to_string())?;
    conn.execute_batch(
        "PRAGMA journal_mode=WAL;
         PRAGMA synchronous=NORMAL;
         PRAGMA busy_timeout=5000;
         PRAGMA foreign_keys=ON;",
    )
    .map_err(|e| e.to_string())?;
    migrate(&conn)?;
    let mut guard = DB
        .lock()
        .map_err(|_| "catalog_db lock poisoned".to_string())?;
    *guard = Some(conn);
    Ok(())
}

pub fn close() {
    if let Ok(mut guard) = DB.lock() {
        *guard = None;
    }
}

fn stream_id_of(s: &Value) -> String {
    s.get("id")
        .or_else(|| s.get("stream_id"))
        .or_else(|| s.get("series_id"))
        .or_else(|| s.get("cmd"))
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .trim()
        .to_string()
}

fn category_id_of(s: &Value) -> String {
    s.get("categoryId")
        .or_else(|| s.get("category_id"))
        .and_then(|v| v.as_str())
        .unwrap_or("all")
        .trim()
        .to_string()
}

fn name_of(s: &Value) -> String {
    s.get("name")
        .or_else(|| s.get("title"))
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string()
}

pub fn has_shelf(portal_hash: &str, section: &str) -> Result<bool, String> {
    with_conn(|conn| {
        let n: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM shelves WHERE portal_hash=?1 AND section=?2",
                params![portal_hash, section],
                |r| r.get(0),
            )
            .map_err(|e| e.to_string())?;
        Ok(n > 0)
    })
}

pub fn replace_shelf(
    portal_hash: &str,
    section: &str,
    categories: &[Value],
    streams: &[Value],
) -> Result<(), String> {
    with_conn(|conn| {
        let tx = conn.unchecked_transaction().map_err(|e| e.to_string())?;
        tx.execute(
            "DELETE FROM streams WHERE portal_hash=?1 AND section=?2",
            params![portal_hash, section],
        )
        .map_err(|e| e.to_string())?;
        tx.execute(
            "DELETE FROM categories WHERE portal_hash=?1 AND section=?2",
            params![portal_hash, section],
        )
        .map_err(|e| e.to_string())?;
        tx.execute(
            "DELETE FROM shelves WHERE portal_hash=?1 AND section=?2",
            params![portal_hash, section],
        )
        .map_err(|e| e.to_string())?;

        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);
        tx.execute(
            "INSERT INTO shelves (portal_hash, section, fetched_at) VALUES (?1,?2,?3)",
            params![portal_hash, section, now],
        )
        .map_err(|e| e.to_string())?;

        {
            let mut stmt = tx
                .prepare(
                    "INSERT INTO categories
                     (portal_hash, section, category_id, name, sort_order, payload_json)
                     VALUES (?1,?2,?3,?4,?5,?6)",
                )
                .map_err(|e| e.to_string())?;
            for (i, c) in categories.iter().enumerate() {
                let id = c
                    .get("id")
                    .or_else(|| c.get("category_id"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .trim()
                    .to_string();
                if id.is_empty() {
                    continue;
                }
                let name = c
                    .get("name")
                    .or_else(|| c.get("category_name"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                let payload = serde_json::to_string(c).unwrap_or_else(|_| "{}".into());
                stmt.execute(params![portal_hash, section, id, name, i as i64, payload])
                    .map_err(|e| e.to_string())?;
            }
        }

        {
            let mut stmt = tx
                .prepare(
                    "INSERT OR REPLACE INTO streams
                     (portal_hash, section, stream_id, category_id, name, sort_order, payload_json)
                     VALUES (?1,?2,?3,?4,?5,?6,?7)",
                )
                .map_err(|e| e.to_string())?;
            for (i, s) in streams.iter().enumerate() {
                let sid = stream_id_of(s);
                if sid.is_empty() {
                    continue;
                }
                let cid = category_id_of(s);
                let name = name_of(s);
                let payload = serde_json::to_string(s).unwrap_or_else(|_| "{}".into());
                stmt.execute(params![
                    portal_hash,
                    section,
                    sid,
                    cid,
                    name,
                    i as i64,
                    payload
                ])
                .map_err(|e| e.to_string())?;
            }
        }

        tx.commit().map_err(|e| e.to_string())?;
        Ok(())
    })
}

fn load_categories(conn: &Connection, portal_hash: &str, section: &str) -> Result<Vec<Value>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT payload_json FROM categories
             WHERE portal_hash=?1 AND section=?2
             ORDER BY sort_order ASC",
        )
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![portal_hash, section], |r| {
            let raw: String = r.get(0)?;
            Ok(raw)
        })
        .map_err(|e| e.to_string())?;
    let mut out = Vec::new();
    for row in rows {
        let raw = row.map_err(|e| e.to_string())?;
        if let Ok(v) = serde_json::from_str::<Value>(&raw) {
            out.push(v);
        }
    }
    Ok(out)
}

fn first_category_id(cats: &[Value]) -> String {
    for c in cats {
        let id = c
            .get("id")
            .or_else(|| c.get("category_id"))
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .trim();
        if !id.is_empty() {
            return id.to_string();
        }
    }
    String::new()
}

pub fn page(req: &Value) -> Result<Value, String> {
    let portal_hash = req
        .get("portal_hash")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .trim();
    let portal_hash = if portal_hash.is_empty() {
        let key = req
            .get("portal_key")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .trim();
        if key.is_empty() {
            return Err("missing_portal".into());
        }
        portal_hash_from_key(key)
    } else {
        portal_hash.to_string()
    };
    let section = req
        .get("section")
        .and_then(|v| v.as_str())
        .unwrap_or("live")
        .trim()
        .to_lowercase();
    let section = match section.as_str() {
        "movies" | "movie" | "vod" => "vod",
        "series" | "tv" => "series",
        _ => "live",
    };

    if !has_shelf(&portal_hash, section)? {
        return Ok(json!({
            "ok": false,
            "error": "shelf_miss",
            "categories": [],
            "streams": [],
        }));
    }

    let mut categories = with_conn(|conn| load_categories(conn, &portal_hash, section))?;

    let has_stream_ids_key = req.get("stream_ids").is_some() || req.get("streamIds").is_some();
    let stream_ids: Vec<String> = req
        .get("stream_ids")
        .or_else(|| req.get("streamIds"))
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|e| e.as_str().map(|s| s.trim().to_string()))
                .filter(|s| !s.is_empty())
                .collect()
        })
        .unwrap_or_default();

    let mut category_id = req
        .get("category_id")
        .or_else(|| req.get("categoryId"))
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .trim()
        .to_string();
    let q = req
        .get("q")
        .or_else(|| req.get("query"))
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .trim()
        .to_string();
    let sort = req
        .get("sort")
        .and_then(|v| v.as_str())
        .unwrap_or("playlist")
        .trim()
        .to_string();

    let synthetic = category_id.starts_with("__");
    if has_stream_ids_key || synthetic {
        category_id.clear();
    } else if stream_ids.is_empty() && q.is_empty() && category_id.is_empty() {
        category_id = first_category_id(&categories);
    }

    let mut page = req.get("page").and_then(|v| v.as_i64()).unwrap_or(1);
    if page < 1 {
        page = 1;
    }
    let mut page_size = req
        .get("page_size")
        .or_else(|| req.get("pageSize"))
        .or_else(|| req.get("limit"))
        .and_then(|v| v.as_i64())
        .unwrap_or(48);
    if page_size < 1 {
        page_size = 48;
    }

    // Favorites / watched by id list
    if has_stream_ids_key || synthetic {
        if stream_ids.is_empty() {
            return Ok(json!({
                "ok": true,
                "categories": categories,
                "streams": [],
                "hitCategoryIds": [],
                "hit_category_ids": [],
                "page": page,
                "pageSize": page_size,
                "page_size": page_size,
                "hasMore": false,
                "has_more": false,
                "total": 0,
                "categoryId": "",
                "category_id": "",
            }));
        }
        if page_size < stream_ids.len() as i64 {
            page_size = stream_ids.len() as i64;
        }
        if page_size > 256 {
            page_size = 256;
        }
        let streams = streams_by_ids_ordered(&portal_hash, section, &stream_ids)?;
        let total = streams.len();
        return Ok(json!({
            "ok": true,
            "categories": categories,
            "streams": streams,
            "hitCategoryIds": [],
            "hit_category_ids": [],
            "page": page,
            "pageSize": page_size,
            "page_size": page_size,
            "hasMore": false,
            "has_more": false,
            "total": total,
            "categoryId": "",
            "category_id": "",
        }));
    }

    if page_size > 128 {
        page_size = 128;
    }

    let hit_category_ids = if q.is_empty() {
        Vec::<String>::new()
    } else {
        with_conn(|conn| query_hit_category_ids(conn, &portal_hash, section, &q))?
    };
    if !q.is_empty() {
        let want: std::collections::HashSet<&str> =
            hit_category_ids.iter().map(|s| s.as_str()).collect();
        categories.retain(|c| {
            let id = c
                .get("id")
                .or_else(|| c.get("category_id"))
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .trim();
            !id.is_empty() && want.contains(id)
        });
    }

    let (total, streams) = with_conn(|conn| {
        query_page(
            conn,
            &portal_hash,
            section,
            &category_id,
            &q,
            &sort,
            page,
            page_size,
        )
    })?;

    let has_more = ((page - 1) * page_size + streams.len() as i64) < total;

    Ok(json!({
        "ok": true,
        "categories": categories,
        "streams": streams,
        "hitCategoryIds": hit_category_ids.clone(),
        "hit_category_ids": hit_category_ids,
        "page": page,
        "pageSize": page_size,
        "page_size": page_size,
        "hasMore": has_more,
        "has_more": has_more,
        "total": total,
        "categoryId": category_id,
        "category_id": category_id,
    }))
}

fn portal_hash_from_key(key: &str) -> String {
    portal_hash(key)
}

fn query_hit_category_ids(
    conn: &Connection,
    portal_hash: &str,
    section: &str,
    q: &str,
) -> Result<Vec<String>, String> {
    if q.is_empty() {
        return Ok(Vec::new());
    }
    let needle = format!("%{}%", q.to_lowercase());
    let mut stmt = conn
        .prepare(
            "SELECT DISTINCT category_id FROM streams
             WHERE portal_hash=?1 AND section=?2
               AND (lower(name) LIKE ?3 OR lower(category_id) LIKE ?3)
             ORDER BY category_id ASC",
        )
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![portal_hash, section, needle], |r| {
            let id: String = r.get(0)?;
            Ok(id)
        })
        .map_err(|e| e.to_string())?;
    let mut out = Vec::new();
    for row in rows {
        let id = row.map_err(|e| e.to_string())?;
        let id = id.trim().to_string();
        if !id.is_empty() {
            out.push(id);
        }
    }
    Ok(out)
}

fn query_page(
    conn: &Connection,
    portal_hash: &str,
    section: &str,
    category_id: &str,
    q: &str,
    sort: &str,
    page: i64,
    page_size: i64,
) -> Result<(i64, Vec<Value>), String> {
    let mut where_sql = String::from("portal_hash=?1 AND section=?2");
    let mut bind: Vec<Box<dyn rusqlite::types::ToSql>> = vec![
        Box::new(portal_hash.to_string()),
        Box::new(section.to_string()),
    ];
    let mut idx = 3;
    if !category_id.is_empty() && category_id != "all" && !category_id.starts_with("__") {
        where_sql.push_str(&format!(" AND category_id=?{idx}"));
        bind.push(Box::new(category_id.to_string()));
        idx += 1;
    }
    if !q.is_empty() {
        let needle = format!("%{}%", q.to_lowercase());
        where_sql.push_str(&format!(
            " AND (lower(name) LIKE ?{idx} OR lower(category_id) LIKE ?{idx})"
        ));
        bind.push(Box::new(needle));
        idx += 1;
    }
    let _ = idx;

    let count_sql = format!("SELECT COUNT(*) FROM streams WHERE {where_sql}");
    let total: i64 = {
        let mut stmt = conn.prepare(&count_sql).map_err(|e| e.to_string())?;
        let params_ref: Vec<&dyn rusqlite::types::ToSql> =
            bind.iter().map(|b| b.as_ref()).collect();
        stmt.query_row(params_ref.as_slice(), |r| r.get(0))
            .map_err(|e| e.to_string())?
    };

    let order = match sort {
        "nameAsc" => "name COLLATE NOCASE ASC, sort_order ASC",
        "nameDesc" => "name COLLATE NOCASE DESC, sort_order ASC",
        _ => "sort_order ASC",
    };
    let offset = (page - 1) * page_size;
    let select_sql = format!(
        "SELECT payload_json FROM streams WHERE {where_sql} ORDER BY {order} LIMIT ? OFFSET ?"
    );
    bind.push(Box::new(page_size));
    bind.push(Box::new(offset));

    let mut stmt = conn.prepare(&select_sql).map_err(|e| e.to_string())?;
    let params_ref: Vec<&dyn rusqlite::types::ToSql> =
        bind.iter().map(|b| b.as_ref()).collect();
    let rows = stmt
        .query_map(params_ref.as_slice(), |r| {
            let raw: String = r.get(0)?;
            Ok(raw)
        })
        .map_err(|e| e.to_string())?;
    let mut streams = Vec::new();
    for row in rows {
        let raw = row.map_err(|e| e.to_string())?;
        if let Ok(v) = serde_json::from_str::<Value>(&raw) {
            streams.push(v);
        }
    }
    Ok((total, streams))
}

fn streams_by_ids_ordered(
    portal_hash: &str,
    section: &str,
    ids: &[String],
) -> Result<Vec<Value>, String> {
    with_conn(|conn| {
        let mut stmt = conn
            .prepare(
                "SELECT payload_json FROM streams
                 WHERE portal_hash=?1 AND section=?2 AND stream_id=?3",
            )
            .map_err(|e| e.to_string())?;
        let mut out = Vec::new();
        for id in ids {
            let raw: Option<String> = stmt
                .query_row(params![portal_hash, section, id], |r| r.get(0))
                .optional()
                .map_err(|e| e.to_string())?;
            if let Some(raw) = raw {
                if let Ok(v) = serde_json::from_str::<Value>(&raw) {
                    out.push(v);
                }
            }
        }
        Ok(out)
    })
}


pub fn export_shelf(portal_hash: &str, section: &str) -> Result<Value, String> {
    if !has_shelf(portal_hash, section)? {
        return Ok(json!({
            "ok": false,
            "error": "shelf_miss",
            "categories": [],
            "streams": [],
        }));
    }
    with_conn(|conn| {
        let categories = load_categories(conn, portal_hash, section)?;
        let mut stmt = conn
            .prepare(
                "SELECT payload_json FROM streams
                 WHERE portal_hash=?1 AND section=?2
                 ORDER BY sort_order ASC",
            )
            .map_err(|e| e.to_string())?;
        let rows = stmt
            .query_map(params![portal_hash, section], |r| {
                let raw: String = r.get(0)?;
                Ok(raw)
            })
            .map_err(|e| e.to_string())?;
        let mut streams = Vec::new();
        for row in rows {
            let raw = row.map_err(|e| e.to_string())?;
            if let Ok(v) = serde_json::from_str::<Value>(&raw) {
                streams.push(v);
            }
        }
        Ok(json!({
            "ok": true,
            "categories": categories,
            "streams": streams,
        }))
    })
}

pub fn clear_all() -> Result<(), String> {
    with_conn(|conn| {
        conn.execute_batch(
            "DELETE FROM streams;
             DELETE FROM categories;
             DELETE FROM shelves;
             DELETE FROM alive_ids;
             DELETE FROM alive_meta;
             DELETE FROM channel_hits;",
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    })
}

pub fn clear_portal(portal_hash: &str) -> Result<(), String> {
    with_conn(|conn| {
        conn.execute(
            "DELETE FROM streams WHERE portal_hash=?1",
            params![portal_hash],
        )
        .map_err(|e| e.to_string())?;
        conn.execute(
            "DELETE FROM categories WHERE portal_hash=?1",
            params![portal_hash],
        )
        .map_err(|e| e.to_string())?;
        conn.execute(
            "DELETE FROM shelves WHERE portal_hash=?1",
            params![portal_hash],
        )
        .map_err(|e| e.to_string())?;
        conn.execute(
            "DELETE FROM alive_ids WHERE portal_hash=?1",
            params![portal_hash],
        )
        .map_err(|e| e.to_string())?;
        conn.execute(
            "DELETE FROM alive_meta WHERE portal_hash=?1",
            params![portal_hash],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    })
}

// ── Alive ──────────────────────────────────────────────────────────────────

pub fn alive_load(portal_hash: &str) -> Result<Value, String> {
    with_conn(|conn| {
        let meta: Option<(i64, i64)> = conn
            .query_row(
                "SELECT checked_at, live_only FROM alive_meta WHERE portal_hash=?1",
                params![portal_hash],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
            .map_err(|e| e.to_string())?;
        let Some((checked_at, live_only)) = meta else {
            return Ok(json!(null));
        };
        let mut stmt = conn
            .prepare("SELECT stream_id FROM alive_ids WHERE portal_hash=?1")
            .map_err(|e| e.to_string())?;
        let ids: Vec<String> = stmt
            .query_map(params![portal_hash], |r| r.get(0))
            .map_err(|e| e.to_string())?
            .filter_map(|r| r.ok())
            .collect();
        Ok(json!({
            "at": checked_at,
            "ids": ids,
            "liveOnly": live_only != 0,
        }))
    })
}

pub fn alive_save(portal_hash: &str, checked_at: i64, ids: &[String], live_only: bool) -> Result<(), String> {
    with_conn(|conn| {
        let tx = conn.unchecked_transaction().map_err(|e| e.to_string())?;
        tx.execute(
            "INSERT INTO alive_meta (portal_hash, checked_at, live_only)
             VALUES (?1,?2,?3)
             ON CONFLICT(portal_hash) DO UPDATE SET
               checked_at=excluded.checked_at,
               live_only=excluded.live_only",
            params![portal_hash, checked_at, if live_only { 1 } else { 0 }],
        )
        .map_err(|e| e.to_string())?;
        tx.execute(
            "DELETE FROM alive_ids WHERE portal_hash=?1",
            params![portal_hash],
        )
        .map_err(|e| e.to_string())?;
        {
            let mut stmt = tx
                .prepare("INSERT INTO alive_ids (portal_hash, stream_id) VALUES (?1,?2)")
                .map_err(|e| e.to_string())?;
            for id in ids {
                if id.trim().is_empty() {
                    continue;
                }
                stmt.execute(params![portal_hash, id])
                    .map_err(|e| e.to_string())?;
            }
        }
        tx.commit().map_err(|e| e.to_string())?;
        Ok(())
    })
}

pub fn alive_set_live_only(portal_hash: &str, live_only: bool) -> Result<(), String> {
    with_conn(|conn| {
        conn.execute(
            "INSERT INTO alive_meta (portal_hash, checked_at, live_only)
             VALUES (?1, 0, ?2)
             ON CONFLICT(portal_hash) DO UPDATE SET live_only=excluded.live_only",
            params![portal_hash, if live_only { 1 } else { 0 }],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    })
}

pub fn alive_clear(portal_hash: &str) -> Result<(), String> {
    with_conn(|conn| {
        conn.execute(
            "DELETE FROM alive_ids WHERE portal_hash=?1",
            params![portal_hash],
        )
        .map_err(|e| e.to_string())?;
        conn.execute(
            "DELETE FROM alive_meta WHERE portal_hash=?1",
            params![portal_hash],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    })
}

pub fn alive_clear_all() -> Result<(), String> {
    with_conn(|conn| {
        conn.execute_batch("DELETE FROM alive_ids; DELETE FROM alive_meta;")
            .map_err(|e| e.to_string())?;
        Ok(())
    })
}

// ── Channel scan hits ──────────────────────────────────────────────────────

pub fn channel_hits_load(channel_id: &str) -> Result<Value, String> {
    with_conn(|conn| {
        let raw: Option<String> = conn
            .query_row(
                "SELECT payload_json FROM channel_hits WHERE channel_id=?1",
                params![channel_id],
                |r| r.get(0),
            )
            .optional()
            .map_err(|e| e.to_string())?;
        match raw {
            Some(s) => serde_json::from_str(&s).map_err(|e| e.to_string()),
            None => Ok(json!([])),
        }
    })
}

pub fn channel_hits_save(channel_id: &str, hits: &Value) -> Result<(), String> {
    let payload = serde_json::to_string(hits).map_err(|e| e.to_string())?;
    with_conn(|conn| {
        conn.execute(
            "INSERT INTO channel_hits (channel_id, payload_json) VALUES (?1,?2)
             ON CONFLICT(channel_id) DO UPDATE SET payload_json=excluded.payload_json",
            params![channel_id, payload],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    })
}

pub fn channel_hits_clear(channel_id: &str) -> Result<(), String> {
    with_conn(|conn| {
        conn.execute(
            "DELETE FROM channel_hits WHERE channel_id=?1",
            params![channel_id],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    })
}

pub fn channel_hits_clear_all() -> Result<(), String> {
    with_conn(|conn| {
        conn.execute("DELETE FROM channel_hits", [])
            .map_err(|e| e.to_string())?;
        Ok(())
    })
}

/// Single JSON dispatcher for FFI.
pub fn handle_json(request_json: &str) -> String {
    let req: Value = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": e.to_string() }).to_string(),
    };
    let action = req
        .get("action")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .trim();

    let result = (|| -> Result<Value, String> {
        match action {
            "open" => {
                let path = req
                    .get("path")
                    .and_then(|v| v.as_str())
                    .ok_or_else(|| "missing_path".to_string())?;
                open(path)?;
                Ok(json!({ "ok": true }))
            }
            "close" => {
                close();
                Ok(json!({ "ok": true }))
            }
            "has_shelf" => {
                let (ph, sec) = portal_section(&req)?;
                Ok(json!({ "ok": true, "has": has_shelf(&ph, &sec)? }))
            }
            "replace_shelf" => {
                let (ph, sec) = portal_section(&req)?;
                let cats = req
                    .get("categories")
                    .and_then(|v| v.as_array())
                    .cloned()
                    .unwrap_or_default();
                let streams = req
                    .get("streams")
                    .and_then(|v| v.as_array())
                    .cloned()
                    .unwrap_or_default();
                replace_shelf(&ph, &sec, &cats, &streams)?;
                Ok(json!({ "ok": true }))
            }
            "page" => page(&req),
            "export_shelf" => {
                let (ph, sec) = portal_section(&req)?;
                export_shelf(&ph, &sec)
            }
            "streams_by_ids" => {
                let (ph, sec) = portal_section(&req)?;
                let ids: Vec<String> = req
                    .get("stream_ids")
                    .or_else(|| req.get("streamIds"))
                    .and_then(|v| v.as_array())
                    .map(|a| {
                        a.iter()
                            .filter_map(|e| e.as_str().map(|s| s.to_string()))
                            .collect()
                    })
                    .unwrap_or_default();
                let streams = streams_by_ids_ordered(&ph, &sec, &ids)?;
                Ok(json!({ "ok": true, "streams": streams }))
            }
            "clear" => {
                clear_all()?;
                Ok(json!({ "ok": true }))
            }
            "clear_portal" => {
                let ph = resolve_portal_hash(&req)?;
                clear_portal(&ph)?;
                Ok(json!({ "ok": true }))
            }
            "alive_load" => {
                let ph = resolve_portal_hash(&req)?;
                Ok(json!({ "ok": true, "snap": alive_load(&ph)? }))
            }
            "alive_save" => {
                let ph = resolve_portal_hash(&req)?;
                let at = req.get("at").and_then(|v| v.as_i64()).unwrap_or(0);
                let live_only = req
                    .get("liveOnly")
                    .or_else(|| req.get("live_only"))
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);
                let ids: Vec<String> = req
                    .get("ids")
                    .and_then(|v| v.as_array())
                    .map(|a| {
                        a.iter()
                            .filter_map(|e| e.as_str().map(|s| s.to_string()))
                            .collect()
                    })
                    .unwrap_or_default();
                alive_save(&ph, at, &ids, live_only)?;
                Ok(json!({ "ok": true }))
            }
            "alive_set_live_only" => {
                let ph = resolve_portal_hash(&req)?;
                let live_only = req
                    .get("liveOnly")
                    .or_else(|| req.get("live_only"))
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);
                alive_set_live_only(&ph, live_only)?;
                Ok(json!({ "ok": true }))
            }
            "alive_clear" => {
                let ph = resolve_portal_hash(&req)?;
                alive_clear(&ph)?;
                Ok(json!({ "ok": true }))
            }
            "alive_clear_all" => {
                alive_clear_all()?;
                Ok(json!({ "ok": true }))
            }
            "channel_hits_load" => {
                let id = req
                    .get("channel_id")
                    .or_else(|| req.get("channelId"))
                    .and_then(|v| v.as_str())
                    .ok_or_else(|| "missing_channel_id".to_string())?;
                Ok(json!({ "ok": true, "hits": channel_hits_load(id)? }))
            }
            "channel_hits_save" => {
                let id = req
                    .get("channel_id")
                    .or_else(|| req.get("channelId"))
                    .and_then(|v| v.as_str())
                    .ok_or_else(|| "missing_channel_id".to_string())?;
                let hits = req.get("hits").cloned().unwrap_or(json!([]));
                channel_hits_save(id, &hits)?;
                Ok(json!({ "ok": true }))
            }
            "channel_hits_clear" => {
                let id = req
                    .get("channel_id")
                    .or_else(|| req.get("channelId"))
                    .and_then(|v| v.as_str())
                    .ok_or_else(|| "missing_channel_id".to_string())?;
                channel_hits_clear(id)?;
                Ok(json!({ "ok": true }))
            }
            "channel_hits_clear_all" => {
                channel_hits_clear_all()?;
                Ok(json!({ "ok": true }))
            }
            _ => Err(format!("unknown_action:{action}")),
        }
    })();

    match result {
        Ok(v) => v.to_string(),
        Err(e) => json!({ "error": e }).to_string(),
    }
}

fn resolve_portal_hash(req: &Value) -> Result<String, String> {
    if let Some(h) = req.get("portal_hash").and_then(|v| v.as_str()) {
        let t = h.trim();
        if !t.is_empty() {
            return Ok(t.to_string());
        }
    }
    let key = req
        .get("portal_key")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .trim();
    if key.is_empty() {
        return Err("missing_portal".into());
    }
    Ok(portal_hash(key))
}

fn portal_section(req: &Value) -> Result<(String, String), String> {
    let ph = resolve_portal_hash(req)?;
    let section = req
        .get("section")
        .and_then(|v| v.as_str())
        .unwrap_or("live")
        .trim()
        .to_lowercase();
    let section = match section.as_str() {
        "movies" | "movie" | "vod" => "vod",
        "series" | "tv" => "series",
        _ => "live",
    };
    Ok((ph, section.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex as StdMutex;

    static TEST_LOCK: StdMutex<()> = StdMutex::new(());

    fn temp_db() -> String {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir()
            .join(format!("forja_catalog_{nanos}.sqlite"))
            .to_string_lossy()
            .into_owned()
    }

    #[test]
    fn replace_and_page_by_category() {
        let _g = TEST_LOCK.lock().unwrap();
        let path = temp_db();
        open(&path).unwrap();
        let ph = portal_hash("http://x|u|p");
        replace_shelf(
            &ph,
            "live",
            &[json!({"id":"a","name":"A"}), json!({"id":"b","name":"B"})],
            &[
                json!({"id":"1","name":"Alpha","category_id":"a"}),
                json!({"id":"2","name":"Beta","category_id":"a"}),
                json!({"id":"3","name":"Gamma","category_id":"b"}),
            ],
        )
        .unwrap();
        let out = page(&json!({
            "portal_hash": ph,
            "section": "live",
            "category_id": "a",
            "page": 1,
            "page_size": 48,
        }))
        .unwrap();
        assert_eq!(out["ok"], true);
        assert_eq!(out["total"], 2);
        let streams = out["streams"].as_array().unwrap();
        assert_eq!(streams.len(), 2);
        assert_eq!(streams[0]["id"], "1");
        let _ = std::fs::remove_file(&path);
        close();
    }

    #[test]
    fn page_search_q() {
        let _g = TEST_LOCK.lock().unwrap();
        let path = temp_db();
        open(&path).unwrap();
        let ph = portal_hash("k");
        replace_shelf(
            &ph,
            "live",
            &[json!({"id":"a","name":"A"})],
            &[
                json!({"id":"1","name":"Alpha","category_id":"a"}),
                json!({"id":"4","name":"Alpine","category_id":"a"}),
            ],
        )
        .unwrap();
        let out = page(&json!({
            "portal_hash": ph,
            "section": "live",
            "q": "alp",
            "category_id": "",
        }))
        .unwrap();
        assert_eq!(out["total"], 2);
        close();
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn page_search_q_filters_categories_and_hit_ids() {
        let _g = TEST_LOCK.lock().unwrap();
        let path = temp_db();
        open(&path).unwrap();
        let ph = portal_hash("search-cats");
        replace_shelf(
            &ph,
            "live",
            &[
                json!({"id":"fr","name":"France"}),
                json!({"id":"vip","name":"VIP"}),
                json!({"id":"news","name":"News"}),
            ],
            &[
                json!({"id":"1","name":"FR - M6 FHD","category_id":"fr"}),
                json!({"id":"2","name":"VIP - M6 4K","category_id":"vip"}),
                json!({"id":"3","name":"News 24","category_id":"news"}),
            ],
        )
        .unwrap();
        let out = page(&json!({
            "portal_hash": ph,
            "section": "live",
            "q": "m6",
            "category_id": "",
            "page": 1,
            "page_size": 48,
        }))
        .unwrap();
        assert_eq!(out["ok"], true);
        assert_eq!(out["total"], 2);
        let cats = out["categories"].as_array().unwrap();
        assert_eq!(cats.len(), 2);
        let ids: Vec<&str> = cats
            .iter()
            .filter_map(|c| c.get("id").and_then(|v| v.as_str()))
            .collect();
        assert!(ids.contains(&"fr"));
        assert!(ids.contains(&"vip"));
        assert!(!ids.contains(&"news"));
        let hits = out["hitCategoryIds"].as_array().unwrap();
        assert_eq!(hits.len(), 2);
        close();
        let _ = std::fs::remove_file(&path);
    }
}
