# 430 — Desktop PiP shrinks the whole app instead of placeholder + float

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Player · Desktop PiP · macOS · Windows  
**RFC:** [121](../rfc/121-[open]-desktop-pip-float-window.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 5** acceptance |
| **Current slice** | Dual-window PiP — main stays full-size + placeholder; float hosts video |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I430-T01 | Stop shrinking the main window on desktop PiP enter | ✅ |
| 2 | I430-T02 | Native secondary always-on-top float + FlutterEngine (macOS) | ✅ |
| 3 | I430-T03 | `PipService` Player handoff + main placeholder / shell unlock | ✅ |
| 4 | I430-T04 | Wire VOD + IPTV + Live Sports enter / expand / close + Auto PiP | ✅ |
| 5 | I430-T05 | Windows float host parity | ✅ |
| 6 | I430-T06 | Feature doc + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I430-A01 | macOS: PiP leaves main window full-size; shell usable; placeholder visible | ⬜ |
| 2 | I430-A02 | macOS: video plays in separate always-on-top float; Expand restores | ⬜ |
| 3 | I430-A03 | In-app mini and OS PiP refuse to overlap | ⬜ |
| 4 | I430-A04 | Auto PiP / Space switch creates the float (not main shrink) | ⬜ |
| 5 | I430-A05 | Windows: same placeholder + float behavior | ⬜ |

---

## Summary

Desktop PiP no longer shrinks the single Forja window. A secondary float host plays video via exclusive media_kit Player handoff. Main shows a corner notice and unlocks the shell.

## Related

- [RFC-121](../rfc/121-[open]-desktop-pip-float-window.md)
- [Picture-in-picture](../features/playback/picture-in-picture.md)
- [In-app mini](../features/playback/in-app-mini-player.md) (distinct)
