# RFC-083: In-app mini player (inside Forja — not OS PiP)

**Status:** open  
**Depends on:** —  
**Area:** `apps/forja/lib/shared/player/in_app_mini/`, desktop VOD + IPTV players, shell TV focus

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** components · **22 / 22** acceptance |
| **Current slice** | Desktop in-app mini shipped — keep-play + resize · chrome auto-hide · phone deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R83-C01 | `InAppMiniPlayerController` + mini chrome (Play / Pause / Expand / Close) | ✅ |
| 2 | R83-C02 | Settings `in_app_mini_player` (default off) + Playback toggle | ✅ |
| 3 | R83-C03 | Desktop VOD Escape → pause + demote; expand re-`enterPlayerSurface` | ✅ |
| 4 | R83-C04 | Desktop IPTV / Live same demote path | ✅ |
| 5 | R83-C05 | `stopForNewPlay` before `openPlayer` / IPTV open | ✅ |
| 6 | R83-C06 | ShellTvFocus registerMini + chrome doors (top Up / nav Left / hero last Right) | ✅ |
| 7 | R83-C07 | Feature docs + changelog | ✅ |
| 8 | R83-C08 | Top-right In-app mini button on desktop VOD + IPTV chrome | ✅ |
| 9 | R83-C09 | Keep playing on demote; top-left drag resize (16:9); skip lifecycle pause while mini | ✅ |

---

## Acceptance (desktop slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R83-A01 | Setting off: armed Escape exits player (today) | ✅ |
| 2 | R83-A02 | Setting on: armed Escape pauses and demotes to in-Forja corner mini | ✅ |
| 3 | R83-A03 | Mini does not call `PipService` / shrink OS window | ✅ |
| 4 | R83-A04 | Enter mini calls `leavePlayerSurface`; expand calls `enterPlayerSurface` | ✅ |
| 5 | R83-A05 | Mini chrome: Play, Pause, Expand, Close only | ✅ |
| 6 | R83-A06 | Expand resumes if playing before demote (unless user paused in mini) | ✅ |
| 7 | R83-A07 | New Play stops mini then opens normal loading → full player | ✅ |
| 8 | R83-A08 | D-pad: Up from hub top menu → mini when active | ✅ |
| 9 | R83-A09 | D-pad: Left from nav outer wall → mini when active | ✅ |
| 10 | R83-A10 | D-pad: Right from hero last action → mini when active | ✅ |
| 11 | R83-A11 | Catalog rows never jump to mini; Back from mini restores chrome (not Close) | ✅ |
| 12 | R83-A12 | IPTV / Live Matches share the same desktop demote path | ✅ |
| 13 | R83-A13 | Setting on: Escape demotes when chrome already hidden (skip arm — hover cannot clear) | ✅ |
| 14 | R83-A14 | Top-right chrome button demotes when setting on (desktop VOD + IPTV) | ✅ |
| 15 | R83-A15 | Mini: OverlayEntry.opaque synced so shell paints under transparent player route | ✅ |
| 16 | R83-A16 | Mini: same MediaKit Video slot resized (no remount) so picture is not black | ✅ |
| 17 | R83-A17 | Mini: shell / overlay / rails receive pointer hits outside the corner (no full-window Material/MouseRegion/Scaffold hit absorb) | ✅ |
| 18 | R83-A18 | Demote keeps playing (no auto-pause); user pauses from mini chrome | ✅ |
| 19 | R83-A19 | Mini top-left grip resizes 16:9 within ~240–720px width (VOD + IPTV) | ✅ |
| 20 | R83-A20 | OS minimize / app background while mini active does not auto-pause | ✅ |
| 21 | R83-A21 | Mini: `buildModalBarrier` is empty while active — default null-color `ModalBarrier` is `HitTestBehavior.opaque` and blocked shell clicks under the transparent route | ✅ |
| 22 | R83-A22 | Mini chrome (buttons + grip) auto-hides after ~3s idle; hover / tap / D-pad focus reveals; stays while focused or resizing | ✅ |

---

## Summary

In-app mini player: Escape (when enabled) shrinks the player to a corner **inside** the Forja window so the shell stays browsable. Distinct from OS/desktop window PiP (`PipService`). Default setting **off**.

### Goals

- Keep playing on demote (pause only from mini chrome); skip lifecycle pause while mini
- Drag-resize corner (16:9)
- Expand restores full-player shell freeze (`enterPlayerSurface`)
- Three chrome D-pad doors only — never catalog Down to mini

### Related

- [In-app mini player](../features/playback/in-app-mini-player.md)
- [Picture-in-picture](../features/playback/picture-in-picture.md) (OS/window — different)
- [Player](../features/playback/player.md)
- [Playback settings](../features/settings/playback-settings.md)
