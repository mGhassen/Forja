# 427 — Green Play cancels sibling providers before probe

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** green Play · engine auto-play  
**Reported:** 2026-10-14  
**Fixed:** 2026-10-14

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **1 / 1** fix · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I427-T01 | Stop `cancelEngineJsExtracts` on first plugin rows — only `abortPool` after probe win | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I427-A01 | Green Play: first provider returns a dead URL → other providers keep racing (no mass `cancelled`) | ⬜ |
| 2 | I427-A02 | Green Play: first provider returns a live URL → siblings cancel only after probe win / player open | ⬜ |

---

## Summary

Green Play raced every enabled Forja provider, but when the **first** plugin returned any playable rows it called `Engine.cancelEngineJsExtracts()` before probing those URLs. Sibling jobs died with `enginejs job error: cancelled`. If that first URL failed probe, the race was empty → “no stream” even though slower providers would have worked.

**Root fix:** remove that early cancel. `abortPool()` already kills siblings after a successful probe.

**Verify:** green Play a title where a fast provider returns a bad link — logs should show other providers completing (or cancel only after a working stream opens), not a wall of `cancelled` right after the first `streams=N`.
