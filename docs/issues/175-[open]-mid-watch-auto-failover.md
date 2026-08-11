# 175 — Mid-watch CDN death: Auto hop (resume seek)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/player/*_player_playback.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I175-T01 | Desktop: mid-watch fatal open → siblings then `_reresolveLikeFirstPlay` with resume seek when Auto / not pinned | ✅ |
| 2 | I175-T02 | Mobile: same mid-watch Auto hop path as desktop | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I175-A01 | Auto On: play a Videasy (or similar) title until CDN dies mid-watch — roulette hops, playback resumes near prior position; pin / Auto Off still stops for Retry | ⬜ |

---

## Summary

After playback confirmed, a fatal mpv `Failed to open` (dead CDN, ABR variant death) always called `_showPlaybackFailureOnWatch` — **never** auto-hop — even with Auto On. Open/probe already hops (issue [037](037-[open]-webstreaming-all-providers-open-validate.md) I37-T08). Feature docs already claimed mid-play continue; code stopped.

**Root fix:** when not pinned / not `streamsPrevalidated`, mid-watch failure marks the dead source, tries remaining siblings, then full Auto re-resolve like first Play, seeking back to the watch position. Pin / Auto Off keep stop + Retry.

---

## Related

- [037](037-[open]-webstreaming-all-providers-open-validate.md) — Auto open failover vs pin stop
- [043](fixed/043-[fixed]-dead-cache-full-auto-reresolve.md) — dead cache → re-resolve
- [Stream providers](../features/sources/stream-providers.md)
- [Player](../features/playback/player.md)
