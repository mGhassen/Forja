# 366 — Pack-owned green Play (multi-tech race)

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** pack settings · green Play  
**RFC:** [RFC-118](../rfc/118-[open]-pack-green-play.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** tasks · **6 / 6** acceptance |
| **Current slice** | Host + packs shipped — manual QA remaining |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I366-T01 | RFC-118 + this issue + index rows | ✅ |
| 2 | I366-T02 | `PackGreenPlayConfig` parse / store / fallback | ✅ |
| 3 | I366-T03 | Addon Settings Green Play UI | ✅ |
| 4 | I366-T04 | Engine race respects allowlist / preferred / order | ✅ |
| 5 | I366-T05 | Multi-tech adapters (stremio / nuvio / torrent) | ✅ |
| 6 | I366-T06 | Hub packs declare `greenPlay` defaults (home / anime / asian_drama) | ✅ |
| 7 | I366-T07 | Feature docs + changelog | ✅ |
| 8 | I366-T08 | Host tests (synthetic fixtures only) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I366-A01 | Undeclared hub green Play unchanged (all enabled Forja) | ✅ |
| 2 | I366-A02 | Declared hub Settings shows Green Play; edits persist | ✅ |
| 3 | I366-A03 | Engine allowlist / preferred / order change race pool | ✅ |
| 4 | I366-A04 | Multi-tech race opens first playable across allowlisted techs | ✅ |
| 5 | I366-A05 | Play-source off excludes that tech from race | ✅ |
| 6 | I366-A06 | Sources chips do not narrow green Play | ✅ |

---

## Problem

Green Play always races every enabled Forja plugin. Users cannot choose technology (Stremio / Nuvio / torrent), provider allowlist, preferred providers, or start order per hub.

## Goal

Pack-declared `settings.greenPlay` with user overlay; parallel multi-tech race; host fallback when undeclared.
