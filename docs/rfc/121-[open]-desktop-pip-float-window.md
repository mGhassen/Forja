# RFC-121: Desktop PiP — placeholder + separate float

**Status:** open  
**Depends on:** —  
**Area:** `PipService`, desktop players, macOS/Windows `DesktopPipChannel`  
**Issue:** [430](../issues/430-[open]-desktop-pip-placeholder-separate-float.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **0 / 4** acceptance |
| **Current slice** | Dual-window handoff — main shell + float Player — device QA open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R121-C01 | Native float window + secondary FlutterEngine (`pipFloatMain`) | ✅ |
| 2 | R121-C02 | `PipService` handoff (snapshot → dispose main → open float) | ✅ |
| 3 | R121-C03 | Main placeholder UI + `leavePlayerSurface` (mutually exclusive with mini) | ✅ |
| 4 | R121-C04 | VOD / IPTV / Live Sports + Auto PiP Space switch | ✅ |
| 5 | R121-C05 | Windows parity + feature docs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R121-A01 | Main window never shrinks for PiP | ⬜ |
| 2 | R121-A02 | Float is always-on-top; Expand / Close match prior semantics | ⬜ |
| 3 | R121-A03 | One media_kit `Player` alive across main ↔ float handoff | ⬜ |
| 4 | R121-A04 | Android system PiP unchanged | ⬜ |

---

## Summary

| Layer | Behavior |
|-------|----------|
| **Platform** | One live media_kit `Player` on macOS; Flutter can host a second engine/window |
| **Forja today** | Secondary float + main placeholder (handoff hitch on enter/leave) |
| **Plan target** | Same — device QA still open |

Handoff hitch (dispose → reopen URL+headers+seek) is required. Distinct from in-app mini.
