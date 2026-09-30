# 382 — Downloads hub

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**RFC:** [RFC-117](../rfc/117-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **12 / 12** tasks · **8 / 10** acceptance |
| **Current slice** | In-progress titles are in the hub list — not checked on a device |

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
| 9 | I382-T09 | Panel is the open film: marked poster, Play on the art, saved rows name the provider and stream. Player source button and list keep that identity with the offline icon | ✅ |
| 10 | I382-T10 | A title that is still saving is a hub card, with a live bar, and each file’s progress in the panel | ✅ |
| 11 | I382-T11 | Snapshot keeps each saved episode’s still and synopsis | ✅ |
| 12 | I382-T12 | Panel lists each saved episode with its still and synopsis, and that episode’s files underneath | ✅ |

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
| 8 | I382-A08 | The open poster stays marked. The panel shows the film, Play on the poster, and each saved file’s provider and stream. Playing that file keeps the same source on the player button and in the source list, with the offline icon | ✅ |
| 9 | I382-A09 | Starting a save shows that title on Downloads without waiting for it to finish, with progress on the poster and on each file | ⬜ |
| 10 | I382-A10 | A series panel shows each saved episode with its image and synopsis, and the files for that episode under it | ⬜ |

---

## Problem

Finished downloads live as a file queue under Settings. There is no catalog of the titles, and opening details still needs the network.

## Goal

A Downloads hub of saved films, series, anime, and dramas. The details page, backdrop, and file list work from what was saved with the download.
