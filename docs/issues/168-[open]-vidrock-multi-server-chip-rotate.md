# 168 — VidRock Sources shows one stream (Servers list not rotated)

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** `vidrock` EmbedExtractProfile · `StreamExtractor` chip rotate

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix tasks · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I168-T01 | VidRock profile: forceDirect + defer + rotateServerChips; click `[data-server-list]` / Server List; 90s sniff / 120s SimpleResolve | ✅ |
| 2 | I168-T02 | Unit + feature doc + changelog | ✅ |
| 3 | I168-T03 | Clicker: open title=`Server List` panel; select `div.cursor-pointer` rows (not star buttons); accent = active | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I168-A01 | Unit: vidrock profile has rotate + defer + empty chip labels | ✅ |
| 2 | I168-A02 | App: pin VidRock — Sources lists multiple server streams when site has several (manual) | ⬜ |

---

## Summary

Web VidRock exposes a Servers panel (`[data-server-list]`) fed by `https://vidrock.ru/api/movie|tv/…` (AES-GCM decrypt per server). Forja used a bare sniff profile — first strong playlist completed → one Sources row.

**Symptom fix (shipped):** chip-rotate collect-all via Server List / `[data-server-list]` rows; HLS.js defer; no early complete. T03: panel only mounts when open (icon `title="Server List"`); rows are `div.cursor-pointer` (not `<button>` — those are star toggles).

**Root (open, later):** host/Rust fan-out of `/api/movie|tv/{tmdb}` + decrypt every server without WebView.

## Related

- [082](082-[open]-multi-server-collect-all.md) — collect-all policy
- [Stream providers](../features/sources/stream-providers.md)
