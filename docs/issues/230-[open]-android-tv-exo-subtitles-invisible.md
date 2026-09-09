# 230 — Android TV ExoPlayer: subtitles selected but invisible (Xiaomi / PlatformView)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · ExoPlayer · subtitles · PlatformView

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I230-T01 | Kotlin: forward Media3 `onCues` text lines on the Exo event channel; hide native `SubtitleView` | ✅ |
| 2 | I230-T02 | Dart: paint cue overlay above `ExoPlayerView` with existing size/color/bg/position prefs | ✅ |
| 3 | I230-T03 | Feature doc + changelog — Exo subs render in Flutter on Android | ✅ |
| 4 | I230-T04 | Auto-select: never fall back to first unlabeled text track (CEA-608 “Track 1”); language match only like MediaKit | ✅ |
| 5 | I230-T05 | Anonymous CEA must not block Wyzie/Levrx auto-sideload; expose `mimeType` on Exo text tracks | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I230-A01 | Xiaomi (or any) Android TV Exo VOD: pick English SRT/VTT or in-stream text → cues visible over video; Off clears; style sliders still apply | ⬜ |

---

## Summary

On **Android TV** (reported **Xiaomi / Android 11**), ExoPlayer can select a text track (menu shows active language) while **no subtitle paint** appears on screen.

**Root cause (paint):** Media3 `PlayerView.subtitleView` lives inside the Flutter **PlatformView** (`AndroidView` / VirtualDisplay for TextureView). Cue-only View invalidates often do not refresh the VD buffer on OEM TV GPUs, so video frames keep updating while subtitle Canvas updates never reach the Flutter texture. Same class of debt as issue [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) (move subtitle paint out of `PlayerView`).

**Root fix (paint):** decode cues in Media3 → emit `cues` events → Flutter overlay above the platform view. Hide native `SubtitleView` to avoid double paint where VD does refresh.

**Root cause (auto-select, ATV emulator 2026-09):** preferred-language auto-pick fell through to `_tracks.text.firstOrNull` — often anonymous HLS **CEA-608** labeled `Track 1`. Log: `auto subtitle → Track 1` + `Cea608Decoder: Invalid channel`. Cues stay empty while the menu looks selected; Wyzie/Levrx never load because `text.isNotEmpty` short-circuited external auto-pick. MediaKit’s `pickEmbeddedSubtitleWithFallback` never does this first-track fallback.

**Root fix (auto-select):** language-match only; skip `isAnonymousClosedCaption`; let external sideload run when mux has no usable language tag.

**Out of scope:** ASS/SSA (still MediaKit / issue [032](032-[draft]-exoplayer-parity-gaps.md)); bitmap/PGS image cues.

## Related

- [132](132-[open]-android-tv-exo-auto-subtitle-merging-crash.md) — auto-select crash (selection path)
- [032](032-[draft]-exoplayer-parity-gaps.md) — Exo subtitle parity
- [features/playback/subtitles.md](../features/playback/subtitles.md)
