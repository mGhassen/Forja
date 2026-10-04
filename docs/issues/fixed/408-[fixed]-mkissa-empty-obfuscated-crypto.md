# 408 — MKissa Sources empty (obfuscated client-crypto)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/mkissa.js` · Anime Sources · MKissa

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I408-T01 | Parse obfuscated `saltMul` crypto chunk (`buildId` / mask / boot prefix / join parts) | ✅ |
| 2 | I408-T02 | Sign `x-aa-boot` with live mask salts and `group/lane/host/buildId/epoch` payload | ✅ |
| 3 | I408-T03 | Implement missing `handleWatch` (episode sources → extract / hop) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I408-A01 | Anime → a title MKissa has → Sources lists a playable MKissa Sub and/or Dub stream | ⬜ |

---

## Summary

MKissa episode GraphQL needs client-crypto (`aaReq`). The site’s JS now obfuscates `buildId` / mask fragments (`saltMul` 20, boot prefix, `/` join). Extract still looked for the old `?"digits":""` chunk, and `handleWatch` was never defined, so every title returned `[]`. Search still works without crypto.

**Root fix:** eval the obfuscated crypto table, sign bootstrap with the live mask and boot payload, and fetch/extract episode `sourceUrls`. Providers pack **1.6.40**.
