# crates/proxy

Local loopback HTTP servers (axum) exposed via FFI.

## Modules

| Module | Role |
|--------|------|
| `LocalProxy` | Generic query/token/HLS/toky/comic/jellyfin/subtitlecat routes |
| `seek111477` | Seekable byte-range proxy for 111477 CDN URLs (chunk cache, reconnect) |

## 111477 — Dart vs Rust split

111477 playback uses **two layers**. Do not conflate them.

| Layer | Location | Responsibility |
|-------|----------|------------------|
| **Index scrape + match** | `packages/api/lib/api/site111477_service.dart` | Fetch `/movies/` and `/tvs/` HTML indexes (~3–8 MB), parse rows, fuzzy TMDB title match, list files in folder. **Cloudflare / rate-limit handling** (HTTP 429, error 1015 body sniff, 7.2s backoff, max 6 retries) lives here. |
| **Seekable stream proxy** | `crates/proxy/src/seek111477.rs` | Given a direct file URL, run localhost axum proxy with chunk cache, range requests, upstream reconnect. No index scrape, no CF challenge logic. |
| **FFI glue** | `packages/api/lib/playback/site111477_proxy.dart` | `seek111477StartJson` / stop / purge — thin wrapper only. |

There is **no** `crates/site111477` crate. P2-92 consolidated the **loopback proxy** into this crate; index scrape intentionally remains in Dart ([ENGINE_BOUNDARY R9](../../docs/ENGINE_BOUNDARY.md#r9--111477-index-scrape-stays-in-dart-legacy-api)).

### Why index scrape stays in Dart (for now)

- HTML directory index + title normalization is catalog-style glue in `packages/api` (Phase 3 delete target).
- CF handling here is **HTTP retry on 429/1015**, not an interactive captcha/WebView flow.
- Rust proxy path only needs the resolved `upstream_url`; it does not duplicate CF logic.

### Future port (optional)

If 111477 index fetch moves to Rust: add `crates/proxy` or `crates/scrapers` module with shared CF retry helper; keep `seek111477` unchanged. Track only if the site changes challenge flow often enough to justify the port.

## FFI

- `seek111477_start_json` — start proxy, returns `{ port, url }`
- `seek111477_stop` / `seek111477_port` / `seek111477_is_running`
- `seek111477_purge_cache_json` — delete chunk cache dir

See `packages/rust/test/parity/seek111477_test.dart`.
