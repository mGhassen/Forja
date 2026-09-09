# 259 — Cloud pack auto-install before profile splash

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** Sync · packs · profile splash · Who's watching

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I259-T01 | Soft-pull `applyCloudLeanDiff` must not download/activate while `!splashDismissed` (Who's watching / profile splash owns hydrate via `ensureAllInstalled`) | ✅ |
| 2 | I259-T02 | Batch hub Features activate: one navbar write + one sync push after multi-pack install (no N cloud upserts freezing the shell) | ✅ |
| 3 | I259-T03 | Sign-out / profile reset keep disk scripts; lean soft-pull rehydrates from per-profile `pack.json` instead of re-downloading | ✅ |
| 4 | I259-T04 | Features push exports raw `visibleIds` (no lean-stub strip); hub filter skips while hydration pending so cloud Features stop reverting on logout | ✅ |
| 5 | I259-T05 | Bind plugin disk scope before BootNeeds / `repairMissingScripts`; never wipe local checkout packs on sign-out reset; soft-pull keeps readable local manifests | ✅ |
| 6 | I259-T06 | Packs fire only after profile launched; pack prefs scoped per profile (`LocalDataScope`); no reset wipe of pack index; rehydrate before BootNeeds | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I259-A01 | Sign in → Who's watching: no `[PluginInstall] cloud auto-install` until after profile splash / shell open; profile splash still hydrates packs | ⬜ |
| 2 | I259-A02 | After profile lands, rail/Settings taps work; no navbar write/sync storm (`[]→[home]→…` with per-tab upsert) from pack activate | ⬜ |
| 3 | I259-A03 | Logout → login → same profile: splash shows `0 silent install job(s)` (or rehydrate log) when scripts already on disk; no full pack re-download | ⬜ |
| 4 | I259-A04 | Features: toggle tabs / reorder / star → logout → login → same Features state (not an older cloud set) | ⬜ |
| 5 | I259-A05 | Local checkout pack (e.g. Shahid path) survives logout/login — not replaced by GitHub Pending download; no false `scripts missing` before profile disk scope binds | ⬜ |

---

## Summary

**Symptom:** Right after login / profile pick, logs showed `cloud auto-install` for hub packs, then a cascade of `navbar write` + `pushProfileSettings` / `navigation upsert` per tab. Shell froze (`Lost connection to device`); profile / Settings tap did nothing.

**Root cause:**

1. Soft-pull `importForja` → `applyCloudLeanDiff` downloaded and `PackHubFeatures.activate`d packs whenever `!bootWarm`, including **before** profile splash set `bootWarm` and before the shell was open (`splashDismissed == false`). Pack hydrate belongs to profile splash / logo intro `ensureAllInstalled(awaitCloudLean: true)`.
2. `refreshAndActivateInstalled` called `activate` per pack; each `activate` awaited an immediate navigation cloud upsert → N sequential network round-trips + navbar notify storm.
3. Sign-out / profile reset wipe the **prefs pack index** with `purgeDisk: false` (disk kept), then soft-pull re-adds lean stubs (`plugins: []`). `packNeedsDiskInstall` treated empty plugins as always-install → profile splash re-downloaded every pack even when JS was already under `accounts/{user}/profiles/{id}/`.
4. First `pack.json` meta never landed (splash timed out mid-CDN install) so disk-rehydrate had nothing to restore — `scripts missing` + `11 silent install job(s)` kept firing despite 100+ `.js` files on disk.

**After:** Soft-pull only updates lean membership until splash dismissed. Profile splash still downloads under `bootWarm`. Mid-session soft pull (shell open) still auto-installs. Hub activate batches tabs into one write + one push. Installs write `pack.json` next to scripts; lean apply / `ensureAllInstalled` rehydrate from disk when scripts are complete. **Install prefers existing per-profile disk JS** (manifest-only when scripts already present) so the first post-fix splash finishes fast and writes `pack.json`.

**Related:** [225](225-[open]-official-pack-install-aborts-skips-nav-refresh.md) · [224](224-[open]-android-tv-addons-iptv-live-toggle-dead.md)

## Verify

1. Sign out → sign in → stay on Who's watching: no `cloud auto-install` lines.
2. Pick a profile → profile splash shows plugin progress; shell opens; rail profile/Settings responds.
3. Mid-session: add a pack on web → app soft pull still auto-installs after shell is up.
