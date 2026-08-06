# 110 — Android TV IPTV player top-right Player button D-pad chrome

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · IPTV player · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I110-T01 | IPTV top-bar flat actions (Player / stats / PiP) use movie-player green D-pad chrome + row edges | ✅ |
| 2 | I110-T02 | IPTV multi-source chip shows green focus when D-pad focused | ✅ |
| 3 | I110-T03 | Explicit Back ↔ source ↔ Player ↔ stats FocusNodes + ←/→ edges (focusInDirection fails across title gap) | ✅ |
| 4 | I110-T04 | ATV Exo/IPTV: top-bar Player uses `PlayerFlatIconButton(tvFocusable)` (not iptvTap); ↑ from right chrome → Player; hide deferral + 10s TV idle | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I110-A01 | Android TV IPTV player: → from Back focuses top-right **Player**; icon turns brand green with outline | ⬜ |
| 2 | I110-A02 | Select on **Player** opens the Player menu; ← returns focus to Back (or source chip when multi-source) | ⬜ |
| 3 | I110-A03 | Android TV IPTV Exo (no progress chrome): ↑ from Search / Guide / Source focuses **Player**; ↑ from Play / Replay focuses **Back** | ⬜ |

---

## Summary

On **Android TV**, IPTV player bottom transport buttons and **Back** used brand-green D-pad focus. The top-right **Player** (and stats / PiP) controls were registered in the D-pad row but rendered a static muted icon with no focus fill/outline — so moving → from Back looked like focus vanished.

**Root cause (chrome):** `_topBarFlatAction` TV path wrapped a hardcoded `Colors.white70` icon in `iptvTap` without `onFocusChange` chrome (unlike `PlayerFlatIconButton(tvFocusable: true)` on the movie/Exo player).

**Root cause (reachability):** After green chrome shipped, → from **Back** still often failed because Flutter `FocusScope.focusInDirection` cannot find **Player** across the wide title gap; the key then died with no effect (same gap after Live Matches Streamed/PPV native handoff).

**Root fix:** `_IptvPlayerTopBarIcon` reuses `playerChrome*` colors/shapes; source chip gets the same green focus treatment. **I110-T03** adds dedicated FocusNodes and explicit ←/→ edge callbacks for Back / source chip / Player / stats.

**Follow-up (I110-T04):** ATV Exo hides the bottom progress bar, so ↑ from every transport control went to **Back** and **Player** stayed hard to reach. Top-bar TV actions now use the same `PlayerFlatIconButton(tvFocusable: true)` path as the movie player; ↑ from Search / Guide / Source claims **Player**; chrome idle is 10s on TV and defers hide while a chrome control still has focus.

## Related

- [104](104-[open]-android-tv-live-matches-embed-dpad.md) — Live Matches embed D-pad
- [122](122-[open]-android-tv-iptv-player-lost-dpad.md) — IPTV player D-pad parity
- [IPTV Xtream](../features/live/iptv-xtream.md) · [Player](../features/playback/player.md)
