# 518 — Phone in landscape detected as Android TV

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android · shell profile · platform detection  
**Reported:** 2026-10-28 (phones and tablets running the Android TV APK)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 4** fix (4 🔄) · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I518-T01 | Native passes the build form factor (`tv` / `mobile` flavor) to Dart at boot ([RFC-123](../rfc/123-[open]-android-mobile-flavor.md) `R123-C03`) | 🔄 |
| 2 | I518-T02 | `mobile` flavor: `PlatformChannel.detectProfile` returns phone; no physical-size TV fallback | 🔄 |
| 3 | I518-T03 | `mobile` flavor: `ShellTokens.isAndroidTvDevice` and `isTvLayout` skip the physical and logical landscape gates; touch tablets resolve to `mobile` | 🔄 |
| 4 | I518-T04 | Unit: phone 2400×1080 landscape and tablet ≥960×480 logical landscape → `mobile` under `mobile` flavor; 1920×1080 → `tv` under `tv` flavor | 🔄 |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I518-A01 | Phone, `mobile` build, cold start in landscape: `mobile` profile for the session; text fields type on focus | ⬜ |
| 2 | I518-A02 | Phone, `mobile` build: portrait → landscape → portrait stays `mobile` | ⬜ |
| 3 | I518-A03 | Tablet, `mobile` build, landscape: `mobile` profile with touch UX | ⬜ |
| 4 | I518-A04 | `forja_tv`, `tv` build: TV profile and D-pad unchanged | ⬜ |

---

## Symptom

A phone rotated to landscape switches to the TV shell. Focus becomes D-pad driven. Text fields wait for OK before typing. A cold start in landscape keeps the TV platform profile for the whole session. Tablets in landscape get the TV shell too.

## Root cause

Form factor is guessed from screen size at runtime.

- `ShellTokens.isAndroidTvDevice` (`packages/forja_foundation/lib/tokens/forja_shell_tokens.dart:1906`) treats any landscape panel with ratio ≥ 1.7 and ≥ 1280×720 physical as a TV. A phone at 2400×1080 passes.
- `ShellTokens.isTvLayout` (same file, `:1918`–`:1924`) also returns TV for any Android landscape layout ≥ 960×480 logical. Tablets pass.
- `PlatformChannel.detectProfile` (`apps/forja/lib/shared/platform/platform_channel.dart:43`, `_physicalAndroidTvPanel` at `:50`) uses the same physical heuristic when leanback does not answer `true`. It runs once at boot, so a landscape cold start pins `PlatformProfile.androidTv`.

## Fix

Root fix: the build declares the form factor ([RFC-123](../rfc/123-[open]-android-mobile-flavor.md) slice 1). The `mobile` flavor never runs the size heuristics. The `tv` flavor keeps leanback detection plus the physical fallback.

Residual until migration: a `tv` APK already on a phone still runs the heuristic. The updater moves it to `android_mobile` (`R123-C04`), which ends the symptom on that device.

## Links

- [RFC-123](../rfc/123-[open]-android-mobile-flavor.md) — Android phone app flavors (owns this fix)
- [RFC-028](../rfc/028-[draft]-adaptive-shell-profiles.md) — shell profile resolver
