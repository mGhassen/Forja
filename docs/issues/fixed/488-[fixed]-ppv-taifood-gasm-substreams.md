# 488 — PPV dead after taifood-blog.asia + language substreams

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs` · livesports `ppv` · gasm unlock  
**Reported:** 2026-10-25 (flutter: `ppv` resolve `raw=0` / `[PPV] streams=0`; web still plays)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Live Sports PPV catalog listed events, but Providers / play returned no streams. Unlock logs never showed gasm work (~15–20ms empty). Web ppv.st played fine and offered multiple language/broadcast mirrors (ESPN+, DAZN locales, …).

## Root cause

1. Detail API `sources[].data` moved to `https://taifood-blog.asia/embed/{path}` (same `/fetch` + `island` gasm as embedindia). `unlockPpvEmbed` only cracked embedindia / embed.st / sportsembed → immediate `null`.
2. Language mirrors live in `data.substreams[]` (`source_tag` + `locale` + own iframe). Pack only read parent `sources` → one unlabeled mirror at best.

Verified: `POST https://taifood-blog.asia/fetch` with protobuf field-1 path returns `island`; pack `gasm/unlock.mjs` yields `.m3u8` on `*.indianservers.st`.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I488-T01 | Treat `taifood-blog.asia` as gasm path embed in `_prelude.js` / `embed-st.js` | ✅ |
| 2 | I488-T02 | `unlockPpvEmbed` → `resolveEmbedIndia` / gasm for that host | ✅ |
| 3 | I488-T03 | Discover parent + `substreams` as labeled mirrors (`language` = `tag (locale)`) | ✅ |
| 4 | I488-T04 | Bump livesports pack `2.0.47` | ✅ |
| 5 | I488-T05 | List-API fallback when detail omits substreams; unique mirror ids; pack `2.0.48` | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I488-A01 | Barça–Madrid (or live PPV) shows multiple PPV language/source rows in Providers | ⬜ |
| 2 | I488-A02 | Tapping a PPV row unlocks to native play (MediaKit/Exo) | ⬜ |

## Links

- Live native playback law · catalog schedule-only
- Peer unlock: embedindia gasm path
