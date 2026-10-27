# 508 — Android TV: online (Wyzie) subtitle loads on Exo with no cues; MediaKit shows no loading

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · ExoPlayer · MediaKit · online subtitles (Wyzie)  
**Reported:** 2026-10-28 (ATV: Exo Wyzie FR loading then blank; MediaKit no loading; desktop MediaKit OK)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On **Android TV**, picking an online subtitle (e.g. Wyzie French):

1. **ExoPlayer** — status chip shows loading (and often success), but **no cues** on screen.
2. **MediaKit** — **no loading chip** at all; cues may never appear (or the pick looks like a no-op while download runs).
3. **Desktop MediaKit** — same Wyzie pick works immediately.

## Root cause

| Path | Cause |
|------|--------|
| Exo | `_prepareSubtitleSideload` chose `.srt` from the **download URL path** (Wyzie/CDN URLs are often extensionless). Body could be **WEBVTT**; Media3 then sideloaded as SubRip → track accepted, **cues empty**. MediaKit already sniffed the body via `externalSubtitleFileExtension`. Cached mislabeled files stayed wrong because pack never set content `mime`. |
| MediaKit UX | Mobile/TV `_loadOnlineSubtitle` never showed a loading/success chip on manual pick (Exo did). |
| Overlay | Exo Flutter cue layer sat **under** `_coverDeadSurface` black cover (MediaKit paints cues above). |

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I508-T01 | Exo: sniff body for extension + Media3 `mime`; reject ASS; pack always sets content mime (cache-safe) | ✅ |
| 2 | I508-T02 | MediaKit mobile/TV: loading / success / failed StatusRoulette on manual online pick (Exo parity) | ✅ |
| 3 | I508-T03 | Exo: paint cue overlay above dead-surface cover | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I508-A01 | Android TV Exo: pick Wyzie (or any online) FR/EN → loading chip → cues visible; Off clears | ⬜ |
| 2 | I508-A02 | Android TV MediaKit: same pick shows loading then cues (or failed toast) | ⬜ |

## Links

- [230](230-[open]-android-tv-exo-subtitles-invisible.md) — Flutter cue paint / CEA auto-select
- [458](fixed/458-[fixed]-exo-online-subtitle-pick-no-op-and-menu-twins.md) — online pick / twins
- [507](507-[open]-exo-hls-instream-subtitles-no-cues.md) — HLS In-stream (separate)
