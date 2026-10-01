# 352 — Source provider unavailable message

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** player Source · providers  
**Reported:** 2026-09-24  
**Fixed:** 2026-09-24

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** fix · **0 / 3** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I352-T01 | Failed Source server row subtitle **Unavailable** | ✅ |
| 2 | I352-T02 | Toast `{Provider} is unavailable` when user checks / picks a dead server (MediaKit panel) | ✅ |
| 3 | I352-T03 | Same toast on Exo Source panel / dialog user check + manual switch fail | ✅ |
| 4 | I352-T04 | Unit tests for subtitle + toast copy helpers | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I352-A01 | Auto race marks a server red → row shows **Unavailable**; no toast spam | ⬜ |
| 2 | I352-A02 | Tap empty / red server that returns nothing → toast `{Name} is unavailable` | ⬜ |
| 3 | I352-A03 | Manual switch to a dead provider → toast; playback Auto failover stays silent | ⬜ |

---

## Summary

Failed Source servers only showed a red status dot. Empty extract and open miss looked the same as “not checked yet” for copy.

**Symptom fix:** subtitle **Unavailable** on failed rows; toast when the user explicitly checks or switches to a server that returns nothing / fails to open. Auto race still uses status glyphs only (no toast).

**Root note:** packs that swallow fetch errors still surface as empty extract → **Unavailable**, not a distinct “unreachable” network reason.

**Verify:** open Source → failed server shows **Unavailable** under the name → tap it → toast with provider name.
