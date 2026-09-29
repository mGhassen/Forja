# 392 — Saved episode won’t play (PNG-wrapped HLS)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**RFC:** [RFC-117](../rfc/117-[open]-vod-offline-downloads.md)  
**Related:** [377](377-[open]-vod-offline-play-corrupt-file-stream-hop.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** tasks · **0 / 1** acceptance |
| **Current slice** | Strip is in the downloader and on Play — not checked on the saved episode |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I392-T01 | HLS save strips a PNG shell per segment before concat | ✅ |
| 2 | I392-T02 | Play rewrites an already saved PNG-wrapped file, then opens it | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I392-A01 | Play on the saved Liar Game episode starts the file | ⬜ |

---

## Problem

Play on a finished Megaplay episode toasts that the file can’t be played.

## Root cause

Those HLS segments are a PNG header plus MPEG-TS. Online play strips the header. The downloader concatenated the shells, so the saved file does not start with media magic and Play refuses it.

## Fix

Strip each segment while downloading. On Play, if the saved file still starts with a PNG, unwrap every segment and then open it. The saved episode on disk starts with a PNG; the video starts at byte 252. Play closes the file before rewriting it, then opens it as MPEG-TS. Not played in the app yet.
