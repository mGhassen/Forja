# 047 — Vidsrc standalone broken: wrong resolve request + stale vsembed.ru host

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/resolver-engine/src/plugins/vidsrc.rs`, `crates/webstreamr` Vidsrc embed URLs

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix tasks · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I47-T01 | `VidsrcProvider` passes `tmdb_id` / season / episode to `resolve_vidsrc_embed_json` (stop using template `build_*_url` + `embedUrl`) | ✅ |
| 2 | I47-T02 | Move embed host `vsembed.ru` / `vidsrc-embed.ru` → `vsembed.su` with documented query/path shapes | ✅ |
| 3 | I47-T03 | Update Dart `VidsrcExtractor` helpers, WebStreamr source goldens, feature tip | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I47-A01 | `./scripts/resolve-engine.sh -p vidsrc --tmdb=94997 --media=tv --season=1 --episode=1 --native-only` returns ≥1 HLS source | ✅ |
| 2 | I47-A02 | Embed URL built as `https://vsembed.su/embed/tv?tmdb=94997&season=1&episode=1` | ✅ |

---

## Summary

Standalone **Vidsrc** failed in Forja while the website player worked. Two stacked bugs:

1. **Resolver plugin never called the extractor correctly** — `VidsrcProvider` used `stream_core::build_tv_url("vidsrc", …)` (template-only → `None`) and sent `{"embedUrl": …}` while Rust expects `tmdb_id` / `is_movie` / season / episode. Resolve finished in ~0 ms with no streams.
2. **Stale embed domain / shape** — site announced `vsembed.ru` → **`vsembed.su`** and documents query embeds (`/embed/tv?tmdb=&season=&episode=`). Forja still used `vsembed.ru` path-style and WebStreamr’s `vidsrc-embed.ru`.

## Verify

```bash
./scripts/resolve-engine.sh -p vidsrc --tmdb=94997 --media=tv --season=1 --episode=1 --native-only
cd crates && cargo test -p webstreamr vidsrc --lib
```

## Related

- [036](036-[fixed]-vidsrc-cloudnestra-cdn-host-stale.md) — CDN host derivation (still valid)
- Feature tip: [stream-providers.md](../../features/sources/stream-providers.md)
