# 428 — Cmd+F on hub details does not open Search

**Priority:** P1  
**Severity:** Medium  
**Status:** fixed  
**Area:** shell find shortcut · hub Search · media details  
**Reported:** 2026-10-14  
**Fixed:** 2026-10-14  
**Related:** [276](276-[fixed]-host-search-engine-behind-kit.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **1 / 1** fix · **0 / 1** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I428-T01 | `_handleFindShortcut`: open hub kit Search even when a shell overlay (details) is up | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I428-A01 | Desktop: open Home/Anime/Asian Drama details → Cmd/Ctrl+F opens that hub’s Search overlay | ⬜ |

---

## Summary

On hub browse, **Cmd+F** / **Ctrl+F** opens kit Search. On hub details (shell overlay), the same shortcut did nothing.

## Root cause

`MainScreen._handleFindShortcut` returned early when `ShellBus.shellOverlayHasPage` was true — details are pushed via `pushShellRoute`, so find never reached `openKitSearch`.

## Fix approach

Drop that early return. Registered find handlers still win first (Search already open focuses the field; Live Sports schedule filter only consumes when not under an overlay). Otherwise open kit Search for the active hub tab — it stacks on details like top-bar Search would.

**Verify:** Home (or Anime / Asian Drama) → open a title → Cmd+F → hub Search opens over details; Back returns to details.
