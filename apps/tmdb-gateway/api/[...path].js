import { handleRequest } from "../src/proxy.js";

/**
 * Vercel serverless catch-all.
 * Rewrites map /3/*, /t/p/*, /health → /api/... so `path` segments are preserved.
 */
export default async function handler(req, res) {
  try {
    const host = req.headers.host || "localhost";
    const proto = req.headers["x-forwarded-proto"] || "https";
    const segments = req.query.path;
    let pathname = "/";
    if (Array.isArray(segments)) {
      pathname = `/${segments.join("/")}`;
    } else if (typeof segments === "string" && segments) {
      pathname = `/${segments}`;
    } else if (typeof req.url === "string") {
      pathname = req.url.split("?")[0] || "/";
      if (pathname.startsWith("/api/")) pathname = pathname.slice(4);
      else if (pathname === "/api") pathname = "/";
    }

    const search = typeof req.url === "string" && req.url.includes("?")
      ? req.url.slice(req.url.indexOf("?"))
      : "";
    const url = new URL(`${pathname}${search}`, `${proto}://${host}`);

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
