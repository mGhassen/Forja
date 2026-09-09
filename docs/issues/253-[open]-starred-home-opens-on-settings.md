# 253 — Starred Home opens on Settings

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** shell / navigation / cold start

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **1 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I253-T01 | `resolveBuildableShellTabIndex` — never fall through to Settings when preferred hub has no builder yet | ✅ |
| 2 | I253-T02 | MainScreen: promote Settings-only cold paint → starred default when feature tabs appear | ✅ |
| 3 | I253-T03 | Restored-session cold start sets `selectDefaultTabOnNextNavLoad` after profile scope / cloud pull | ✅ |
| 4 | I253-T04 | Cold auth / packs gate: always arm default tab (`prepareCurrent: false` + enter-shell); keep arm until starred tab lands | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I253-A01 | Star Home in Features, kill app, reopen (restored session): lands on Home, not Settings | ⬜ |
| 2 | I253-A02 | Unit: ghost hub builders keep preferred Home index instead of Settings | ✅ |
| 3 | I253-A03 | Sign in → pick profile → packs auto-install → shell opens on starred tab (not Settings rail) | ⬜ |

---

## Summary

**Star Home** in Settings → Features, but cold open (especially restored signed-in session) lands on **Settings**. The star still shows Home.

### Root cause

1. **Ghost builder fallback** — first navbar resolve can prefer `home` while hub packs are mid-refresh (`navTabBuilders` only has `iptv` / `settings`). Old code did `indexWhere(navTabBuilders.containsKey)` and picked **Settings** when IPTV was filtered out or not visible yet. `_initialNavResolved` then stayed true, so later hub registration kept Settings selected.
2. **Restored session** — skips `ProfileSwitchSplash` (the only place that set `selectDefaultTabOnNextNavLoad`). MainScreen can lock onto Settings-only before profile nav is rich, then preserve Settings when tabs appear.
3. **Cold auth / packs gate** — `ProfileSwitchSplash(prepareCurrent: false)` never armed the default-tab flag. MainScreen could paint Settings (empty rail / late default) and clear any arm too early, then keep Settings after hubs + star landed.

### Fix

- Prefer another **feature** builder, or keep the preferred ghost index — never Settings — via `SettingsService.resolveBuildableShellTabIndex`.
- When the rail goes from Settings-only → features while still on Settings, apply the starred default once.
- Restored-session background sync sets `selectDefaultTabOnNextNavLoad` like a profile switch.
- Gate profile splash always arms the flag; MainScreen keeps the arm until the selected tab matches the starred default.

### Related

- [navigation](../features/getting-started/navigation.md) · [Features settings](../features/settings/navigation-bar.md) · RFC-006 R06-A33 (profile-switch default tab)
