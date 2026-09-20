/**
 * Supabase cache for TMDB gateway.
 * - API JSON → Postgres `tmdb_response_cache`
 * - Images → Storage bucket `tmdb-images` + Postgres `tmdb_image_cache` metadata
 */

const JSON_TABLE = "tmdb_response_cache";
const IMAGE_TABLE = "tmdb_image_cache";
const IMAGE_BUCKET = "tmdb-images";

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

export function cacheConfigured() {
  return Boolean(supabaseConfig());
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
 * @param {string} cacheKey
 * @param {string} rest image path after /t/p/
 * @returns {Promise<{ body: Buffer, contentType: string } | null>}
 */
export async function cacheGetImage(cacheKey, rest) {
  const cfg = supabaseConfig();
  if (!cfg) return null;

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
    const objRes = await fetch(
      `${cfg.url}/storage/v1/object/${IMAGE_BUCKET}/${path}`,
      { headers: headers(cfg.key) },
    );
    if (!objRes.ok) {
      console.warn("[tmdb-cache] image object get HTTP", objRes.status);
      return null;
    }
    const buf = Buffer.from(await objRes.arrayBuffer());
    return {
      body: buf,
      contentType: String(
        row.content_type ||
          objRes.headers.get("content-type") ||
          "application/octet-stream",
      ),
    };
  } catch (err) {
    console.warn("[tmdb-cache] image get failed", err);
    return null;
  }
}

/**
 * @param {string} cacheKey
 * @param {string} rest
 * @param {Buffer|Uint8Array} body
 * @param {string} contentType
 * @param {number} ttlSeconds
 */
export async function cachePutImage(cacheKey, rest, body, contentType, ttlSeconds) {
  const cfg = supabaseConfig();
  if (!cfg) return;

  const buf = toBuffer(body);
  const path = imageStoragePath(rest);
  const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();
  const ct = contentType || "image/jpeg";

  try {
    const uploadRes = await fetch(
      `${cfg.url}/storage/v1/object/${IMAGE_BUCKET}/${path}`,
      {
        method: "POST",
        headers: headers(cfg.key, {
          "Content-Type": ct,
          "x-upsert": "true",
        }),
        body: buf,
      },
    );
    if (!uploadRes.ok) {
      const text = await uploadRes.text().catch(() => "");
      console.warn(
        "[tmdb-cache] image upload HTTP",
        uploadRes.status,
        text.slice(0, 200),
      );
      return;
    }

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
  } catch (err) {
    console.warn("[tmdb-cache] image put failed", err);
  }
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

async function deleteImage(cacheKey, storagePath) {
  const cfg = supabaseConfig();
  if (!cfg) return;
  try {
    await fetch(
      `${cfg.url}/rest/v1/${IMAGE_TABLE}?cache_key=eq.${encodeURIComponent(cacheKey)}`,
      { method: "DELETE", headers: headers(cfg.key) },
    );
    if (storagePath) {
      await fetch(`${cfg.url}/storage/v1/object/${IMAGE_BUCKET}`, {
        method: "DELETE",
        headers: headers(cfg.key, { "Content-Type": "application/json" }),
        body: JSON.stringify({ prefixes: [storagePath] }),
      });
    }
  } catch {
    /* ignore */
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
