# Soft-pull keeps stale pack manifest URLs after catalog move

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/engine/packs/`, `apps/forja/lib/shared/sync/`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** tasks · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I267-T01 | `applyLeanManifestUrls`: same-slot remote URL wins (keep readable local checkout) | ✅ |
| 2 | I267-T02 | `importForja`: remap lean URLs through published `plugin_packs` by opaque slot | ✅ |
| 3 | I267-T03 | Unit tests + feature/changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I267-A01 | Device with old GitHub pack URLs soft-pulls → Settings shows catalog `manifest_url` and re-downloads | ✅ |
| 2 | I267-A02 | Local forja-packs / plugins checkout still satisfies same-slot cloud URL (no purge) | ✅ |

---

## Summary

After packs moved to `forja-packs` (admin `plugin_packs.manifest_url` updated), signed-in Android TV still showed `…/Forja/main/plugins/…` URLs. Soft-pull treated same-slot old remote installs as already satisfying the new URL, so the device never swapped or reinstalled. Profile `packs[]` could also still hold retired hosts even when the catalog row had moved.

**Fix:** remap lean rows through published catalog by opaque slot, then migrate remote→remote same-slot URL changes (cloud URL wins). Readable local checkouts still win. After migrate adds, push Forja so profile membership stores the new URLs.

### Related

- [RFC-074](../../rfc/074-[open]-remote-profile-plugin-install.md)
- [Forja Packs](../../features/settings/forja-packs.md)
