/**
 * Cloudflare Workers entry for TMDB gateway.
 * Custom domain: tmdb.forjahq.xyz
 */

import { applyWorkerEnv, envGet } from "./runtime-env.js";
import { handleRequest } from "./proxy.js";

export default {
  /**
   * @param {Request} request
   * @param {any} env
   * @param {ExecutionContext} ctx
   */
  async fetch(request, env, ctx) {
    applyWorkerEnv(env);
    try {
      return await handleRequest(request);
    } catch (err) {
      console.error("[tmdb-gateway]", err);
      return new Response(JSON.stringify({ error: "Internal error" }), {
        status: 500,
        headers: { "Content-Type": "application/json; charset=utf-8" },
      });
    }
  },

  /**
   * Daily purge — wrangler triggers crons = ["0 4 * * *"]
   * @param {ScheduledEvent} _event
   * @param {any} env
   * @param {ExecutionContext} ctx
   */
  async scheduled(_event, env, ctx) {
    applyWorkerEnv(env);
    const secret =
      envGet("TMDB_CACHE_PURGE_SECRET") || envGet("CRON_SECRET");
    if (!secret) {
      console.warn("[tmdb-gateway] cron purge skipped — no TMDB_CACHE_PURGE_SECRET");
      return;
    }
    const origin = envGet("TMDB_GATEWAY_PUBLIC_URL") || "https://tmdb.forjahq.xyz";
    const req = new Request(`${origin.replace(/\/$/, "")}/internal/purge-expired`, {
      method: "GET",
      headers: { Authorization: `Bearer ${secret}` },
    });
    ctx.waitUntil(
      handleRequest(req)
        .then(async (res) => {
          const text = await res.text().catch(() => "");
          console.log("[tmdb-gateway] cron purge", res.status, text.slice(0, 200));
        })
        .catch((err) => console.error("[tmdb-gateway] cron purge failed", err)),
    );
  },
};
