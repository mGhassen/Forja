# Issue 033: VOD player decoder recovery

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** `apps/forja/lib/shared/player/`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 5** verification |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I33-T01 | Split audio vs video decoder errors in `isIgnorablePlayerError` | ✅ |
| 2 | I33-T02 | Port IPTV hw→software decode fallback to VOD player | ✅ |
| 3 | I33-T03 | Decoder failure triggers next scored candidate before provider switch | ✅ |
| 4 | I33-T04 | mpv log listener for hw accelerator failures (media_kit path) | ✅ |
| 5 | I33-T05 | Manual QA on HEVC-failing Android TV device | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I33-A01 | `isVideoDecoderError` vs `isAudioDecoderError` exported from utils | ✅ |
| 2 | I33-A02 | `_forceSoftwareDecode` called once per session on hw fail | ✅ |
| 3 | I33-A03 | ExoPlayer path receives equivalent recovery hook | ✅ |

---

## Summary

VOD player ignored video decoder init failures and treated all decoder errors as ignorable audio noise. IPTV player already recovers via software decode — this issue tracks porting that behavior to movie/TV/anime playback.

## Root cause (historical)

`isIgnorablePlayerError` lumped audio and video decoder failures. No mpv log listener on VOD player for `hardware accelerator failed`.

## Related

- [RFC-030](../rfc/030-[open]-playback-selection-engine.md)
- [iptv_pt_player_screen.dart](../../apps/forja/lib/features/iptv/screens/iptv_pt_player_screen.dart)
