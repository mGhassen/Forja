# 114 — Android TV movie MediaKit: sound but no video

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · movie/VOD player · MediaKit · Impeller  
**Reported:** 2026-07-26 (switch Exo → MediaKit in movies)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I114-T01 | Remove manifest `EnableImpeller=true` (raced TV `--enable-impeller=false`) | ✅ |
| 2 | I114-T02 | MainActivity `getFlutterShellArgs` adds Impeller disable on TV | ✅ |
| 3 | I114-T03 | VOD MediaKit: `vo=mediacodec_embed` + surface attach when `PlatformInfo.isAndroidTv` (IPTV parity) | ✅ |
| 4 | I114-T04 | Engine switch passes session URL/headers; ATV player uses `_sessionStreamUrl` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I114-A01 | Android TV release: open a movie on Exo, switch **Player → MediaKit** — video + audio | ⬜ |
| 2 | I114-A02 | Android TV: set MediaKit in Settings, open a movie — video (not black) | ⬜ |

---

## Summary

Switching movies to **MediaKit** on Android TV played **audio with a black picture** (same class of bug as the old VOD Impeller + `vo=gpu` path).

**Root causes:**

1. **Impeller race:** `AndroidManifest` forced `EnableImpeller=true` while `ForjaApplication` passed `--enable-impeller=false` on TV. Both flags could land in the shell-arg set; Impeller then broke MediaKit’s SurfaceProducer (audio OK, no frames).
2. **VOD vs IPTV knobs:** IPTV already used `mediacodec_embed` + `androidAttachSurfaceAfterVideoParameters: false`; VOD only keyed off `tvRemoteEnabled` and omitted the surface attach flag.
3. **Engine switch / ATV session:** ATV `PlayerScreen` passed `widget.streamUrl` instead of the live session URL when swapping engines.

**Fix:** Drop the manifest Impeller force (phones keep API 29+ default Impeller). Keep Application + MainActivity Impeller off on TV. Align VOD MediaKit with IPTV embed output. Persist session URL across Exo ↔ MediaKit switches.

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — Exo TextureView compositing  
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — IPTV MediaKit `mediacodec_embed` (I108-T05)  
- Changelog 1.2.366 — first ATV MediaKit video fix (Impeller + embed)
