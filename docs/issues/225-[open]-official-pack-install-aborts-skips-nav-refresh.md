# 225 — Official pack install aborts batch / skips hub nav refresh

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** Settings → Forja Packs · Official packs picker · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I225-T01 | Official picker `_applySelected`: per-pack try/catch so one failure does not abort the rest | ✅ |
| 2 | I225-T02 | After batch install always `PluginNavRegistry.refresh` (even if pane unmounted) | ✅ |
| 3 | I225-T03 | Block Back / category leave / Not now while install applying | ✅ |
| 4 | I225-T04 | `installManifest` per-URL in-flight + `[PluginInstall]` / `[PackPrompt]` debug logs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I225-A01 | ATV: Official packs → select Anime (+ others) → Install → logs show `[PackPrompt] install` / `[PluginInstall] ready`; Features lists hub tabs | ⬜ |
| 2 | I225-A02 | Mid-download Back does not dismiss the picker; install finishes and nav refreshes | ⬜ |

---

## Summary

**Symptom:** Selecting official packs and Install on Android TV looked dead or left Features empty / Anime still pending.

**Root cause:**

1. `_applySelected` wrapped the whole loop in one try/catch — first pack failure stopped the rest with a single toast.
2. Success path did `if (!mounted) return` **before** any hub nav refresh. Back (or remount) during download closed the pane and skipped `PluginNavRegistry.refresh`.
3. Settings Back always called `dismissWithoutApply` while the picker was open — including mid-download.
4. Manual install logged almost nothing, so ATV logs looked like “nothing ran” even when fetch/commit happened.

**Related:** [222](222-[open]-android-tv-features-empty-after-pack-install.md) · [224](224-[open]-android-tv-addons-iptv-live-toggle-dead.md)

## Verify

1. Hot restart ATV.
2. Settings → Forja Packs → Official packs → select Anime (and optional hubs) → Install N packs.
3. Log: `[PackPrompt] install …` then `[PluginInstall] ready …`.
4. Settings → Features shows hub rows; rail shows Anime after enable/first-seen.
