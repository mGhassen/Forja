# 114 — Android TV movie MediaKit: sound but no video

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · movie/VOD player · MediaKit · Impeller  
**Reported:** 2026-07-26 (switch Exo → MediaKit in movies)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |
| **Current slice** | SurfaceTexture producers under Impeller OpenGLES (Xiaomi A11) — smoke pending |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I114-T01 | Remove manifest `EnableImpeller=true` (raced TV `--enable-impeller=false`) | ✅ |
| 2 | I114-T02 | MainActivity `getFlutterShellArgs` adds Impeller disable on TV | ✅ |
| 3 | I114-T03 | VOD MediaKit: `vo=mediacodec_embed` + surface attach when `PlatformInfo.isAndroidTv` (IPTV parity) | ✅ |
| 4 | I114-T04 | Engine switch passes session URL/headers; ATV player uses `_sessionStreamUrl` | ✅ |
| 5 | I114-T05 | ATV: `FlutterRenderer.debugForceSurfaceProducerGlTextures` so MediaKit uses SurfaceTexture (not ImageReader) under Impeller OpenGLES | ✅ |

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
4. **ImageReader SurfaceProducer (API 29+):** After [215](215-[open]-android-tv-skia-glyph-atlas-glitch.md) moved leanback to Impeller OpenGLES, `TextureRegistry.createSurfaceProducer()` still picked **ImageReader** on Android 11+. On Amlogic/Xiaomi boxes that path composites no frames (audio OK). Toshiba Android 7 (API &lt; 29) already used **SurfaceTexture** and kept picture. Exo works because it paints via PlatformView TextureView, not Flutter SurfaceProducer.

**Fix (earlier):** Drop the manifest Impeller force. Align VOD MediaKit with IPTV embed output. Persist session URL across Exo ↔ MediaKit switches.

**Fix (T05):** On leanback only, set `FlutterRenderer.debugForceSurfaceProducerGlTextures = true` in `ForjaApplication` before engine init so MediaKit’s `createSurfaceProducer()` returns a **SurfaceTexture** producer (OpenGLES path). Keep Impeller OpenGLES for glyphs. Do **not** set on phones (undefined with Impeller Vulkan).

## Follow-up (issue 215)

Forcing Skia on leanback (`--enable-impeller=false`) fixed MediaKit black video but **corrupted glyph/icon atlases** on physical ATV (garbled synopsis text, action icons). **Issue 215** switches ATV to **Impeller + `--impeller-backend=opengles`** while keeping `vo=mediacodec_embed`. T05 keeps that UI path and fixes MediaKit compositing without re-enabling Skia. Re-verify I114-A01 / A02 and I215-A02 on Xiaomi Android 11 + Toshiba Android 7.

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — Exo TextureView compositing  
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — IPTV MediaKit `mediacodec_embed` (I108-T05)  
- [215](215-[open]-android-tv-skia-glyph-atlas-glitch.md) — ATV Skia text/icon garbage → Impeller OpenGLES  
- Changelog 1.2.366 — first ATV MediaKit video fix (Impeller + embed)
