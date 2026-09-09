# RFC-101: Shahid hub + provider + Exo Widevine

**Status:** open  
**Depends on:** [RFC-029](029-[open]-dual-built-in-playback-engines.md), [RFC-089](fixed/089-[fixed]-pack-addon-settings.md)  
**Area:** `plugins/hubs/shahid/`, `plugins/providers/shahid.js`, `apps/forja/android/`, `shared/player/exo/`, pack settings, engine stream map

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **6 / 6** A · **4 / 4** B · **5 / 6** C · **3 / 3** D · **1 / 1** E |
| **Current slice** | Catalog API retarget (top-ranking + search); Connected Services auth via [RFC-102](102-[open]-pack-connected-services-auth.md); manual DRM QA — [issue 258](../issues/258-[open]-shahid-android-drm-manual-qa.md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R101-C01 | Generic stream `drm` contract + Android Exo Media3 Widevine / SmoothStreaming | ✅ |
| 2 | R101-C02 | Pack settings `password`/`secret` → Keychain + inject into `runPlugin` config | ✅ |
| 3 | R101-C03 | Shahid hub + provider packs + official onboarding | ✅ |
| 4 | R101-C04 | Shahid login via pack Connected Services auth ([RFC-102](102-[open]-pack-connected-services-auth.md)) | ✅ |

---

## Acceptance (slice A — DRM + Exo)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R101-A01 | `mapEngineStream` / `StreamSource` pass optional `drm` (scheme, licenseUrl, licenseHeaders) | ✅ |
| 2 | R101-A02 | Gradle Media3 DRM + SmoothStreaming; Exo `MediaItem.DrmConfiguration` wired | ✅ |
| 3 | R101-A03 | Android: DRM stream forces Exo even if MediaKit preferred for VOD | ✅ |
| 4 | R101-A04 | Non-Android / MediaKit: DRM sources skipped or toast; clear HLS still plays | ✅ |
| 5 | R101-A05 | Host unit test: synthetic `drm` fixture maps through (no pack id) | ✅ |
| 6 | R101-A06 | No embed/WebView fallback for DRM miss | ✅ |

---

## Acceptance (slice B — pack secrets)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R101-A07 | Pack field types `password` / `secret` store in SecureSettings | ✅ |
| 2 | R101-A08 | Addons UI obscures secret fields | ✅ |
| 3 | R101-A09 | `runPlugin` merges pack settings + secrets into extract `config` | ✅ |
| 4 | R101-A10 | Host unit test: synthetic secret merge (no Shahid id) | ✅ |

---

## Acceptance (slice C — Shahid packs)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R101-A11 | Hub `forjahq-shahid` kit catalog (rails, search, details, videos) | ✅ |
| 2 | R101-A12 | Provider `shahid` extract: clear HLS or Widevine license row | ✅ |
| 3 | R101-A13 | Login via pack settings email + password | ✅ |
| 4 | R101-A14 | Official pack list + catalog regen; nav tab Shahid | ✅ |
| 5 | R101-A15 | Feature docs + changelog bullets | ✅ |
| 6 | R101-A16 | Manual Android QA with Shahid account — [issue 258](../issues/258-[open]-shahid-android-drm-manual-qa.md) | ⬜ |

---

## Acceptance (slice D — Connected Services auth)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R101-A17 | Shahid hub declares `settings.addon: connected_services` + `auth` (no permanent Account fields) | ✅ |
| 2 | R101-A18 | Login methods (email / phone) via pack `auth_*` actions; session secrets inject into extract | ✅ |
| 3 | R101-A19 | Feature docs describe Connected services Login (not pack Account fields) | ✅ |

---

## Acceptance (slice E — catalog API)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R101-A20 | Hub feed/rail/search use live Shahid endpoints (`top-ranking` / `related` / `search/{tab}` + `country` + profile headers); drop dead `product/filter` | ✅ |

---

## Summary

Add a **Shahid** hub and stream provider using MBC’s public catalog/playout APIs (same shape as the Kodi add-on and yt-dlp). Premium titles use **Android Exo + Widevine** against Shahid’s license server with the user’s account — not key extraction. Clear HLS plays on all engines when `drm` is absent.

Generic host pieces (stream `drm` field, pack secrets) stay pack-agnostic so other licensed OTTs can reuse them.

## Goals

1. Browse Shahid catalog in Forja (kit hub).
2. Play free/clear streams on Exo and MediaKit.
3. Play DRM titles on Android Exo with official license URL.
4. Store Shahid session in Keychain via pack Connected Services auth ([RFC-102](102-[open]-pack-connected-services-auth.md)).

## Out of scope

- Desktop / iOS / MediaKit Widevine
- DRM circumvention / ClearKey theft
- Arabic/Larozaa changes
- Portal `db push` (admin publishes catalog separately)

## Related

- [RFC-029](029-[open]-dual-built-in-playback-engines.md)
- [issue 258](../issues/258-[open]-shahid-android-drm-manual-qa.md)
- [plugin.video.shahid](https://github.com/chamchenko/plugin.video.shahid)
- [yt-dlp Shahid](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/shahid.py)
