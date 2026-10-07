# 418 — Torrent downloads list painted by the torrent pack, not host Dart

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Torrent pack · Settings → Addons → Direct torrent · Settings → Downloads · pack settings fields  
**Reported:** 2026-10-07

**Related:** [RFC-089](../../rfc/fixed/089-[fixed]-pack-addon-settings.md) · [RFC-109](../../rfc/109-[open]-forja-pack-product-host.md) · [RFC-110](../../rfc/110-[draft]-pack-surface-contributions.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5/5** tasks · **0 / 3** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

A torrent list with Stop / Delete rows was added as host Dart under `features/settings` and wired into the Direct torrent page and a hard-coded Torrents tab on Settings → Downloads. Torrent is pack product; the host may only paint what a pack declares.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I418-T01 | Remove host torrent list section and the host Torrents tab | ✅ |
| 2 | I418-T02 | Pack settings field type `action_list`: pack action returns rows + footer; taps run the pack item action; host paints generic rows | ✅ |
| 3 | I418-T03 | `settings.addons` list lets one plugin contribute to several buckets; Settings → Downloads paints one tab per plugin contributing to `downloads` | ✅ |
| 4 | I418-T04 | `ctx.host.engine.request('torrent', …)`: list / stop / remove / remove_all on the local engine session | ✅ |
| 5 | I418-T05 | Torrent pack `torrent-downloads` plugin (`downloads.js`) declares the Torrents list for `torrent` and `downloads` | ✅ |

## Acceptance (manual)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I418-A01 | Direct torrent page shows the Torrents group from the pack; uninstalling the torrent pack removes it | ⬜ |
| 2 | I418-A02 | Settings → Downloads shows a Torrents tab only while the torrent pack is active | ⬜ |
| 3 | I418-A03 | Stop keeps the file and the next play resumes; Delete removes it; rows refresh every 2 s | ⬜ |

## Notes

Host still owns the Direct torrent engine sliders, sort order, FlareSolverr field and the admin-only Jackett / Prowlarr groups (pre-existing, not part of this issue).
