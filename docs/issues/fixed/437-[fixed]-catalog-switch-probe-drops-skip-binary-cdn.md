# 437 — Catalog switch probe drops `probe:skip` and false-fails binary CDNs

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Player catalog switch · stream probe · DahmerMovies / workers.dev

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I437-T01 | Pass pack `probe` on desktop/mobile catalog switch `validateStreamSourceForCheck` | ✅ |
| 2 | I437-T02 | Range-only headOrRange probe (no fake HEAD→full GET) + cap binary/Range HTTP body in stremio fetch | ✅ |
| 3 | I437-T03 | Unit test + changelog + engine 3.1.4 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I437-A01 | Unit: `validateStreamSourceForCheck` with `probe: skip` returns true without HTTP | ✅ |
| 2 | I437-A02 | App: DahmerMovies workers.dev row opens (no `switch probe failed`) after CF DNS off (manual) | ⬜ |

---

## Summary

DahmerMovies returns playable `*.workers.dev/d/…` file URLs with `probe: 'skip'`. Catalog switch built a `StreamSource` **without** that field, so Forja ran `headOrRange` via `engineHttp`. That path mapped HEAD→full GET and UTF-8-decoded the body — a ~GB `.mkv` timed out / failed while the same URL downloaded fine in a browser → `switch probe failed`.

**Root fix:** honor pack `probe` on switch; Range-only reachability probe; stremio HTTP caps binary/Range bodies so a probe never pulls a full media object.

### Verify

```bash
cd apps/forja && flutter test test/player_playback_headers_test.dart
cargo test -p stremio binary_content_types_are_capped
# Manual: Sources → DahmerMovies → open a workers.dev row
```

## Related

- [340](340-[fixed]-dahmermovies-st111477-rate-limit.md) — addon rate-limit (listings)
- [218](218-[fixed]-dimatoon-green-play-probe-false-fail.md) — probe skip trust pattern
