# 173 — Android TV update dialog: D-pad stays under the gate

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** In-app update gate · Android TV D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I173-T01 | Wrap update offer + download-complete screens in `TvOverlayScope` so D-pad stays on the gate | ✅ |
| 2 | I173-T02 | Claim Install / Continue focus with owned `FocusNode` + post-frame retries (non-opaque `showGeneralDialog` leaves shell focusable) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I173-A01 | Android TV: open update gate over IPTV (or any tab) — focus lands on **Install update**; ↑/↓ stays on the gate; OK does not activate a channel behind | ⬜ |
| 2 | I173-A02 | Android TV: during download, focus lands on **Continue in background**; shell under the gate stays inert | ⬜ |

---

## Summary

On some Android TVs the full-screen update gate painted over the shell, but D-pad / OK still drove content underneath (e.g. IPTV channels). Install had `autoFocus: true`, but `showGeneralDialog` is non-opaque so the previous route stays focusable, and nothing trapped focus like other TV overlays (`TvOverlayScope`).

**Root fix:** `TvOverlayScope` on the offer and download-complete screens, plus explicit `requestFocus` on Install / Continue with a few post-frame retries after the fade and shell reclaim.

## Related

- `apps/forja/lib/shared/widgets/update_dialog.dart`
- `apps/forja/lib/shared/tv/tv_focus_graph.dart` — `TvOverlayScope`
- [149](149-[open]-iptv-player-source-picker-dpad.md) — same class of modal focus leak
- [app-updates](../features/settings/app-updates.md)
