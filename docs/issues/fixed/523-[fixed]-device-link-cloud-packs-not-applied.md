# 523 — Device-link: cloud packs full, app Forja Packs empty

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** host · sync · packs · device link / profile splash  
**Reported:** 2026-11-02 (QR link → Live signed in; portal packs full; app empty)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance (manual device-link QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

After QR / device-link into an account whose cloud profile (e.g. Live) already has Forja Packs + addons on the portal, the app shows signed in + “N setting sections synced” but Settings → Forja Packs / Addons look empty or unhydrated.

## Root cause

Profile splash could finish the **UI** wait (timeout / Continue) while `pullAndMergeForProfileSwitch` was still running. `BootNeeds` then resolved against an empty lean pack index → skipped `ensureAllInstalled(awaitCloudLean)`. Soft-pull `importForja` that landed later deferred downloads (`!splashDismissed`), and nothing re-hydrated after dismiss.

“N setting sections synced” only counts top-level `profile_settings` keys — not proof packs applied.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I523-T01 | Profile splash awaits lean sync future before BootNeeds / warm | ✅ |
| 2 | I523-T02 | Signed-in + `awaitCloudLean` always runs pack warm even if BootNeeds empty | ✅ |
| 3 | I523-T03 | Settings → Forja Packs open forces cloud soft-pull then reload | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I523-A01 | Device-link → pick Live (cloud packs already set) → Forja Packs lists those packs after splash | ⬜ |
| 2 | I523-A02 | Open Settings → Forja Packs while signed in recovers membership if index was empty | ⬜ |

## Links

- [259](../259-[open]-cloud-pack-auto-install-before-profile-splash.md) — splash owns hydrate
- [522](522-[fixed]-connect-code-stolen-as-pkce.md) — QR `?code=` PKCE collision (separate)
- [RFC-046](../../rfc/046-[open]-android-tv-device-link.md)
