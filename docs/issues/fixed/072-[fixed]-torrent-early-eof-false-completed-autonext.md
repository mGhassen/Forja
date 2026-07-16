# 072 — Local torrent early EOF triggers false playback completed / auto-next

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player`, local torrent streams

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 9 / 9** fix · **4 / 6** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I72-T01 | Require decoded video before confirming local torrent playback (moov duration alone is not enough) | ✅ |
| 2 | I72-T02 | Gate natural end / auto-next on ≥45s confirmed playback (reject early EOF with real duration) | ✅ |
| 3 | I72-T03 | Skip watch-history near-end saves from early-EOF sessions (do not poison resume) | ✅ |
| 4 | I72-T04 | Unit coverage for early-EOF natural-end + persist guards + local-torrent decode requirement | ✅ |
| 5 | I72-T05 | Continue Watching / history resume uses 2–90% rule (≥90% restarts from 0) | ✅ |
| 6 | I72-T06 | Do not set mpv `start` / seek into credits for near-end resume positions | ✅ |
| 7 | I72-T07 | Details hero: finished (≥90%) shows Play + clear trash, not Resume into credits | ✅ |
| 8 | I72-T08 | Latch abortive `completed`; require mid-episode playback before natural end | ✅ |
| 9 | I72-T09 | Seek bar: safe global pointer detach + no setState after dispose | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I72-A01 | Unit: EOF seconds after confirm with full duration is not a natural end | ✅ |
| 2 | I72-A02 | Unit: near-end progress within grace window is not persisted | ✅ |
| 3 | I72-A03 | Unit: local torrent stream URLs require video decode | ✅ |
| 4 | I72-A04 | Manual: play season-pack torrent → stays on E1 until real end; no instant auto-next / freeze | ⬜ |
| 5 | I72-A05 | Manual: after false-finished history, Continue Watching / Play starts from beginning | ⬜ |
| 6 | I72-A06 | Unit: stuck EOF without mid-playback is not natural even after grace | ✅ |

---

## Summary

Local torrent `.mp4` streams demux a real episode duration from the moov atom before any frame. mpv then hits EOF while pieces are still missing. The player treated that as a natural end (`pos ≈ dur`), logged `Playback completed`, auto-advanced to the next episode, and kicked off a torrent search while the UI looked frozen.

The tiny-duration guard (`dur < 90s`) did not cover this path. Root fix: require a decoded video frame before confirming local torrent opens, and require ≥45s of confirmed playback before EOF can auto-next. Early-EOF near-end positions are not written to watch history.

A follow-on failure: poisoned ≥90% history made Continue Watching resume at the credits (raw position), so replay looked broken. History resume now uses the same 2–90% rule as details; near-end mpv `start` seeks were removed; finished titles show **Play** (not Resume) with a clear-progress control.

## Related

- [024](024-[open]-local-torrent-mpv-format-probe-race.md) — stream-head / format-probe race (open smoke remains)
- Changelog `1.2.x` — prior tiny-duration auto-next fix
