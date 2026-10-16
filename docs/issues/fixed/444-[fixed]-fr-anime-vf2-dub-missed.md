# 444 — French anime VF/VF2 dub missed (Anime-Sama / VoirAnime)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Anime · Sources · Providers

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I444-T01 | Map site `vf2` / `vfq` / `vfN` reader keys to DUB in `_fr_anime_embeds` | ✅ |
| 2 | I444-T02 | Anime-Sama fetch `vf` + `vf2` + `vfq` (honour extract `category`) | ✅ |
| 3 | I444-T03 | Changelog + providers pack version bump | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I444-A01 | One Piece S1E1 with DUB / VF selected shows Anime-Sama and/or VoirAnime streams | ⬜ |
| 2 | I444-A02 | SUB / VOSTFR still returns Japanese · sous-titres FR rows, not VF2 | ⬜ |

---

## Summary

French sites keep a live French dub under **`vf2`** when the legacy **`vf`** ansembed is 404. Packs only scraped `vf` + `vostfr`, so DUB filter got `raw=1` VOSTFR → `streams=0`. Fix: treat every `vf*` reader key as dub, and Anime-Sama also loads `saisonN/vf2`.

## Related

- [443](443-[fixed]-anime-stream-languages-like-home.md) — anime stream language filter stamps `category`
