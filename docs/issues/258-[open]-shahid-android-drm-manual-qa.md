# 258 — Shahid Android DRM manual QA

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Shahid hub / Exo Widevine / Android  
**Depends on:** [RFC-101](../rfc/101-[open]-shahid-hub-provider-exo-widevine.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I258-A01 | Clear / free clip HLS plays on Android Exo | ⬜ |
| 2 | I258-A02 | Clear clip plays on MediaKit when selected | ⬜ |
| 3 | I258-A03 | Premium episode with Shahid login plays on Android Exo (Widevine) | ⬜ |
| 4 | I258-A04 | No credentials → premium resolve empty / toast; no crash | ⬜ |
| 5 | I258-A05 | MediaKit preferred + DRM title → Exo forced or clear toast; MediaKit still works for clear VOD | ⬜ |

---

## Summary

Manual verification for RFC-101 slice A/C on a physical Android (phone or TV) with a real Shahid account. Host unit tests cover synthetic DRM mapping only.

## Related

- [RFC-101](../rfc/101-[open]-shahid-hub-provider-exo-widevine.md)
