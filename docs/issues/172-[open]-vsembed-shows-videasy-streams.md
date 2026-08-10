# 172 — VSEmbed Sources panel shows Videasy streams

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** player Sources · `vidsrc` / VSEmbed · `videasy` · `StreamExtractor`

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I172-T01 | `StreamExtractor` cancel/extract: pin completer + await cancel so shared WebView cannot complete the next provider's session | ✅ |
| 2 | I172-T02 | `sourcesOwnedByProvider` / panel cache: reject foreign `providerId` + Videasy mirror titles under non-videasy buckets | ✅ |
| 3 | I172-T03 | `_loadProvider` / `hitsToProviderCache`: refuse hit whose `providerId` ≠ requested server | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I172-A01 | Unit: Videasy `Yoru`/`Breach` rows filtered out of `vidsrc` cache/panel | ✅ |
| 2 | I172-A02 | Manual: open title → Videasy plays → expand VSEmbed → streams are not Videasy mirror labels | ⬜ |

---

## Summary

Sources panel showed identical **Yoru / Cypher / Breach · playhq** rows under both Videasy and VSEmbed. Those titles come only from `VideasyExtractor` API mirrors — VSEmbed (`vidsrc`) must never display them.

**Root:** shared host `StreamExtractor` cancel raced a newer `extract` (unawaited cancel completing the wrong completer), plus cache writes keyed by the tapped server without checking ownership.

**Symptom fix:** ownership filter at cache + panel; load refuses mismatched hits.

**Engine/session fix:** cancel pins the session completer; `extract` awaits cancel before starting.

## Related

- [164](164-[open]-vsembed-new-player-chain.md) — VSEmbed sniff path
- [047](fixed/047-[fixed]-vidsrc-vsembed-su-and-broken-plugin.md) — VSEmbed labeling
