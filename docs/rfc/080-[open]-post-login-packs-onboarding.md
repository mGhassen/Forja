# RFC-080: Post-login packs onboarding

**Status:** open  
**Depends on:** [RFC-074](074-[open]-remote-profile-plugin-install.md) · [RFC-068](fixed/068-[fixed]-engine-plugin-registry.md)  
**Area:** `apps/forja/lib/app/`, `apps/forja/lib/features/account/`, `apps/forja/lib/shared/sync/`, `apps/web/src/lib/sync-domains.ts`

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **11 / 11** acceptance |
| **Current slice** | Desktop + Android TV — synced `onboarded` + packs wizard; Settings Official uses picker |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R80-C01 | `connectedServices.forja.onboarded` sync (Flutter + web compact) | ✅ |
| 2 | R80-C02 | `DesktopStartupGate` packs stage + restored-session path | ✅ |
| 3 | R80-C03 | Cold-start defer `ProfileSwitchSplash` until after packs | ✅ |
| 4 | R80-C04 | `PacksOnboardingScreen` (Community Packs link, Install official, Skip) | ✅ |
| 5 | R80-C05 | Official pack URL catalog + sequential `installManifest` | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R80-A01 | Fresh sign-in → create/pick profile → packs screen when `!onboarded` | ✅ |
| 2 | R80-A02 | Install official ForjaHQ packs → device packs + `onboarded: true` → splash → shell | ✅ |
| 3 | R80-A03 | Skip → `onboarded: true`, empty packs OK; second launch no wizard | ✅ |
| 4 | R80-A04 | Upgrade / restored session with missing `onboarded` → packs wizard once | ✅ |
| 5 | R80-A05 | Device already has packs + `!onboarded` → auto-mark onboarded, no flash | ✅ |
| 6 | R80-A06 | Guest → packs wizard when device-local guest onboarded is false; Skip/Install sets local flag only | ✅ |
| 7 | R80-A07 | Empty packs after Skip still exports `{ onboarded: true }` (flag not dropped) | ✅ |
| 8 | R80-A08 | Mid-session Who's watching unchanged (no packs step) | ✅ |
| 9 | R80-A09 | ATV: D-pad focus on Install / Skip / browse; focus ≠ activate | ✅ |
| 10 | R80-A10 | Feature docs + changelog | ✅ |
| 11 | R80-A11 | Settings → Forja Packs **Official packs** opens checkbox picker (no silent install-all) | ✅ |

---

## Summary

After sign-in on desktop / Android TV, once a profile is active, show a packs onboarding step when the profile is **not onboarded**. Primary CTA installs all official ForjaHQ packs; users can browse Community Packs or Skip. Synced `onboarded` covers **new users** and **upgrades** that would otherwise land in an empty shell (no default pack auto-install).

**Settings → Official packs** uses the same batch checkbox picker as profile/Community installs — it does not silently download the full bundle. Onboarding’s Install CTA still installs the full official set in one go.

### Trigger

```
signed in + active profile AND NOT onboarded
```

Field missing ⇒ `false`. Guest uses a **device-local** onboarded flag (no cloud). Mobile gate out of scope.

### Payload

```json
"connectedServices": {
  "forja": {
    "packs": [ ... ],
    "onboarded": true
  }
}
```

### Related

- [tv-connect.md](../features/accounts/tv-connect.md)
- [forja-packs.md](../features/settings/forja-packs.md)
- [cloud-sync.md](../features/settings/cloud-sync.md)
- [RFC-074](074-[open]-remote-profile-plugin-install.md)
