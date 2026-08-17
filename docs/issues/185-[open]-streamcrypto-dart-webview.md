# 185 — STREAMCRYPTO Dart + WebView (shared enc=2 decrypt)

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** `StreamCrypto` / `VideasyExtractor` / VidSrc.sbs nested player

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **2 / 4** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I185-T01 | Shared Dart `StreamCrypto` (AniWorld / player JS, uint32-safe) | ✅ |
| 2 | I185-T02 | Keep JS WebView host; admin Playback setting picks `webview` / `native` | ✅ |
| 3 | I185-T03 | Videasy `enc=2` decrypt uses the setting (native skips Headless WebView) | ✅ |
| 4 | I185-T04 | VidSrc.sbs nested `player.videasy.*` uses STREAMCRYPTO HTTP, not sniff | ✅ |
| 5 | I185-T05 | Unit: round-trip / bad magic / host routing; TV does not skip videasy / vidsrcsbs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I185-A01 | Unit: Dart encrypt→decrypt round-trip; wrong seed / garbage throw | ✅ |
| 2 | I185-A02 | Unit: `player.videasy.to` / `.net` is STREAMCRYPTO; cinesrc / nxsha is not | ✅ |
| 3 | I185-A03 | Manual: pin Videasy, switch STREAMCRYPTO decrypt Native vs WebView — both resolve | ⬜ |
| 4 | I185-A04 | Manual: pin VidSrc.sbs 4K (`player.videasy.net`) — HTTP STREAMCRYPTO, not 75s sniff | ⬜ |

---

## Summary

STREAMCRYPTO is the **enc=2 player** (seed + tmdbId → XOR keystream → `mvm1` JSON). Same blob as AniWorld cineby/vidking. It is **not** Videasy-provider-private.

Forja’s JS only lived in `VideasyExtractor`, but VidSrc.sbs **4K** is the same player (`player.videasy.net` → `.to`) and was generic `StreamExtractor` sniff — never `/seed` + `enc=2`.

**Shipped:** Dart port + existing WebView host. Settings → Playback (admin, Webstreaming on) **STREAMCRYPTO decrypt** chooses one. Nested videasy URLs call `VideasyExtractor` HTTP. Default stays WebView.

**Not this issue:** Cinesrc `playlist_010.jpg` segment sniff (`contains('playlist')`).

Rust-native Videasy remains [RFC-032](../rfc/032-[open]-rust-resolver-engine.md) R32-A09.

## Related

- [041](fixed/041-[fixed]-videasy-hangs-before-cdn-yoru.md) — mirror probe order
- [048](048-[open]-vidsrc-sbs-iframe-playback-restricted.md) — VidSrc.sbs top-level load
- [stream-providers](../features/sources/stream-providers.md)
- [playback-settings](../features/settings/playback-settings.md)
