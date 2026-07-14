# 048 — VidSrc.sbs iframe playback restricted

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** `HostProviderAdapter` / `StreamExtractor` (Flutter WebView extraction)

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 1** fix tasks · **1 / 2** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I48-T01 | Load `vidsrcsbs` as the WebView top-level document, bypassing Forja's optional iframe wrapper (`forceDirect` in `StreamExtractor.extract`, keyed by provider ID in `HostProviderAdapter`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I48-A01 | Resolver returns `https://vidsrc.sbs/embed/tv/94997/1/1` for HOTD S1E1 (`plugins/vidsrcsbs.rs` HostRequired template) | ✅ |
| 2 | I48-A02 | Rebuilt app resolves and opens VidSrc.sbs with global **Embed** enabled | ⬜ |

---

## Summary

The canonical URL was already correct and `VidsrcsbsProvider` already resolves correctly as a `HostRequired` template embed. The failure was Flutter-side: VidSrc.sbs detects iframe embedding and displays **Playback Restricted**, and Forja's global **Embed** setting wrapped the provider page in an iframe — reproducing that rejection.

Fix is entirely on the host side: `vidsrcsbs` now bypasses the optional iframe wrapper and loads as the headless WebView's top-level page. Plugin layout for template embeds (including VidSrc.sbs) is tracked in [050](fixed/050-[fixed]-template-embed-one-file-per-plugin.md).

## Verify

```bash
./scripts/resolve-engine.sh -p vidsrcsbs --tmdb=94997 --media=tv --season=1 --episode=1 --json
cd crates && cargo test -p resolver-engine host_template
```
