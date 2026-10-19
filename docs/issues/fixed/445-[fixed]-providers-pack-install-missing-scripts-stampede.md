# 445 — Providers pack install fails with fake “missing scripts”

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Settings → Forja Packs · plugin install · Android / emulator

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I445-T01 | Bound pack-file CDN fetch concurrency (no unbounded `Future.wait`) | ✅ |
| 2 | I445-T02 | Retry transient GET failures; log real errors instead of silent `catch (_)` | ✅ |
| 3 | I445-T03 | Unit test: flaky script GET succeeds on retry + changelog | ✅ |
| 4 | I445-T04 | Install mutates a mutable copy of `listPacksRaw` (empty mem is `const []`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I445-A01 | Android emulator: Install ForjaHQ Providers from GitHub raw completes without “missing scripts” | ⬜ |

---

## Summary

Installing the providers pack from `raw.githubusercontent.com` failed with `missing scripts: megaplay.js, hdhub4u.js, anizone.js` while those files exist on `main`. Small hub packs (4–15 bundle files) installed fine.

**Root:** `_installUnlocked` fired every bundle path in one unbounded `Future.wait` (~138 parallel `PackHttp` clients). A few GETs failed on the emulator; `catch (_)` turned that into “missing scripts.”

**Fix:** `mapBoundedParallel` (concurrency 6) + up to 3 attempts with short backoff; log the real error on final failure.
