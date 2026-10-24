# 477 — My List Open in… sheet is host-decided; kit.list needs a pack-declared `bind` verb

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** packs · kit painter · My List · RFC-109  
**Reported:** 2026-10-24 (owner: "dialog open with in mylist is host owned, must not, it must be pack specific")

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **1 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Symptom

Selecting a My List poster can open an **Open in…** sheet, long-press opens **Open with…**, and every poster carries a list pin. None of that is declared by the My List pack. The host decides it for every feed-only `kit.list` whose plugin has no `details` capability, and the sheet's wording lives in host Dart.

## Root cause

- `list_open_flow.dart:15-16` — `kitListUsesOpenBinding(callerHasDetails) => callerHasDetails == false`: a capability sniff stands in for a pack verb.
- `paint_tree.dart:2078-2107, 2191-2200, 2338-2347` — every non-managed `kit.list` gets the bind tap, the long-press rebind and the pin accessory. Comment says "Feed-only hubs (My List)".
- `list_open_flow.dart:193, 204, 230` and `list_open_bind_sheet.dart:267, 410, 458, 832, 884, 985` — product copy ("Open in…", "Open with…", "No hub available…", "Search title", "Best match", "Cancel") hardcoded in host.
- Side effect: Live Sports 24/7 channel tiles (`live_sports/_layout.js` tv_channels, `open: 'play'`, plugin has no `details`) get the My List hub picker on long-press.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I477-T01 | My List pack `kit.list` declares `open: 'bind'`, a `bind { title, pickTitle, searchHint, searchBrowseHint, noMatch, noHub, bestMatch, cancel, remember, rebind }` block, and `accessory: 'listPin'` | ✅ |
| 2 | I477-T02 | Foundation protocol `KitListBindSpec` + `KitListAccessorySpec` (props in → typed spec out, no hooks) | ✅ |
| 3 | I477-T03 | Painter routes `open: 'bind'` to the bind flow; long-press only when `bind.rebind`; accessory only when declared; invalid `bind` logs once and falls back to plain open | ✅ |
| 4 | I477-T04 | Bind flow and sheet take copy from the spec; delete `kitListUsesOpenBinding`, the `hasDetails` branch and `openLegacyListItem` | ✅ |
| 5 | I477-T05 | IPTV, Live Sports and Downloads layouts declare their `accessory` (favorite / list pin) so today's pins stay; no `bind` on Live Sports channels | ✅ |
| 6 | I477-T06 | Tests: tap-open matrix with `bind`, painter wiring with and without `bind` / `accessory`, foundation spec parse (synthetic JSON only) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I477-A01 | `grep -rn "Open in…\|Open with…\|kitListUsesOpenBinding\|No hub available" apps/forja/lib` → 0 hits | ✅ |
| 2 | I477-A02 | Live Sports 24/7 channel long-press shows no hub picker; favorite star still there | ⬜ |
| 3 | I477-A03 | My List tap / long-press / pin behave as before on desktop and Android TV, with the pack's wording | ⬜ |
| 4 | I477-A04 | IPTV channel tiles keep the favorite star, IPTV VOD posters keep the list pin | ⬜ |

## Compatibility

Heuristic removed outright, not kept as a fallback. An older My List pack on the new host gets a plain open by `open.surface` with one debug log line and no sheet. The owner ships both repos and the remote catalog serves the latest pack.

## Deferred

- Sheet paint → foundation widget (props + field builder). Tracked as R109-A91.

## Links

- [RFC-109](../rfc/109-[open]-forja-pack-product-host.md) — A89–A91
- [RFC-108](../rfc/fixed/108-[fixed]-my-list-open-hub-binding.md) — designed the host sheet this issue moves behind a pack verb
- [260](260-[open]-host-hardcodes-specific-plugins.md) — I260-T07
- [400](400-[open]-my-list-open-with-hub-checkbox.md) · [473](fixed/473-[fixed]-my-list-open-with-size-persist-card.md) — prior iterations on the same sheet
