# RFC-115: Foundation motion presets (pack-overridable)

**Status:** open  
**Depends on:** RFC-106, RFC-109, RFC-112  
**Area:** `packages/forja_foundation/lib/tokens/`, kit paint, forja-sdk layout schema

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** components · **10 / 10** acceptance |
| **Current slice** | Theme + scope + pack merge + migrate interactive surfaces — shipped |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R115-C01 | `ForjaMotionTheme` / `ForjaMotionScope` / `ForjaMotionScale` — numbers only in theme factory | ✅ |
| 2 | R115-C02 | `ShellPaintScope.focusableTap(motion:)` resolves focus scale from theme | ✅ |
| 3 | R115-C03 | Pack layout `motion{}` + per-node props → host Motionscope merge (generic) | ✅ |
| 4 | R115-C04 | SDK schema + `components.md` motion contract | ✅ |
| 5 | R115-C05 | Migrate catalog/details/chrome/guide/sources/DS interactive widgets onto presets | ✅ |
| 6 | R115-C06 | Tests: defaults, leanback hover off, merge overlay | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R115-A01 | Widgets use preset names only — no hover/focus scale or motion-duration literals outside theme | ✅ |
| 2 | R115-A02 | Closed presets: `cardLift`, `chipLift`, `fillOnly`, `railIcon`, `none` (+ specialized kenBurns / playPulse / favoriteHeartbeat) | ✅ |
| 3 | R115-A03 | Pack `motion{}` on layout root overrides that pack tree without host pack-id branches | ✅ |
| 4 | R115-A04 | Per-node `motion` + numeric overrides win over pack map for that node | ✅ |
| 5 | R115-A05 | Unknown pack motion keys ignored; host does not invent presets | ✅ |
| 6 | R115-A06 | Leanback `scaleOnHover: false` — no hover grow; focus scale still from theme | ✅ |
| 7 | R115-A07 | Media cards (poster / continue / episode / cast / trailers) use `cardLift` | ✅ |
| 8 | R115-A08 | Chrome chips/rails/rows use `fillOnly`; arrows / season / mood / portal icons use `chipLift` | ✅ |
| 9 | R115-A09 | DS Accordion/Item/ListTile/VerticalMenu/Segmented/Toggle/MoodCircle/Pagination on presets; Material forms stay `none` | ✅ |
| 10 | R115-A10 | SDK schema documents `motion` map + enum props | ✅ |

---

## Summary

Closed interaction intents in foundation. **All numbers** live in `ForjaMotionTheme`. Widgets pick a preset name. Packs override via paint-tree `motion{}` and optional per-node props. Host merges generically. `ShellPaintScope.scaleOnHover` remains host input policy (desktop vs leanback).

## Assignment (intent)

| Preset | Surfaces |
|--------|----------|
| `cardLift` | posters, continue, episode, cast/trailer thumbs |
| `chipLift` | mood, season, scroller arrows, small controls |
| `fillOnly` | chips, rails, list rows, dense/EPG/channel/event, sources/guide rows |
| `railIcon` | nav rail (defaults from ShellTokens rail scales) |
| `none` | Material forms, static paint, layout shells |

## Out of scope

Host per-pack-id motion tables · free-form pack effect names · lift on Button/forms · OS reduce-motion (follow-up)
