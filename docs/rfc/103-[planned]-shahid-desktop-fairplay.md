# RFC-103: Shahid desktop FairPlay (macOS)

**Status:** planned  
**Depends on:** [RFC-101](101-[open]-shahid-hub-provider-exo-widevine.md) (catalog + DRM license fetch), [RFC-029](029-[open]-dual-built-in-playback-engines.md)  
**Area:** `plugins/providers/shahid.js`, macOS native player (AVPlayer / FairPlay), `StreamDrmConfig`, desktop player open path

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 3** components · **0 / 8** acceptance (macOS FairPlay) |
| **Current slice** | Spec — desktop Shahid play via FairPlay; MediaKit Widevine is not a path |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R103-C01 | Provider emits FairPlay-capable stream row (HLS + cert / license) when Shahid returns FairPlay | ⬜ |
| 2 | R103-C02 | macOS AVPlayer (or equivalent) with FairPlay content-key session | ⬜ |
| 3 | R103-C03 | Desktop play path: DRM Shahid → FairPlay player; no MediaKit open; no Android-only UX | ⬜ |

---

## Acceptance (slice — macOS FairPlay)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R103-A01 | Shahid DRM response maps `fairplay` cert (+ license) into `StreamDrmConfig` (`scheme: fairplay`) | ⬜ |
| 2 | R103-A02 | Playout prefers HLS (or FairPlay-compatible) URL when targeting desktop Apple | ⬜ |
| 3 | R103-A03 | macOS native player loads FairPlay cert and completes license exchange | ⬜ |
| 4 | R103-A04 | Desktop Play / Sources opens FairPlay path for Shahid DRM — MediaKit never fed encrypted MPD | ⬜ |
| 5 | R103-A05 | Toast / empty copy never mentions Android ExoPlayer | ⬜ |
| 6 | R103-A06 | Connected Services login still required for VIP / license | ⬜ |
| 7 | R103-A07 | Host tests: synthetic FairPlay `drm` fixture (no pack id) | ⬜ |
| 8 | R103-A08 | Manual QA: one Shahid episode plays on macOS desktop build | ⬜ |

---

## Summary

Product target for Shahid **play** while developing on desktop is **macOS FairPlay**, not Android Widevine. [RFC-101](101-[open]-shahid-hub-provider-exo-widevine.md) already shipped catalog, signed DRM license fetch, and an Android Exo Widevine path. That Android path stays as an extra; it is **not** the desktop UX.

Shahid’s `playout/new/drm` success body includes a FairPlay certificate URL alongside the Widevine `signature`. Desktop MediaKit cannot decrypt Widevine; forcing MediaKit yields green/gray frames. Correct desktop approach: FairPlay content keys + Apple AVPlayer (or a thin Flutter wrapper), with provider rows that carry HLS + FairPlay DRM fields.

### Goals

1. Play Shahid DRM titles on **macOS desktop** with FairPlay.
2. Keep catalog + Connected Services as shipped.
3. Stop telling desktop users to use Android.

### Non-goals (this RFC)

- Windows / Linux Shahid DRM (no FairPlay; separate later if ever)
- MediaKit Widevine CDM
- Embed / WebView playback ([no-embed-playback](../../.cursor/rules/no-embed-playback.mdc))

### Related

- [RFC-101](101-[open]-shahid-hub-provider-exo-widevine.md) — Android Widevine + catalog
- [issue 258](../issues/258-[open]-shahid-android-drm-manual-qa.md) — Android QA only
- [features/hubs/shahid.md](../features/hubs/shahid.md)
