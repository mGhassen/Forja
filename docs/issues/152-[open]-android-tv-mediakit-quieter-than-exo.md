# 152 — Android TV: MediaKit plays quieter than ExoPlayer at the same level

**Status:** open
**Priority:** P2
**Severity:** Medium
**Area:** Playback (Android TV, MediaKit vs ExoPlayer)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 5** fix tasks · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | I152-T01 | Shared `mpvVolumeForUi` + `kAtvMediaKitVolumeGain` (1.3) in player `utils.dart` | ✅ |
| 2 | I152-T02 | IPTV MediaKit applies the gain and sets `volume-max=150` on the ATV branch | ✅ |
| 3 | I152-T03 | Movie / anime / drama MediaKit (`TvPlayerScreen` → `MobilePlayerScreen`) applies the gain; `volume-max=200` on TV | ✅ |
| 4 | I152-T04 | Verify the gain on a real box against Exo and tune the constant | ⬜ |
| 5 | I152-T05 | Decide whether loud peaks need a limiter (`af=acompressor` / `dynaudnorm`) instead of raw softvol | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | I152-A01 | Android TV: switching IPTV between Exo and MediaKit mid-channel keeps roughly the same loudness at one TV volume step | ⬜ |
| 2 | I152-A02 | Android TV movie / anime / drama MediaKit matches Exo loudness the same way | ⬜ |
| 3 | I152-A03 | Loud 5.1 content does not audibly clip or distort with the boost applied | ⬜ |
| 4 | I152-A04 | Phone and desktop MediaKit loudness is unchanged (gain is TV-only) | ⬜ |

---

## Summary

On Android TV the same stream is audibly quieter under MediaKit than under
ExoPlayer, even though both engines are at full soft volume: the UI level maps
to mpv `volume=100` for MediaKit and to `ExoPlayer.volume = 1.0` for Exo. Users
have to raise TV/soundbar volume after every engine switch.

## Root cause — different audio pipelines, not a mapping bug

| | ExoPlayer | MediaKit |
|---|---|---|
| Decode | MediaCodec (audio) | FFmpeg → PCM |
| Output | `AudioTrack` via Media3 with `USAGE_MEDIA` / `AUDIO_CONTENT_TYPE_MOVIE` | mpv `ao=audiotrack` (forced on ATV — OpenSLES misconfigures on some images) |
| DSP | OEM leanback post-processing, stream DRC / dialog lift | none |
| 5.1 → stereo | platform downmix | mpv software downmix, attenuates more |

Nothing in the app scales one path down. The gap is the pipeline, so parity has
to be bought back with gain.

## Fix (shipped) — TV-only softvol gain

`kAtvMediaKitVolumeGain = 1.3` (≈ +2.3 dB) in
[`utils.dart`](../../apps/forja/lib/shared/player/player/utils.dart); every
MediaKit `setVolume` on a TV goes through `mpvVolumeForUi`, so UI 100 asks mpv
for 130. `volume-max` is raised to cover the boosted ceiling (IPTV 150, movie
player 200 because its slider already reaches 150).

**Honest limits:**

- The constant is a **bench estimate, not measured on a box** (`I152-T04`).
  Perceived parity varies with the OEM's DSP and with how aggressive the
  content's DRC metadata is.
- mpv softvol above 100 has **no limiter** — loud peaks can clip (`I152-A03`).
  If that shows up, the real fix is a filter (`af=acompressor` or
  `dynaudnorm`), not more gain (`I152-T05`).
- Exo's own volume is capped at `1.0`, so this only moves MediaKit up; it
  cannot make Exo quieter to meet in the middle.

## Related

- [138](138-[open]-android-tv-iptv-4k-audio.md) — ATV MediaKit `ao=audiotrack` / unmute restore; same audio path
- [137](137-[open]-android-tv-player-engine-not-remembered.md) — per-surface engine choice, which makes the loudness jump user-visible
