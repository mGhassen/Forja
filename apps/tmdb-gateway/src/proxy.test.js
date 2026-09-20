import test from "node:test";
import assert from "node:assert/strict";
import {
  classifyPath,
  isAllowedApiPath,
  cacheKeyFor,
  ttlSecondsFor,
  rewriteConfigurationImages,
  apiKeysFromEnv,
  nextApiKey,
  resetApiKeyCursor,
} from "./proxy.js";

test("classifyPath strips api prefix and detects kinds", () => {
  assert.equal(classifyPath("/3/movie/550").kind, "api");
  assert.equal(classifyPath("/3/movie/550").rest, "movie/550");
  assert.equal(classifyPath("/api/3/search/movie").rest, "search/movie");
  assert.equal(classifyPath("/t/p/w500/abc.jpg").kind, "image");
  assert.equal(classifyPath("/t/p/w500/abc.jpg").rest, "w500/abc.jpg");
  assert.equal(classifyPath("/health").kind, "health");
});

test("isAllowedApiPath allowlist", () => {
  assert.equal(isAllowedApiPath("movie/550"), true);
  assert.equal(isAllowedApiPath("configuration"), true);
  assert.equal(isAllowedApiPath("trending/movie/day"), true);
  assert.equal(isAllowedApiPath("admin/secret"), false);
});

test("cacheKeyFor drops api_key", () => {
  const qs = new URLSearchParams("api_key=secret&query=Inception");
  assert.equal(cacheKeyFor("api", "search/movie", qs), "api:search/movie?query=Inception");
});

test("ttlSecondsFor tiers", () => {
  assert.equal(ttlSecondsFor("image", "w500/x"), 7 * 24 * 60 * 60);
  assert.equal(ttlSecondsFor("api", "configuration"), 3600);
  assert.equal(ttlSecondsFor("api", "trending/movie/day"), 20 * 60);
  assert.equal(ttlSecondsFor("api", "movie/550"), 8 * 60);
});

test("rewriteConfigurationImages points at gateway /t/p", () => {
  process.env.TMDB_GATEWAY_PUBLIC_URL = "https://tmdb.forjahq.xyz";
  const out = rewriteConfigurationImages(
    JSON.stringify({
      images: {
        base_url: "http://image.tmdb.org/t/p/",
        secure_base_url: "https://image.tmdb.org/t/p/",
      },
    }),
  );
  const data = JSON.parse(out);
  assert.equal(data.images.secure_base_url, "https://tmdb.forjahq.xyz/t/p/");
  assert.equal(data.images.base_url, "https://tmdb.forjahq.xyz/t/p/");
});

test("imageStoragePath mirrors TMDB", async () => {
  const { imageStoragePath } = await import("./cache.js");
  assert.equal(imageStoragePath("w500/abc.jpg"), "t/p/w500/abc.jpg");
});

test("apiKeysFromEnv parses TMDB_API_KEYS round-robin pool", () => {
  const keys = apiKeysFromEnv({
    TMDB_API_KEYS: "aaa, bbb\nccc,aaa",
    TMDB_API_KEY: "ignored-when-multi-set",
  });
  assert.deepEqual(keys, ["aaa", "bbb", "ccc"]);
});

test("apiKeysFromEnv falls back to TMDB_API_KEY", () => {
  assert.deepEqual(apiKeysFromEnv({ TMDB_API_KEY: "only" }), ["only"]);
});

test("nextApiKey round-robins", () => {
  const prev = process.env.TMDB_API_KEYS;
  process.env.TMDB_API_KEYS = "k1,k2,k3";
  delete process.env.TMDB_API_KEY;
  resetApiKeyCursor(0);
  assert.equal(nextApiKey(), "k1");
  assert.equal(nextApiKey(), "k2");
  assert.equal(nextApiKey(), "k3");
  assert.equal(nextApiKey(), "k1");
  if (prev == null) delete process.env.TMDB_API_KEYS;
  else process.env.TMDB_API_KEYS = prev;
});
