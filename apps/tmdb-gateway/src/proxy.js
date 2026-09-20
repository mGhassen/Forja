import {
  cacheGetJson,
  cachePutJson,
  cacheGetImage,
  cachePutImage,
  cacheConfigured,
} from "./cache.js";


const TMDB_API = "https://api.themoviedb.org";
const TMDB_IMG = "https://image.tmdb.org";

const ALLOW_API_PREFIXES = [
  "movie/",
  "tv/",
  "search/",
  "discover/",
  "trending/",
  "find/",
  "genre/",
  "configuration",
  "person/",
  "collection/",
  "company/",
  "network/",
  "watch/",
  "credit/",
  "keyword/",
  "list/",
];

/**
 * Public origin for rewriting configuration image hosts, e.g.
 * https://tmdb.forjahq.xyz or http://localhost:3000
 */
export function publicOrigin() {
  const fromEnv = (process.env.TMDB_GATEWAY_PUBLIC_URL || "").trim().replace(/\/$/, "");
  if (fromEnv) return fromEnv;
  const vercel = (process.env.VERCEL_URL || "").trim();
  if (vercel) return `https://${vercel.replace(/^https?:\/\//, "")}`;
  return "http://localhost:3000";
}

function apiKey() {
  return (process.env.TMDB_API_KEY || "").trim();
}

function bearer() {
  return (
    process.env.TMDB_READ_ACCESS_TOKEN ||
    process.env.TMDB_BEARER_TOKEN ||
    ""
  ).trim();
}

function hasCredentials() {
  return Boolean(apiKey() || bearer());
}

/** @param {string} pathNoQuery */
export function isAllowedApiPath(pathNoQuery) {
  const p = pathNoQuery.replace(/^\/+/, "");
  if (!p) return false;
  return ALLOW_API_PREFIXES.some(
    (prefix) => p === prefix.replace(/\/$/, "") || p.startsWith(prefix),
  );
}

/** Normalize request pathname → { kind: 'api'|'image'|'health'|'other', rest } */
export function classifyPath(pathname) {
  let path = String(pathname || "").split("?")[0].replace(/^\/+/, "");
  // Vercel mounts under /api
  if (path === "api" || path.startsWith("api/")) {
    path = path.slice(4).replace(/^\/+/, "");
  }
  if (path === "health" || path.startsWith("health/")) {
    return { kind: "health", rest: path.slice("health".length).replace(/^\/+/, "") };
  }
  if (path === "3" || path.startsWith("3/")) {
    return { kind: "api", rest: path.slice(2).replace(/^\/+/, "") };
  }
  if (path === "t/p" || path.startsWith("t/p/")) {
    return { kind: "image", rest: path.slice(3).replace(/^\/+/, "") };
  }
  return { kind: "other", rest: path };
}

export function cacheKeyFor(kind, rest, searchParams) {
  const qs = new URLSearchParams(searchParams);
  // Never key on client api_key — server injects credentials.
  qs.delete("api_key");
  const sorted = [...qs.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  const q = new URLSearchParams(sorted).toString();
  return `${kind}:${rest}${q ? `?${q}` : ""}`;
}

export function ttlSecondsFor(kind, rest) {
  if (kind === "image") return 7 * 24 * 60 * 60;
  if (kind === "api") {
    if (rest.startsWith("configuration")) return 60 * 60;
    if (
      rest.startsWith("trending/") ||
      rest.startsWith("discover/") ||
      rest === "movie/popular" ||
      rest.startsWith("movie/popular") ||
      rest === "tv/popular" ||
      rest.startsWith("tv/popular")
    ) {
      return 20 * 60;
    }
    return 8 * 60;
  }
  return 60;
}

function cacheControlFor(ttl) {
  return `public, max-age=${Math.min(ttl, 3600)}, s-maxage=${ttl}`;
}

/**
 * @param {Request} request
 * @returns {Promise<Response>}
 */
export async function handleRequest(request) {
  const url = new URL(request.url);
  if (request.method !== "GET" && request.method !== "HEAD") {
    return json({ error: "Method not allowed" }, 405);
  }

  const { kind, rest } = classifyPath(url.pathname);

  if (kind === "health") {
    return json({
      ok: true,
      hasApiKey: Boolean(apiKey()),
      hasBearer: Boolean(bearer()),
      cache: cacheConfigured(),
      publicOrigin: publicOrigin(),
    });
  }

  if (kind === "other") {
    return json(
      {
        error: "Not found",
        hint: "Use /3/... for TMDB API or /t/p/{size}/... for images",
      },
      404,
    );
  }

  if (kind === "api") {
    if (!isAllowedApiPath(rest)) {
      return json({ error: "Path not allowed" }, 404);
    }
    if (!hasCredentials()) {
      return json(
        {
          error:
            "TMDB credentials missing — set TMDB_API_KEY and/or TMDB_READ_ACCESS_TOKEN",
        },
        500,
      );
    }
    return proxyApi(rest, url.searchParams, request.method);
  }

  if (kind === "image") {
    if (!rest || rest.includes("..")) {
      return json({ error: "Bad image path" }, 400);
    }
    return proxyImage(rest, request.method);
  }

  return json({ error: "Not found" }, 404);
}

async function proxyApi(rest, searchParams, method) {
  const key = cacheKeyFor("api", rest, searchParams);
  const ttl = ttlSecondsFor("api", rest);

  const cached = await cacheGetJson(key);
  if (cached) {
    return new Response(method === "HEAD" ? null : cached.body, {
      status: 200,
      headers: {
        "Content-Type": cached.contentType,
        "Cache-Control": cacheControlFor(ttl),
        "X-TMDB-Cache": "HIT",
      },
    });
  }

  const params = new URLSearchParams(searchParams);
  params.delete("api_key");
  const keyVal = apiKey();
  if (keyVal) params.set("api_key", keyVal);
  const qs = params.toString();
  const upstream = `${TMDB_API}/3/${rest}${qs ? `?${qs}` : ""}`;

  const headers = { Accept: "application/json" };
  const token = bearer();
  if (token) headers.Authorization = `Bearer ${token}`;

  let upstreamRes;
  try {
    upstreamRes = await fetch(upstream, { headers });
  } catch (err) {
    return json({ error: "Failed to reach TMDB", detail: String(err) }, 502);
  }

  let bodyText = await upstreamRes.text();
  const contentType =
    upstreamRes.headers.get("content-type") || "application/json; charset=utf-8";

  if (
    upstreamRes.ok &&
    rest.startsWith("configuration") &&
    contentType.includes("json")
  ) {
    bodyText = rewriteConfigurationImages(bodyText);
  }

  if (upstreamRes.ok && upstreamRes.status === 200) {
    void cachePutJson(key, bodyText, contentType, ttl);
  }

  return new Response(method === "HEAD" ? null : bodyText, {
    status: upstreamRes.status,
    headers: {
      "Content-Type": contentType,
      "Cache-Control": upstreamRes.ok
        ? cacheControlFor(ttl)
        : "no-store",
      "X-TMDB-Cache": "MISS",
    },
  });
}

async function proxyImage(rest, method) {
  const key = cacheKeyFor("image", rest, new URLSearchParams());
  const ttl = ttlSecondsFor("image", rest);

  const cached = await cacheGetImage(key, rest);
  if (cached) {
    return new Response(method === "HEAD" ? null : cached.body, {
      status: 200,
      headers: {
        "Content-Type": cached.contentType,
        "Cache-Control": cacheControlFor(ttl),
        "X-TMDB-Cache": "HIT",
      },
    });
  }

  const upstream = `${TMDB_IMG}/t/p/${rest}`;
  let upstreamRes;
  try {
    upstreamRes = await fetch(upstream);
  } catch (err) {
    return json({ error: "Failed to reach TMDB images", detail: String(err) }, 502);
  }

  const buf = Buffer.from(await upstreamRes.arrayBuffer());
  const contentType =
    upstreamRes.headers.get("content-type") || "application/octet-stream";

  if (upstreamRes.ok && upstreamRes.status === 200) {
    void cachePutImage(key, rest, buf, contentType, ttl);
  }

  return new Response(method === "HEAD" ? null : buf, {
    status: upstreamRes.status,
    headers: {
      "Content-Type": contentType,
      "Cache-Control": upstreamRes.ok ? cacheControlFor(ttl) : "no-store",
      "X-TMDB-Cache": "MISS",
    },
  });
}

export function rewriteConfigurationImages(bodyText) {
  const origin = publicOrigin();
  const imageBase = `${origin}/t/p`;
  try {
    const data = JSON.parse(bodyText);
    if (data && data.images) {
      if (typeof data.images.secure_base_url === "string") {
        data.images.secure_base_url = `${imageBase}/`;
      }
      if (typeof data.images.base_url === "string") {
        data.images.base_url = `${imageBase}/`;
      }
    }
    return JSON.stringify(data);
  } catch {
    return bodyText
      .replaceAll("https://image.tmdb.org/t/p/", `${imageBase}/`)
      .replaceAll("http://image.tmdb.org/t/p/", `${imageBase}/`);
  }
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}
