# Issue 037: Webstreaming must validate open for every provider

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/`, `apps/forja/lib/shared/playback/`, webstreaming Play

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 7** fix · **0 / 1** device smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I37-T01 | Pre-open HTTP reachability probe in `_trySourcesFromIndex` (desktop + mobile) for every provider | ✅ |
| 2 | I37-T02 | Failover roulette marks provider success only after playbackConfirmed | ✅ |
| 3 | I37-T03 | Disk-cache webstreaming extracts only after confirmed play (not on resolve alone) | ✅ |
| 4 | I37-T04 | Default order + episode builtin keys include Vidzee / VidRock / all registry embeds | ✅ |
| 5 | I37-T05 | Manual smoke: green Play walks dead CDN → next providers until video plays | ⬜ |
| 6 | I37-T06 | Disable in-player auto provider/source failover — fail with error; user picks Sources | ✅ |
| 7 | I37-T07 | Server dots gray until play/check; reject junk extracts (`demo-video`, relative paths) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I37-A01 | Dead HLS from any server fails probe/open and Auto continues the full settings order | ✅ |
| 2 | I37-A02 | Cache reuse never stores an extract that never reached `_playbackConfirmed` | ✅ |
| 3 | I37-A03 | Feature docs describe probe-before-open for all built-in providers | ✅ |
| 4 | I37-A04 | In-player dead stream stops (no silent hop); Sources stays open for manual pick | ✅ |
| 5 | I37-A05 | Extract-only / unchecked servers stay gray — green only when playing or URL-checked | ✅ |

---

## Summary

Green **Play** treated “extractor returned a URL” as enough for some paths (early roulette ✓, disk cache before mpv). Dead CDNs (e.g. WebStreamr / VidSrc HLS) then burned long mpv timeouts before failover. This issue tracks the **shared** fix for **all** built-in webstreaming servers — not VidSrc/Vidzee alone.

### Symptom (before)

- Cache or race winner opens `master.m3u8` that `ffurl_read` cannot fetch
- Roulette / score can show success before video decodes
- Next Play reuses the bad extract
- In-player autofailover hopped vidzee → vidrock demo → unknown providers while UI stayed green

### Fix (landed in code)

- `validateStreamSourceForCheck` before mpv open for every non-torrent source
- Details screen no longer writes webstreaming disk cache on bare resolve; player persists after confirm
- Default provider order + episode host-adapter fallback keys cover the full embed set
- **No in-player autofailover** — `_failPlaybackNoFailover` stops; user picks another server
- Junk extracts filtered (`isUnplayableCachedStreamUrl`); server glyph green only after play/check

### Related

- [Webstreaming](../features/movies-tv/direct-streaming-mode.md)
- [Stream providers](../features/sources/stream-providers.md)
- [RFC-031](../rfc/031-[open]-source-engine-middleware.md) Auto failover (details Play resolve only)
