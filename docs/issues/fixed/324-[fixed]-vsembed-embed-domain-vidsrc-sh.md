# 324 — VSEmbed embed domain → vidsrc.sh

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** VSEmbed / `vidsrc` · `ProviderRuntimeConfig` builtins

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **2 / 2** fix · **1 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I324-T01 | Builtin `apis.vidsrcEmbed` + `templates.vidsrc` → `https://vidsrc.sh` path embeds | ✅ |
| 2 | I324-T02 | Feature tip + changelog Sources bullet | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I324-A01 | Builtins open VSEmbed as `vidsrc.sh/embed/movie\|tv/{tmdb}/…` (Referer host `vidsrc.sh`) | ✅ |

---

## Summary

VSEmbed operators announced **`vidsrc.sh`** as the main embed mirror (`/embed/movie/{imdb|tmdb}`, `/embed/tv/{id}/{season}/{episode}`). Older hosts (`vsembed.su`, …) keep working.

**Root fix:** retarget Dart builtins — `vidsrcEmbed` origin and `vidsrc` movie/TV templates — to `vidsrc.sh` path style (TMDB ids Forja already has). Playback Referer for `vidsrc` follows the same origin.

## Related

- [164](../164-[open]-vsembed-new-player-chain.md) — sniff / new player chain (still open)
- [047](047-[fixed]-vidsrc-vsembed-su-and-broken-plugin.md) — prior `vsembed.su` move
- [stream-providers.md](../../features/sources/stream-providers.md)
