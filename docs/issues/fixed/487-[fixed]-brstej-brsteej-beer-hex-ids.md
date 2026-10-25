# 487 — Brstej / Aflem empty after site moved to brsteej.beer

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs` · Aflem hub (`hubs/aflem`) · provider `brstej`  
**Reported:** 2026-10-25 (flutter: `brstej extract error: HTTP 404`; Aflem rails empty)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Aflem catalog rails and search returned no (or almost no) cards. Opening a show and running Brstej extract logged `HTTP 404` on `play.php` and `raw=0 streams=0`.

## Root cause

Upstream rebranded:

- Origin `hd1.brstej.com` / `uo.brstej.com` → `https://brsteej.beer`
- Series ids numeric → hex (`series1.php?id=eb59ad819`)
- Episode pages `watch.php` → `video.php` (watch still redirects)

Pack parsers required `\d+` series ids and `watch.php` only → **0 cards**. Provider still called `play.php` with stale numeric vids → **404**. Live check: hex `play.php?vid=` returns 200 with `data-embed-url` servers.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I487-T01 | Point Aflem + `brstej` provider origin at `https://brsteej.beer` | ✅ |
| 2 | I487-T02 | Accept alnum series ids; parse `video.php` alongside `watch.php` in catalog / details | ✅ |
| 3 | I487-T03 | Details + provider referer use `video.php`; bump aflem `1.0.28` / providers `1.6.72` | ✅ |
| 4 | I487-T04 | Config origin = `https://brstej.com`; pin live host from first `res.url` (aflem `1.0.29` / providers `1.6.73`) | ✅ |
| 5 | I487-T05 | Details: story plot (not SEO meta), genres from الأقسام, year/runtime releaseInfo, episode `overview` (aflem `1.0.30`) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I487-A01 | Manual: Aflem rails show series/episodes again; search finds titles | ⬜ |
| 2 | I487-A02 | Manual: open a show → episode → Brstej returns streams (no `HTTP 404`) | ⬜ |

## Links

- [419](../419-[open]-aflem-hub-home-page-only.md) — Aflem rail coverage (parsers assumed numeric/`watch.php`)
- [RFC-077](../../rfc/fixed/077-[fixed]-brstej-hub-laroza-only-arabic.md) — hub split (historical `uo.brstej.com`)
- [Aflem feature guide](../../features/hubs/aflem.md)
