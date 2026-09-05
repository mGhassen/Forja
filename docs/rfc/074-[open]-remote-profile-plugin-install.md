# RFC-074: Remote profile plugin install and uninstall

**Status:** open  
**Depends on:** [RFC-068](fixed/068-[fixed]-engine-plugin-registry.md) · [issue 213](../issues/213-[open]-engine-nuvio-plugin-disk-cache.md)  
**Area:** `apps/web/` Community Packs, `apps/forja/lib/shared/sync/`, `apps/forja/lib/shared/engine/`

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **13 / 15** acceptance |
| **Current slice** | Code shipped — phone→TV add/remove (A02 / A10) still unverified |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R74-C01 | `PackDeviceState` + deferred install store + pending purge store | ✅ |
| 2 | R74-C02 | `applyLeanManifestUrls` added/removed + `purgeRemovedImmediately` + export skip | ✅ |
| 3 | R74-C03 | Prompt FIFO install + uninstall copy | ✅ |
| 4 | R74-C04 | Web split button: add and remove from profile | ✅ |
| 5 | R74-C05 | Settings pending-install / pending-purge badges | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R74-A01 | Signed-in catalog: cloud icon → profile add without deep-link wait | ✅ |
| 2 | R74-A02 | Phone add → TV resume/tab → install dialog | ⬜ |
| 3 | R74-A03 | Install Not now → no download; Settings Install later | ✅ |
| 4 | R74-A04 | Boot splash still auto-installs without dialog | ✅ |
| 5 | R74-A05 | `forja://install` unchanged | ✅ |
| 6 | R74-A06 | Update flow unchanged (toast, never auto) | ✅ |
| 7 | R74-A07 | Multi-pack sync → FIFO (install and uninstall mixed) | ✅ |
| 8 | R74-A08 | `addedAt` on web add confirm | ✅ |
| 9 | R74-A09 | Signed-in catalog: trash → remove from profile | ✅ |
| 10 | R74-A10 | Phone remove → TV mid-session uninstall dialog; boot silent purge | ⬜ |
| 11 | R74-A11 | Uninstall Later → scripts stay; Forja export does not resurrect pack | ✅ |
| 12 | R74-A12 | Re-add to profile cancels pending purge | ✅ |
| 13 | R74-A13 | Unit tests | ✅ |
| 14 | R74-A14 | Feature docs + changelog | ✅ |
| 15 | R74-A15 | Multi-pack lean sync → one batch dialog (install + uninstall rows), not FIFO singles | ✅ |

---

## Summary

Phone (web Community Packs) adds or removes a pack on the **profile**. Signed-in devices detect the lean `packs[]` diff on cloud sync. Mid-session the app asks in **one batch dialog** before download or uninstall (all added/removed packs together — not pack-by-pack). Boot still hydrates and purges silently (issue 213). Device install state is **computed locally** — never stored in Supabase.

Cloud membership stays `{ manifestUrl, name?, version?, addedAt? }` on `profile_settings.payload.connectedServices.forja.packs`.

Do **not** offer “keep on this device forever” after profile remove — `_exportForjaCompact` would re-add the pack. Defer uninstall with a local pending-purge set excluded from export.

### Contracts

| Layer | Storage | Meaning |
|-------|---------|---------|
| Profile (cloud) | `forja.packs[]` | Membership only |
| Device | `PackDeviceState` (computed) | Lean / deferred / installed / pending purge |
| Install defer | `engine_deferred_remote_install_v1` | Not now — survives reboot; Settings Install |
| Purge defer | `engine_pending_remote_purge_v1` | After this session — excluded from Forja export |

| Entry | Prompt | Download / purge |
|-------|--------|------------------|
| Boot / splash | No | Silent hydrate + silent purge |
| Mid-session sync | Yes (one batch: install + uninstall) | After confirm or defer |
| `forja://install` | Yes | After confirm |
| Updates | Toast | Never auto |

### Related

- [RFC-068](fixed/068-[fixed]-engine-plugin-registry.md)
- [Issue 213](../issues/213-[open]-engine-nuvio-plugin-disk-cache.md)
- [cloud-sync.md](../features/settings/cloud-sync.md)
- [stream-providers.md](../features/sources/stream-providers.md)
- [forja-packs.md](../features/settings/forja-packs.md)
