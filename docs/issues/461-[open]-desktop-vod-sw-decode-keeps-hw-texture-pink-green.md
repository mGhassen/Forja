# 461 — Desktop VOD SW decode still used HW texture (pink/green)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** desktop · player · MediaKit  
**Reported:** 2026-10-23 (manual macOS playback — pink/green picture; SW setting unchanged)

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 7** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

macOS desktop VOD shows inverted / pink+green colors. Player Settings → Video decode → **SW** did not fix it.

## Root cause

Desktop always created `VideoController` with `enableHardwareAcceleration: true` (TextureHW). The Video decode menu only set mpv `hwdec` — **SW** never flipped soft texture (TextureSW). Pink/green matches chroma misuse on the HW texture path.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I461-T01 | SW → `enableHardwareAcceleration: false` + `hwdec=no` on create / PiP restore | ✅ |
| 2 | I461-T02 | Live Video decode switch recreates VideoController when soft-texture boundary flips | ✅ |
| 3 | I461-T03 | macOS desktop: force soft TextureSW always + default Video decode SW (match PiP) | ✅ |
| 4 | I461-T04 | Native VideoOutput.swift force TextureSW on macOS (pub-cache AimesSoft media-kit) | ✅ |
| 5 | I461-T05 | Desktop mpv HDR→SDR tone-map (tone-mapping/target-prim/trc) for 4K green/magenta | ✅ |
| 6 | I461-T06 | Root: upstream TextureHW chroma + lasting fork patch (pub-cache wipe risk) | ⬜ |
| 7 | I461-T07 | Keep soft TextureSW; default decode → `autoSafe` (VT copy-back) — full SW starved MegaPlay strip HLS ([510](510-[open]-megaplay-pngstrip-vod-prefetch-desync.md)) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I461-A01 | Full restart → Carrie (or failing title) shows normal colors; log `VideoOutput: enableHardwareAcceleration: false` + `TextureSW: resize` | ⬜ |
| 2 | I461-A02 | UI chrome stays correct; picture is not pink/green | ⬜ |

## Links

- Related: `033-[open]-vod-decoder-recovery.md` (hw→software fallback wiring)
- Related: `docs/issues/fixed/359-[fixed]-live-sports-stremio-vt-hold-corrupt-frames.md` (VT chroma-ish live)
