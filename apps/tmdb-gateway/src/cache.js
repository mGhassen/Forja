/**
 * TMDB gateway cache.
 * - API JSON → Postgres `tmdb_response_cache`
 * - Images → R2 bucket (`R2_TMDB_BUCKET`) + Postgres `tmdb_image_cache` metadata
 */

import {
  r2Configured,
  r2GetObject,
  r2HeadObject,
  r2PutObject,
  r2DeleteObject,
  r2DeleteObjects,
} from "./r2.js";

const JSON_TABLE = "tmdb_response_cache";
const IMAGE_TABLE = "tmdb_image_cache";
const PURGE_BATCH = 500;

function supabaseConfig() {
  const url = (process.env.SUPABASE_URL || "").trim().replace(/\/$/, "");
  const key = (
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.SUPABASE_SERVICE_KEY ||
    ""
  ).trim();
  if (!url || !key) return null;
  return { url, key };
}

function headers(key, extra = {}) {
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    Accept: "application/json",
    ...extra,
  };
}

/** JSON cache (Postgres) ready. */
export function jsonCacheConfigured() {
  return Boolean(supabaseConfig());
}

/** Image cache needs Postgres meta + R2. */
export function imageCacheConfigured() {
  return Boolean(supabaseConfig()) && r2Configured();
}

/** True when any shared cache backend is configured. */
export function cacheConfigured() {
  return jsonCacheConfigured();
}

/**
 * @param {string} cacheKey
 * @returns {Promise<{ body: Buffer, contentType: string } | null>}
 */
export async function cacheGetJson(cacheKey) {
  const cfg = supabaseConfig();
  if (!cfg) return null;

  const qs = new URLSearchParams({
    select: "body,content_type,expires_at",
    cache_key: `eq.${cacheKey}`,
    limit: "1",
  });

  try {
    const res = await fetch(`${cfg.url}/rest/v1/${JSON_TABLE}?${qs}`, {
      headers: headers(cfg.key),
    });
    if (!res.ok) {
      console.warn("[tmdb-cache] json get HTTP", res.status);
      return null;
    }
    const rows = await res.json();
    if (!Array.isArray(rows) || !rows.length) return null;
    const row = rows[0];
    if (!row.expires_at || new Date(row.expires_at).getTime() <= Date.now()) {
      void deleteJsonRow(cacheKey);
      return null;
    }
    const body = decodeBody(row.body);
    if (!body) return null;
    return {
      body,
      contentType: String(row.content_type || "application/json"),
    };
  } catch (err) {
    console.warn("[tmdb-cache] json get failed", err);
    return null;
  }
}

/**
 * @param {string} cacheKey
 * @param {Buffer|Uint8Array|string} body
 * @param {string} contentType
 * @param {number} ttlSeconds
 */
export async function cachePutJson(cacheKey, body, contentType, ttlSeconds) {
  const cfg = supabaseConfig();
  if (!cfg) return;

  const buf = toBuffer(body);
  const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();
  const payload = {
    cache_key: cacheKey,
    body: `\\x${buf.toString("hex")}`,
    content_type: contentType || "application/json",
    expires_at: expiresAt,
    updated_at: new Date().toISOString(),
  };

  try {
    const res = await fetch(`${cfg.url}/rest/v1/${JSON_TABLE}`, {
      method: "POST",
      headers: headers(cfg.key, {
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates",
      }),
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      console.warn("[tmdb-cache] json put HTTP", res.status, text.slice(0, 200));
    }
  } catch (err) {
    console.warn("[tmdb-cache] json put failed", err);
  }
}

/**
 * Image object path inside the bucket (mirrors TMDB /t/p/{rest}).
 * @param {string} rest e.g. w500/abc.jpg
 */
export function imageStoragePath(rest) {
  return `t/p/${String(rest || "").replace(/^\/+/, "")}`;
}

/**
 * Meta-only lookup for redirect flow (no R2 byte download).
 * @param {string} cacheKey
 * @param {string} rest
 * @returns {Promise<{ storagePath: string, contentType: string, expiresAt: string } | null>}
 */
export async function cacheLookupImage(cacheKey, rest) {
  const cfg = supabaseConfig();
  if (!cfg || !r2Configured()) return null;

  const qs = new URLSearchParams({
    select: "storage_path,content_type,expires_at",
    cache_key: `eq.${cacheKey}`,
    limit: "1",
  });

  try {
    const metaRes = await fetch(`${cfg.url}/rest/v1/${IMAGE_TABLE}?${qs}`, {
      headers: headers(cfg.key),
    });
    if (!metaRes.ok) {
      console.warn("[tmdb-cache] image meta get HTTP", metaRes.status);
      return null;
    }
    const rows = await metaRes.json();
    if (!Array.isArray(rows) || !rows.length) return null;
    const row = rows[0];
    if (!row.expires_at || new Date(row.expires_at).getTime() <= Date.now()) {
      void deleteImage(cacheKey, row.storage_path);
      return null;
    }

    const path = String(row.storage_path || imageStoragePath(rest));
    const exists = await r2HeadObject(path);
    if (!exists) {
      console.warn("[tmdb-cache] image object miss in R2", path);
      void deleteImageMeta(cacheKey);
      return null;
    }
    return {
      storagePath: path,
      contentType: String(row.content_type || "image/jpeg"),
      expiresAt: String(row.expires_at),
    };
  } catch (err) {
    console.warn("[tmdb-cache] image lookup failed", err);
    return null;
  }
}

/**
 * @param {string} cacheKey
 * @param {string} rest image path after /t/p/
 * @returns {Promise<{ body: Buffer, contentType: string } | null>}
 */
export async function cacheGetImage(cacheKey, rest) {
  const hit = await cacheLookupImage(cacheKey, rest);
  if (!hit) return null;
  const obj = await r2GetObject(hit.storagePath);
  if (!obj) {
    void deleteImageMeta(cacheKey);
    return null;
  }
  return {
    body: obj.body,
    contentType: String(
      hit.contentType || obj.contentType || "application/octet-stream",
    ),
  };
}

/**
 * @param {string} cacheKey
 * @param {string} rest
 * @param {Buffer|Uint8Array} body
 * @param {string} contentType
 * @param {number} ttlSeconds
 * @returns {Promise<string | null>} storage path on success
 */
export async function cachePutImage(cacheKey, rest, body, contentType, ttlSeconds) {
  const cfg = supabaseConfig();
  if (!cfg || !r2Configured()) return null;

  const buf = toBuffer(body);
  const path = imageStoragePath(rest);
  const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();
  const ct = contentType || "image/jpeg";

  try {
    const ok = await r2PutObject(path, buf, ct);
    if (!ok) return null;

    const payload = {
      cache_key: cacheKey,
      storage_path: path,
      content_type: ct,
      expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    };
    const metaRes = await fetch(`${cfg.url}/rest/v1/${IMAGE_TABLE}`, {
      method: "POST",
      headers: headers(cfg.key, {
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates",
      }),
      body: JSON.stringify(payload),
    });
    if (!metaRes.ok) {
      const text = await metaRes.text().catch(() => "");
      console.warn(
        "[tmdb-cache] image meta put HTTP",
        metaRes.status,
        text.slice(0, 200),
      );
    }
    return path;
  } catch (err) {
    console.warn("[tmdb-cache] image put failed", err);
    return null;
  }
}

/**
 * Delete expired JSON rows and expired image meta + R2 objects.
 * @returns {Promise<{ jsonDeleted: number, imagesDeleted: number }>}
 */
export async function purgeExpiredCaches() {
  const jsonDeleted = await purgeExpiredJson();
  const imagesDeleted = await purgeExpiredImages();
  return { jsonDeleted, imagesDeleted };
}

async function purgeExpiredJson() {
  const cfg = supabaseConfig();
  if (!cfg) return 0;

  let total = 0;
  const now = new Date().toISOString();
  for (;;) {
    const qs = new URLSearchParams({
      select: "cache_key",
      expires_at: `lte.${now}`,
      limit: String(PURGE_BATCH),
    });
    try {
      const listRes = await fetch(`${cfg.url}/rest/v1/${JSON_TABLE}?${qs}`, {
        headers: headers(cfg.key),
      });
      if (!listRes.ok) {
        console.warn("[tmdb-cache] json purge list HTTP", listRes.status);
        break;
      }
      const rows = await listRes.json();
      if (!Array.isArray(rows) || !rows.length) break;
      const keys = rows.map((r) => r.cache_key).filter(Boolean);
      const inList = keys.map((k) => `"${String(k).replace(/"/g, '\\"')}"`).join(",");
      const delRes = await fetch(
        `${cfg.url}/rest/v1/${JSON_TABLE}?cache_key=in.(${inList})`,
        {
          method: "DELETE",
          headers: headers(cfg.key, { Prefer: "return=minimal" }),
        },
      );
      if (!delRes.ok) {
        console.warn("[tmdb-cache] json purge delete HTTP", delRes.status);
        break;
      }
      total += keys.length;
      if (keys.length < PURGE_BATCH) break;
    } catch (err) {
      console.warn("[tmdb-cache] json purge failed", err);
      break;
    }
  }
  return total;
}

async function purgeExpiredImages() {
  const cfg = supabaseConfig();
  if (!cfg) return 0;

  let total = 0;
  const now = new Date().toISOString();
  for (;;) {
    const qs = new URLSearchParams({
      select: "cache_key,storage_path",
      expires_at: `lte.${now}`,
      limit: String(PURGE_BATCH),
    });
    try {
      const listRes = await fetch(`${cfg.url}/rest/v1/${IMAGE_TABLE}?${qs}`, {
        headers: headers(cfg.key),
      });
      if (!listRes.ok) {
        console.warn("[tmdb-cache] image purge list HTTP", listRes.status);
        break;
      }
      const rows = await listRes.json();
      if (!Array.isArray(rows) || !rows.length) break;

      const paths = rows.map((r) => r.storage_path).filter(Boolean);
      if (r2Configured() && paths.length) {
        await r2DeleteObjects(paths);
      }

      const keys = rows.map((r) => r.cache_key).filter(Boolean);
      const inList = keys.map((k) => `"${String(k).replace(/"/g, '\\"')}"`).join(",");
      const delRes = await fetch(
        `${cfg.url}/rest/v1/${IMAGE_TABLE}?cache_key=in.(${inList})`,
        {
          method: "DELETE",
          headers: headers(cfg.key, { Prefer: "return=minimal" }),
        },
      );
      if (!delRes.ok) {
        console.warn("[tmdb-cache] image purge delete HTTP", delRes.status);
        break;
      }
      total += keys.length;
      if (keys.length < PURGE_BATCH) break;
    } catch (err) {
      console.warn("[tmdb-cache] image purge failed", err);
      break;
    }
  }
  return total;
}

/** @deprecated use cacheGetJson — kept for older call sites */
export const cacheGet = cacheGetJson;
/** @deprecated use cachePutJson */
export const cachePut = cachePutJson;

async function deleteJsonRow(cacheKey) {
  const cfg = supabaseConfig();
  if (!cfg) return;
  try {
    await fetch(
      `${cfg.url}/rest/v1/${JSON_TABLE}?cache_key=eq.${encodeURIComponent(cacheKey)}`,
      { method: "DELETE", headers: headers(cfg.key) },
    );
  } catch {
    /* ignore */
  }
}

async function deleteImageMeta(cacheKey) {
  const cfg = supabaseConfig();
  if (!cfg) return;
  try {
    await fetch(
      `${cfg.url}/rest/v1/${IMAGE_TABLE}?cache_key=eq.${encodeURIComponent(cacheKey)}`,
      { method: "DELETE", headers: headers(cfg.key) },
    );
  } catch {
    /* ignore */
  }
}

async function deleteImage(cacheKey, storagePath) {
  await deleteImageMeta(cacheKey);
  if (storagePath) {
    await r2DeleteObject(storagePath);
  }
}

function toBuffer(body) {
  if (Buffer.isBuffer(body)) return body;
  if (typeof body === "string") return Buffer.from(body);
  return Buffer.from(body);
}

function decodeBody(raw) {
  if (raw == null) return null;
  if (typeof raw === "string") {
    if (raw.startsWith("\\x")) {
      return Buffer.from(raw.slice(2), "hex");
    }
    try {
      return Buffer.from(raw, "base64");
    } catch {
      return Buffer.from(raw);
    }
  }
  if (Array.isArray(raw)) return Buffer.from(raw);
  return null;
}
