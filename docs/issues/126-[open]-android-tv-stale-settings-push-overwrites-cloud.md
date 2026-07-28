# 126 — Android TV stale local settings push overwrites cloud Features / nav

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** `sync_domain_bridge.dart` · `sync_service.dart` · profile_settings  
**Reported:** 2026-07-28

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I126-T01 | `pullProfileSettings` rethrows on error — `null` only means missing row | ✅ |
| 2 | I126-T02 | `pullAndMergeAll` aborts on pull failure (keep local) — never `seedNewProfileDefaults` + push | ✅ |
| 3 | I126-T03 | Debounced / pending pushes overlay only the edited domain(s); failed cloud pull aborts upsert | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I126-A01 | Android TV cold start with JWT/network pull failure: cloud Features/nav unchanged; device keeps prior local cache | ⬜ |
| 2 | I126-A02 | Toggle a playback pref on TV: cloud navigation / default tab unchanged | ⬜ |

---

## Summary

**Symptom:** Streaming profile on Android TV relaunches into Asian Drama with a thin Features tab set, while Account → Features on the web still shows the full cloud layout (or flips after TV was open). Feels like the TV pushes local defaults over cloud every launch.

**Root cause (same class as [096](fixed/096-[fixed]-iptv-empty-local-cache-wipes-cloud.md) / [099](099-[open]-profile-settings-cloud-master-local-cache.md) / [118](118-[open]-iptv-thin-local-cache-shrinks-cloud.md)):**

1. **`pullProfileSettings` swallowed errors as `null`.** `pullAndMergeAll` treated that as “no row” → `seedNewProfileDefaults()` (TV platform nav + play-source offs) → `pushAllLocal` upserted over cloud. Common on ATV cold start with JWT discard ([109](109-[open]-android-tv-boot-jwt-expired-discard-race.md)).
2. **Every debounced domain push overlaid all lean domains.** A playback toggle still rewrote `payload.navigation` from whatever was in the local cache — so a stale TV nav could poison cloud without the user touching Features.
3. **Merge-on-push used `pull ?? {}`.** A failed pull mid-push built a local-only payload and upserted it, dropping remote keys.

**After:** Failed pulls keep local and never seed/push. Debounced edits overlay only that domain. Full overlay remains for profile switch / new-profile seed / empty-row backfill.

**Related:** [099](099-[open]-profile-settings-cloud-master-local-cache.md) · [109](109-[open]-android-tv-boot-jwt-expired-discard-race.md) · [118](118-[open]-iptv-thin-local-cache-shrinks-cloud.md)

## Verify

1. Sign in on ATV → Streaming → confirm Features match web (Home/Search visible if enabled in cloud; default tab from cloud).
2. Force a failed settings pull (expire AT / airplane) then relaunch — cloud Features on web unchanged.
3. Change only a playback toggle on TV — web Features / default tab unchanged.
