# 382 — Downloads hub

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**RFC:** [RFC-117](../rfc/117-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** tasks · **7 / 7** acceptance |
| **Current slice** | Hub, snapshot, offline details, Downloaded tab, green Play |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I382-T01 | Snapshot details page, poster, and backdrop on enqueue; keep drama as its own type | ✅ |
| 2 | I382-T02 | `ctx.host.downloads.titles()` and `open.surface: offline` | ✅ |
| 3 | I382-T03 | Downloads hub pack (Film / Series / Anime / Asian Drama) | ✅ |
| 4 | I382-T04 | Sources Downloaded tab and green Play of the first finished file | ✅ |
| 5 | I382-T05 | Feature guide, changelog, RFC-117 rows | ✅ |
| 6 | I382-T06 | Card tap opens the saved page; the file button lists saved files only | ✅ |
| 7 | I382-T07 | Card docks a side panel: saved info, finished episodes, Play, file cards only | ✅ |
| 8 | I382-T08 | Kind menu and posters sit below the window bar and share the same left edge | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I382-A01 | Saving a film or episode also stores the page, poster, and backdrop | ✅ |
| 2 | I382-A02 | Downloads hub shows one card per finished title, grouped by kind | ✅ |
| 3 | I382-A03 | That details page works from the snapshot and lists only finished episodes | ✅ |
| 4 | I382-A04 | Sources opens on a Downloaded tab that lists the saved files | ✅ |
| 5 | I382-A05 | Green Play on that page starts the first finished file | ✅ |
| 6 | I382-A06 | Tapping a card opens that saved page. The file button lists only the saved file cards | ✅ |
| 7 | I382-A07 | The card docks a side panel with saved info and finished episodes. Play starts the first file. The white button lists file cards only | ✅ |

---

## Problem

Finished downloads live as a file queue under Settings. There is no catalog of the titles, and opening details still needs the network.

## Goal

A Downloads hub of saved films, series, anime, and dramas. The details page, backdrop, and file list work from what was saved with the download.
