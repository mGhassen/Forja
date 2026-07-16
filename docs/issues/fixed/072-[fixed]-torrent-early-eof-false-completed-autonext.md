# 072 — Local torrent early EOF triggers false playback completed / auto-next

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player`, local torrent streams

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **3 / 4** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I72-T01 | Require decoded video before confirming local torrent playback (moov duration alone is not enough) | ✅ |
| 2 | I72-T02 | Gate natural end / auto-next on ≥45s confirmed playback (reject early EOF with real duration) | ✅ |
| 3 | I72-T03 | Skip watch-history near-end saves from early-EOF sessions (do not poison resume) | ✅ |
| 4 | I72-T04 | Unit coverage for early-EOF natural-end + persist guards + local-torrent decode requirement | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I72-A01 | Unit: EOF seconds after confirm with full duration is not a natural end | ✅ |
| 2 | I72-A02 | Unit: near-end progress within grace window is not persisted | ✅ |
| 3 | I72-A03 | Unit: local torrent stream URLs require video decode | ✅ |
| 4 | I72-A04 | Manual: play season-pack torrent → stays on E1 until real end; no instant auto-next / freeze | ⬜ |

---

## Summary

Local torrent `.mp4` streams demux a real episode duration from the moov atom before any frame. mpv then hits EOF while pieces are still missing. The player treated that as a natural end (`pos ≈ dur`), logged `Playback completed`, auto-advanced to the next episode, and kicked off a torrent search while the UI looked frozen.

The tiny-duration guard (`dur < 90s`) did not cover this path. Root fix: require a decoded video frame before confirming local torrent opens, and require ≥45s of confirmed playback before EOF can auto-next. Early-EOF near-end positions are not written to watch history.

## Related

- [024](024-[open]-local-torrent-mpv-format-probe-race.md) — stream-head / format-probe race (open smoke remains)
- Changelog `1.2.x` — prior tiny-duration auto-next fix
