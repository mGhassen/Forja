import { handleRequest } from "../src/proxy.js";

/**
 * Single Vercel entry. Rewrites send the original path as `?__p=...`
 * so multi-segment routes (/3/movie/550, /t/p/...) always hit this function.
 * (api/[...path].js was NOT_FOUND for deep paths on Vercel.)
 */
export default async function handler(req, res) {
  try {
    const host = req.headers.host || "localhost";
    const proto = req.headers["x-forwarded-proto"] || "https";

    let pathname = "/";
    const p = req.query.__p;
    if (typeof p === "string" && p.length) {
      pathname = p.startsWith("/") ? p : `/${p}`;
    } else if (Array.isArray(p) && p.length) {
      pathname = `/${p.join("/")}`;
    } else if (typeof req.url === "string") {
      // Direct hit on /api or /api/health-style without rewrite.
      const raw = req.url.split("?")[0] || "/";
      if (raw === "/api" || raw === "/api/") pathname = "/health";
      else if (raw.startsWith("/api/")) pathname = raw.slice(4);
      else pathname = raw;
    }

    const search =
      typeof req.url === "string" && req.url.includes("?")
        ? req.url.slice(req.url.indexOf("?"))
        : "";
    // Strip our internal __p from the search string passed to the proxy.
    const sp = new URLSearchParams(search.startsWith("?") ? search.slice(1) : search);
    sp.delete("__p");
    const q = sp.toString();
    const url = new URL(`${pathname}${q ? `?${q}` : ""}`, `${proto}://${host}`);

    const request = new Request(url, {
      method: req.method || "GET",
      headers: req.headers,
    });
    const response = await handleRequest(request);
    res.statusCode = response.status;
    response.headers.forEach((value, key) => {
      res.setHeader(key, value);
    });
    const buf = Buffer.from(await response.arrayBuffer());
    res.end(buf);
  } catch (err) {
    console.error("[tmdb-gateway]", err);
    res.statusCode = 500;
    res.setHeader("Content-Type", "application/json");
    res.end(JSON.stringify({ error: "Internal error" }));
  }
}
