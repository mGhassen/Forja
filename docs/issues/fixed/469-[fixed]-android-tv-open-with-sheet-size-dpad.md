# 469 — Android TV Open with… sheet too small; D-pad ↑ stuck in results

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Lists · Open with · Android TV · D-pad  
**Reported:** 2026-10-23 (device / emulator)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

1. **Open with…** on Android TV renders as a phone-narrow confirm dialog (~360×420) instead of a readable 10ft picker.
2. In the search results list, D-pad **Down** moves between rows but **Up** does not (cannot climb the list or return to the search field).

## Root cause

1. `list_open_bind_sheet.dart` used settings-confirm clamps (`0.34` width → max **360**, height max **420**) — wrong for a hub search + results sheet.
2. Hit rows owned ↑/↓ via `onUpEdge` / `onDownEdge` `requestFocus`. That always consumed ↑ even when the previous `FocusNode` was detached after ListView recycle, so focus stayed put. Settings select dialogs use `ShellTvContainDpad` + `ShellTvLinearFocusScope` instead.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I469-T01 | `SettingsTokens.bindSheet*` — TV picker ≥480×480, up to ~48%/78% of screen | ✅ |
| 2 | I469-T02 | Wrap sheet in contain + linear; hit rows use item ensure-visible; ↑ between hits via linear | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I469-A01 | ATV Open with… sheet reads as a landscape picker (not a phone card) | ⬜ |
| 2 | I469-A02 | ATV: results list ↑/↓ walks rows; ↑ from first row lands on search | ⬜ |

## Links

- [RFC-108](../../rfc/fixed/108-[fixed]-my-list-open-hub-binding.md) · [400](../400-[open]-my-list-open-with-hub-checkbox.md) · [371](371-[fixed]-my-list-open-with-regression.md)
