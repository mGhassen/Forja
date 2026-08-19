# 169 — VidFast sniff misses streams (`/w/` + bundled HLS)

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** `vidfast` EmbedExtractProfile · `StreamExtractor`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix tasks · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I169-T01 | Sniff `/w/{uuid}/…` bodies + JSON URL walk when `acceptProxyPlaylistBodies` | ✅ |
| 2 | I169-T02 | Hook bundled HLS (`loadSource` deep-scan + `defineProperty` trap); chip-rotate Servers | ✅ |
| 3 | I169-T03 | Profile timeout 90s · SimpleResolve 120s · unit + feature doc + changelog | ✅ |
| 4 | I169-T04 | Engine `ctx.host` budget = sniff timeout+30s; settle default server if chips never click | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I169-A01 | Unit: vidfast rotates chips + defer + proxy bodies | ✅ |
| 2 | I169-A02 | App: pin VidFast — Sources gets stream(s) when browser plays (manual) | ⬜ |

---

## Summary

VidFast SPA loads in headless sniff (`autoPlay`, UI chrome, `/w/…` fetches) but never emitted `HLS_SRC` / `.m3u8` — webpack keeps HLS.js off `window.Hls`, and opaque `/w/{uuid}/…` bodies were not scanned as proxy playlists. Browser works; Forja timed out empty.

**Symptom fix (shipped):** expand proxy-body scan for `/w/`, deep-hook `loadSource`, enable Server chip-rotate collect-all. T04: Forja engine wait matches sniff budget (30s was dumping `[]` after `HLS_SRC`); idle-complete ~8s when no Server chip clicks so default HLS is not held until 90s.

**Root (HTTP still EncDec):** `vidfast.js` still goes through enc-dec.app; miss → `ctx.host` sniff. Bundled HLS hook is the working path when EncDec misses.

## Related

- [082](082-[open]-multi-server-collect-all.md) — collect-all pattern
- [168](168-[open]-vidrock-multi-server-chip-rotate.md) — VidRock chip-rotate
- [170](170-[open]-vidzee-cloudflare-sniff.md) — Vidzee CF (separate)
