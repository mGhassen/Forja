# 205 — Mid-watch network drop: remount instead of Failed / Retry

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/player/` (MediaKit + Exo VOD; IPTV already has lavf reconnect)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I205-T01 | Shared network-error classifier + wait-for-online + remount attempt helper | ✅ |
| 2 | I205-T02 | MediaKit mobile + desktop: mid-watch fatal → remount same URL at position before hop / Retry | ✅ |
| 3 | I205-T03 | ExoPlayer: mid-watch error → remount same URL before Failed / Retry | ✅ |
| 4 | I205-T04 | VOD MediaKit: lavf `reconnect=*` (parity with IPTV) for brief socket blips | ✅ |
| 5 | I205-T05 | Unit: classifier + remount-only-when-online logic | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I205-A01 | MediaKit VOD: kill Wi‑Fi mid-watch, restore → Reconnecting… then resume near prior position (no Failed / Retry) | ⬜ |
| 2 | I205-A02 | Exo VOD: same offline→online remount; if remount still fails after retries → existing Retry / Auto hop | ⬜ |

---

## Summary

VOD MediaKit/Exo treated mid-watch socket death as a hard failure (`Failed to open…` → **Failed / Retry** or Auto hop). IPTV already sets lavf reconnect + watchdog remount. Offline then online must remount the **same** URL at the last position first; only then fall through to issue [175](175-[open]-mid-watch-auto-failover.md) hop / pin Retry.

**Root fix:** detect mid-watch fatals, wait for connectivity, remount via existing `remountPlayerStreamAtPosition` / Exo open-at-position; enable lavf reconnect on VOD MediaKit.

---

## Related

- [175](175-[open]-mid-watch-auto-failover.md) — CDN death Auto hop (after remount fails)
- [184](184-[open]-post-seek-buffering-remount.md) — post-seek remount (same URL helpers)
- [Player](../features/playback/player.md)
