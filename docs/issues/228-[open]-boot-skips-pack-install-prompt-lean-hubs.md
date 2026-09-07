# 228 — Boot skips pack install prompt when hub Features on but packs lean

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** `BootNeeds` · `PluginInstallCoordinator` · splash / profile warm

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I228-T01 | `BootNeeds`: Features hub ids + pending lean disk → `needsForjaPluginWarm` (no `isContributed` filter) | ✅ |
| 2 | I228-T02 | Splash: prompt **new** lean stubs once; silent-repair packs with plugin index already on device | ✅ |
| 3 | I228-T03 | Mid-session cloud add still uses batch confirm; Install later stays deferred (no cold-boot clear) | ✅ |
| 4 | I228-T04 | Unit tests: BootNeeds; lean prompt vs silent repair | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I228-A01 | Web adds pack → app prompts once → Install → next cold start silent (no re-ask); scripts on disk | ⬜ |
| 2 | I228-A02 | Features hub ids on + lean stubs → warm runs (no `skip (no VOD/catalog tab)`); new lean prompts after splash | ⬜ |
| 3 | I228-A03 | Install later stays Install later across cold starts until user Downloads | ⬜ |

---

## Summary

**Symptom:** App opens with placeholder hub icons and pending packs; no install flow — or (wrong fix) re-prompted every boot.

**Root cause:**

1. `BootNeeds` filtered Features with `isContributed` → lean stubs → IPTV-only warm skip.
2. Lifecycle must be: **new lean** → ask once → on yes persist full pack (plugin index + scripts) → **next splash silent-repair** if scripts missing. Never re-ask for packs already installed on device. **Install later** stays deferred.

**After:** BootNeeds mirrors Features ids; splash prompts empty-plugin lean only; packs with plugins silent-hydrate; deferred untouched on cold boot.
