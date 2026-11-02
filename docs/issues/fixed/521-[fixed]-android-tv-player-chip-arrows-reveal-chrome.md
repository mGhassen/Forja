# 521 — Android TV player floating chips: arrows must not reveal chrome; → stays on X

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · player chrome · floating chips  
**Reported:** 2026-11-02 (chips pop / Next Episode → jumps to Play and shows chrome)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On Android TV, when **Skip Intro** / **Skip Recap** / **Next Episode** is focused with chrome **hidden**, D-pad arrows that the chip did not consume bubbled into the video key handler and **revealed chrome** (←/→ → Play, ↑ → Back). With chrome **already up**, → from a countdown **Next Episode** chip could spatial-focus **Play** instead of the cancel **X**.

Product rule: if chrome is already showing, keep it; if it is hidden, do not show it just because a chip is up or the user D-pads on the chip. Focus lands on chips when they appear. Countdown Next Episode → focuses **X**.

## Root cause

1. `PlayerTvKeyScope` treated every unused navigation key on a focused floating chip like the video node, including arrows → `onFocusPlay` / `onFocusBack` revealed chrome (`player_tv_key_scope.dart`).
2. Skip / Next Episode chip key handlers returned `ignored` for ←/→ in cases spatial focus could walk to Play while chrome was visible (`PlayerFloatingChip`, `PlayerNextEpisodeChip`).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I521-T01 | Swallow arrow keys on floating-chip focus when chrome is hidden (do not reveal) | ✅ |
| 2 | I521-T02 | Trap ←/→ on Skip + Next Episode chips so spatial focus cannot jump to Play; → → X with countdown | ✅ |
| 3 | I521-T03 | Widget tests: chrome stays hidden on chip arrows; chrome-up → reaches X not Play | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I521-A01 | ATV: chrome hidden + Skip / Next Episode focused → D-pad arrows do not show chrome | ⬜ |
| 2 | I521-A02 | ATV: Next Episode countdown focused (chrome up or hidden) → focuses X, not Play | ⬜ |

## Links

- [506](506-[fixed]-android-tv-player-skip-next-ep-chip-autofocus.md) — appear autofocus
- [RFC-122](../../rfc/122-[draft]-android-tv-remote-ux.md)
- [next-episode.md](../../features/playback/next-episode.md)
