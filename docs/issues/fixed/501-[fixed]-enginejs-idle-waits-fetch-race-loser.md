# 501 — EngineJS idle waits on fetch race loser (~25s)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** engine · EngineJsExtract · Anime / AniList  
**Reported:** 2026-10-26 (released Anime hub rails `ok … 12–25030ms` while curl AniList ~300ms)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **1 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Opening Anime on a released build, parallel `anilist` `action=rail` jobs log `ok` at ~2s…**25s**. Raw GraphQL to `graphql.anilist.co` is ~300ms. Hub feels stuck after AniList already had a valid payload.

## Root cause

Pack `anilistQuery` races primary + mirror; first win resolves the extract Promise. `extract_inner` then awaited `rt.idle()`, which drains **all** leftover QuickJS promises — including the race loser `ctx.fetch` — up to `FETCH_TIMEOUT` (25s) before returning to Dart.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I501-T01 | Stop awaiting `rt.idle()` after extract resolves; drop runtime so race losers do not stall the job | ✅ |
| 2 | I501-T02 | Regression test: fast+hanging localhost race returns on winner in &lt;3s | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I501-A01 | `cargo test -p engine extract_returns_on_fetch_race_winner_without_waiting_loser` passes | ✅ |

---

## Summary

**Root fix:** engine returns as soon as `extract(ctx)` resolves. Orphan race fetches are abandoned with the runtime instead of holding the job open. Anime pack comment updated (version 1.0.61). Related stampede/cooldown: [380](380-[fixed]-pack-reload-anilist-stampede.md).
