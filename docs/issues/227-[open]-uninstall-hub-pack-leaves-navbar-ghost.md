# 227 — Uninstall hub pack leaves navbar ghost tab

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Settings → Forja Packs · Features · shell navbar · `PluginNavRegistry`

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I227-T01 | `PluginNavRegistry.refresh` prunes hub tabs gone from the pack index (and orphan visible KV) when not hydrating | ✅ |
| 2 | I227-T02 | Pack remove / purge deactivates hub Features then `refresh` (same as pack OFF) | ✅ |
| 3 | I227-T03 | Pack prompt uninstall deactivates hub Features before `removePack` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I227-A01 | Uninstall a hub pack (e.g. Kids / Aflem) → tab gone from Features **and** left navbar | ⬜ |
| 2 | I227-A02 | Cold start with a leftover visible hub id and no pack → rail drops the ghost after hub refresh | ⬜ |

---

## Summary

**Symptom:** After deleting a hub pack under **Forja Packs**, **Settings → Features** no longer listed the tab, but the left navbar still showed its icon (ghost between other hubs).

**Root cause:**

1. Features inventory comes from `PluginNavRegistry.destinations` (enabled pack `nav`) — uninstall correctly dropped the hub from that map on refresh.
2. The shell rail paints from Features `visibleIds` and intentionally does **not** filter with `isContributed` (224 ATV race).
3. Pack **disable** called `_deactivatePackHubFeatures` (hide tab in KV). Pack **uninstall / purge** only called `removePack` — no deactivate, and refresh skipped `syncActiveHubNavIds` for non-empty remaining installs (comment assumed uninstall pruned explicitly).

**After:** Refresh strips hub ids that are no longer in the pack index (and orphans still in visible KV) when packs are not hydrating. Uninstall / purge / prompt uninstall deactivate hub Features then refresh.

**Related:** [222](222-[open]-android-tv-features-empty-after-pack-install.md) · [224](224-[open]-android-tv-addons-iptv-live-toggle-dead.md) · [RFC-081](../rfc/fixed/081-[fixed]-host-only-platform-nav-defaults.md)

## Verify

1. Install a hub pack (Kids / Aflem / Arabic / …) so its tab is on the rail.
2. Uninstall that pack under **Forja Packs**.
3. Confirm Features has no row for it and the left navbar icon is gone.
4. Optional: leave a stale visible id in KV with pack already gone → restart → rail heals after refresh.
