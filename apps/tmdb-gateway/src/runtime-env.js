/**
 * Shared env for Node (local/Vercel) and Cloudflare Workers.
 * Worker entry calls applyWorkerEnv(env) before handleRequest.
 */

/** @type {Record<string, string>} */
let stringEnv = Object.create(null);

/** @type {R2Bucket | null} */
let r2Binding = null;

/** @type {'node' | 'cloudflare-workers'} */
let runtimeKind = "node";

/**
 * @param {any} env Workers env (string secrets + TMDB_R2 binding)
 */
export function applyWorkerEnv(env) {
  runtimeKind = "cloudflare-workers";
  stringEnv = Object.create(null);
  r2Binding = null;
  if (!env || typeof env !== "object") return;

  for (const key of Object.keys(env)) {
    const v = env[key];
    if (typeof v === "string") {
      stringEnv[key] = v;
      if (typeof process !== "undefined" && process.env) {
        process.env[key] = v;
      }
    }
  }

  if (env.TMDB_R2 && typeof env.TMDB_R2.put === "function") {
    r2Binding = env.TMDB_R2;
  }
}

export function runtimeName() {
  return runtimeKind;
}

/** @returns {R2Bucket | null} */
export function getR2Binding() {
  return r2Binding;
}

/**
 * @param {string} key
 * @param {string} [fallback]
 */
export function envGet(key, fallback = "") {
  const fromMap = stringEnv[key];
  if (fromMap != null && fromMap !== "") return fromMap;
  if (typeof process !== "undefined" && process.env) {
    const v = process.env[key];
    if (v != null && String(v) !== "") return String(v);
  }
  return fallback;
}
