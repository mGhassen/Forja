# 262 — Android TV Forja Packs: last pack unreachable / clipped

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings → Forja Packs · D-pad scroll

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** · A **0/1** |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I262-T01 | `shellTvEnsureVisibleItem` leaves bottom inset (no flush keepVisibleAtEnd) so next/last pack stays on-screen | ✅ |
| 2 | I262-T02 | Settings page TV bottom scroll slack matches the inset token | ✅ |
| 3 | I262-T03 | Pending pack rows get a full-width leanback focus target (↓ reaches last pending pack) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I262-A01 | Android TV Settings → Forja Packs: ↓ from second-to-last pack focuses and reveals the last pack (installed or pending) | ⬜ |

---

## Summary

On **Android TV**, **Settings → Forja Packs** stopped one pack short: the last pack stayed below the fold and D-pad ↓ could not usefully land on it.

**Root cause:** `shellTvEnsureVisibleItem` used flush `keepVisibleAtEnd`, pinning the focused row to the bottom of the viewport. The next pack never peeked, and the last pack sat under overscan. Pending rows only had small right-side icons (outside the header focus band), so spatial ↓ often skipped them.

**Root fix:** Bottom inset in ensureVisible (token-aligned scroll slack) + focusable pending pack headers.

**Related:** [forja-packs](../features/settings/forja-packs.md) · [127](127-[open]-android-tv-settings-detail-dpad.md)
