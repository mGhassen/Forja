# 225 — Official pack install aborts batch / skips hub nav refresh

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** Settings → Forja Packs · Official packs picker · guest onboarding · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I225-T01 | Official picker `_applySelected`: per-pack try/catch so one failure does not abort the rest | ✅ |
| 2 | I225-T02 | After batch install always `PluginNavRegistry.refresh` (even if pane unmounted) | ✅ |
| 3 | I225-T03 | Block Back / category leave / Not now while install applying | ✅ |
| 4 | I225-T04 | `installManifest` per-URL in-flight + `[PluginInstall]` / `[PackPrompt]` debug logs | ✅ |
| 5 | I225-T05 | Shared `PackHubFeatures` — install / guest onboard / cloud add call refresh then default-on hub Features (same as pack toggle ON) | ✅ |
| 6 | I225-T06 | URL install + pending download paths activate hub Features; providers-only packs correctly leave rail unchanged | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I225-A01 | ATV: Official packs → select Anime (+ others) → Install → logs show `[PackPrompt] install` / `[PluginInstall] ready`; Features lists hub tabs | ⬜ |
| 2 | I225-A02 | Mid-download Back does not dismiss the picker; install finishes and nav refreshes | ⬜ |
| 3 | I225-A03 | Guest: install official hub packs (onboarding or Settings) → rail shows those tabs without needing pack OFF/ON | ⬜ |

---

## Summary

**Symptom:** Selecting official packs and Install on Android TV looked dead or left Features empty / Anime still pending. Guest install required deactivate + reactivate the pack to see hub tabs on the navbar.

**Root cause:**

1. `_applySelected` wrapped the whole loop in one try/catch — first pack failure stopped the rest with a single toast.
2. Success path did `if (!mounted) return` **before** any hub nav refresh. Back (or remount) during download closed the pane and skipped `PluginNavRegistry.refresh`.
3. Settings Back always called `dismissWithoutApply` while the picker was open — including mid-download.
4. Manual install logged almost nothing, so ATV logs looked like “nothing ran” even when fetch/commit happened.
5. RFC-086: `PluginNavRegistry.refresh` / `ensureNavIdsKnown` only mark hubs **known** — they do **not** write `visibleIds`. Pack toggle ON called `_activatePackHubFeatures`; guest onboarding + `installSelectedOfficialPacks` + URL install did not, so Features/rail stayed empty until the user flipped the pack switch.

**After:** `PackHubFeatures.refreshAndActivateInstalled` runs after official batch / Settings prompt / guest onboard / cloud add / URL install — same default-on as pack enable.

**Related:** [222](222-[open]-android-tv-features-empty-after-pack-install.md) · [224](224-[open]-android-tv-addons-iptv-live-toggle-dead.md) · [RFC-086](../rfc/fixed/086-[fixed]-addons-packs-feature-vs-navbar.md)

## Verify

1. Hot restart ATV / guest desktop.
2. Settings → Forja Packs → Official packs → select Anime (and optional hubs) → Install N packs.
3. Log: `[PackPrompt] install …` then `[PluginInstall] ready …`.
4. Left navbar shows hub tabs immediately (no pack OFF/ON).
5. Settings → Features lists those hub rows on.
