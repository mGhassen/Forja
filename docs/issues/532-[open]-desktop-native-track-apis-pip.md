# 532 — Desktop native track APIs + OS PiP

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** Desktop · AVPlayer · libVLC · audio/subs/quality · PiP  
**Reported:** 2026-11-03 (follow-up from 531 chrome parity — toast stubs)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I532-T01 | AVPlayer / VLC bridge APIs for audio + text track list/select | ⬜ |
| 2 | I532-T02 | Quality / HLS variant selection on native engines (or honest unavailable) | ⬜ |
| 3 | I532-T03 | Desktop OS PiP for native engines, or keep MediaKit-only with chrome toast | ⬜ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I532-A01 | Catalog AVPlayer/VLC Audio/Subs/Quality menus work like MediaKit, or PiP/tracks documented as MediaKit-only without toast stubs | ⬜ |

---

## Symptom

After [531](fixed/531-[fixed]-desktop-native-vod-chrome-match-mediakit.md), Audio / Subs / Quality / PiP buttons show on native desktop VOD but toast that MediaKit/Exo is required.

## Root cause

Native bridges do not yet expose track enumeration/selection or desktop PiP handoff. Chrome was shipped present (no-hide) with stubs.

## Links

- [531](fixed/531-[fixed]-desktop-native-vod-chrome-match-mediakit.md)
- [RFC-107](../rfc/107-[open]-iptv-multi-engine-avplayer-vlc.md)
