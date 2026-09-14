# RFC-110: Pack surface contributions (layers / modules / slots)

**Status:** draft  
**Depends on:** [RFC-070](070-[partial]-catalog-hub-protocol.md) · [RFC-089](fixed/089-[fixed]-pack-addon-settings.md) · [RFC-099](099-[open]-live-unlock-pack-modules.md) · [RFC-106](fixed/106-[fixed]-forja-foundation-design-system-package.md) · [RFC-109](109-[open]-forja-pack-product-host.md)  
**Area:** pack protocol · host contribution registry · foundation mount points · Addons UX

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 8** components · **26 / 28** acceptance (spec) · **0 / 12** acceptance (host registry) · **0 / 10** acceptance (details+player slots) · **0 / 6** acceptance (conflict UX) · **0 / 4** acceptance (reference packs) |
| **Current slice** | Spec drafted — cursor rule + SDK note still open; code not scheduled |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R110-C01 | Slot registry + contribution parse on `EnginePlugin` / pack manifest | ⬜ |
| 2 | R110-C02 | Contribution resolver (bind + priority + exclusive vs additive) | ⬜ |
| 3 | R110-C03 | Details mount points consume `details.*` contributions | ⬜ |
| 4 | R110-C04 | Player chrome mount points consume `player.*` contributions | ⬜ |
| 5 | R110-C05 | Addons conflict / override UI for exclusive slots | ⬜ |
| 6 | R110-C06 | Migrate enrich / layout / settings / unlock into contribution vocabulary | ⬜ |
| 7 | R110-C07 | Grep gates + host tests (synthetic fixtures only) | ⬜ |
| 8 | R110-C08 | Reference packs: hub+providers vs details+player-chrome | ⬜ |

---

## Acceptance (spec / law)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R110-A01 | RFC documents layers vs modules vs slots; forbids free screen hierarchy | ✅ |
| 2 | R110-A02 | Slot catalog table (built-ins + extension rules) is normative | ✅ |
| 3 | R110-A03 | Manifest `contributes[]` schema documented (slot, mode, priority, binds, payload) | ✅ |
| 4 | R110-A04 | Open identity law: source `pluginId` never remapped to a contribution pack | ✅ |
| 5 | R110-A05 | Exclusive vs additive merge rules + conflict outcomes documented | ✅ |
| 6 | R110-A06 | Host / foundation / pack ownership table matches RFC-109 sniff test | ✅ |
| 7 | R110-A07 | Capability matrix: Platform / Forja today / Plan target for each slot family | ✅ |
| 8 | R110-A08 | Non-goals: pack Dart screens, pack-id host branches, silent exclusive steal | ✅ |
| 9 | R110-A09 | Migration map: enrich, layout, addon settings, unlock modules → slots | ✅ |
| 10 | R110-A10 | Example: Pack A hub+providers + Pack B details+player-chrome composes | ✅ |
| 11 | R110-A11 | Cursor rule pointer (new or extend pack-product / external-plugins) | ⬜ |
| 12 | R110-A12 | Feature-doc / changelog policy for contribution UX when shipped | ✅ |
| 13 | R110-A13 | SDK / pack-author note: how to declare contributions | ⬜ |
| 14 | R110-A14 | Related RFC/issue cross-links updated (070, 089, 099, 109) | ✅ |
| 15 | R110-A15 | Slice plan ordered: registry → details → player → UX → reference packs | ✅ |
| 16 | R110-A16 | Binding keys: `open.surface`, `types`, optional `kinds` — no pack-id allowlists | ✅ |
| 17 | R110-A17 | Default fallback: hub-owned details/player when no contribution matches | ✅ |
| 18 | R110-A18 | Uninstall contribution pack → slots revert without breaking source hub open | ✅ |
| 19 | R110-A19 | Multiple additive sections merge with stable deterministic order | ✅ |
| 20 | R110-A20 | Priority ties broken by install time then pluginId sort (documented) | ✅ |
| 21 | R110-A21 | User override prefs key: slot → winning pluginId (Addons) | ✅ |
| 22 | R110-A22 | Contributions cannot invent new host route surfaces without RFC | ✅ |
| 23 | R110-A23 | `capabilities` remain for action discovery; `contributes` owns surface fill | ✅ |
| 24 | R110-A24 | Live / IPTV / My List product chrome eventually use same slot API | ✅ |
| 25 | R110-A25 | Providers remain cumulative (additive `player.resolve` / stream list) | ✅ |
| 26 | R110-A26 | Enrich stays a meta pipe layer (`meta.enrich`), not a details UI pack | ✅ |
| 27 | R110-A27 | Forbidden: `open` remapping to contribution pack to “open details pack” | ✅ |
| 28 | R110-A28 | TV focus / D-pad contracts stay on foundation mount points | ✅ |

---

## Acceptance (host registry)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R110-A29 | Parse `contributes[]` from plugin JSON into typed contribution records | ⬜ |
| 2 | R110-A30 | `ContributionRegistry.resolve(slot, bindCtx)` returns winner / merged list | ⬜ |
| 3 | R110-A31 | Registry rebuilds on pack install / enable / disable / uninstall | ⬜ |
| 4 | R110-A32 | Unknown slots ignored with one debug log (no crash) | ⬜ |
| 5 | R110-A33 | Invalid contribution (missing slot / payload) skipped; pack still loads | ⬜ |
| 6 | R110-A34 | Host tests: synthetic plugin ids only — no shipped hub/provider contracts | ⬜ |
| 7 | R110-A35 | Grep gate: no `switch (pluginId)` in contribution resolver | ⬜ |
| 8 | R110-A36 | Persist user exclusive-slot overrides in generic store / prefs | ⬜ |
| 9 | R110-A37 | Cache contribution resolution keyed by slot + bind fingerprint | ⬜ |
| 10 | R110-A38 | Document registry API for PackDetailsHost / PackLayoutHost / player overlay | ⬜ |
| 11 | R110-A39 | Legacy `"enrich": "<id>"` still works; registry exposes as `meta.enrich` | ⬜ |
| 12 | R110-A40 | Legacy hub `layout` + `capabilities` still work without `contributes` | ⬜ |

---

## Acceptance (details + player slots)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R110-A41 | `details.layout` exclusive — foundation runner mounts winning layout JSON | ⬜ |
| 2 | R110-A42 | `details.sections` additive — cast/trailers/extra rails merge | ⬜ |
| 3 | R110-A43 | Details open still calls source hub `details` + enrich pipe first | ⬜ |
| 4 | R110-A44 | Contribution pack may enrich via `meta.enrich` bind without owning open | ⬜ |
| 5 | R110-A45 | `player.chrome` exclusive — overlay chrome layout / hook set | ⬜ |
| 6 | R110-A46 | `player.actions` additive — extra overlay actions merge | ⬜ |
| 7 | R110-A47 | Stream providers stay additive under resolve/sources (no exclusive steal) | ⬜ |
| 8 | R110-A48 | Pack payloads are layout JSON + hook ids — not Flutter/Dart binaries | ⬜ |
| 9 | R110-A49 | PackDetailsHost / player overlay become thin slot mounts (RFC-109) | ⬜ |
| 10 | R110-A50 | Manual: hub-only vs hub+details-chrome pack — details paint changes, open id stable | ⬜ |

---

## Acceptance (conflict UX)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R110-A51 | Addons shows exclusive-slot conflicts (slot name + candidate packs) | ⬜ |
| 2 | R110-A52 | User can pick winner; choice persists across relaunch | ⬜ |
| 3 | R110-A53 | Clear override restores priority resolution | ⬜ |
| 4 | R110-A54 | Uninstall winner → next candidate or default; no dead open | ⬜ |
| 5 | R110-A55 | Feature doc: how layered packs compose + how to pick chrome | ⬜ |
| 6 | R110-A56 | Changelog bullet when conflict UI ships (user-facing) | ⬜ |

---

## Acceptance (reference packs)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R110-A57 | Example / official Pack A: hub browse + providers (no exclusive details chrome) | ⬜ |
| 2 | R110-A58 | Example / official Pack B: `details.layout` + `player.chrome` binds to surfaces | ⬜ |
| 3 | R110-A59 | Install A alone → stock foundation details/player | ⬜ |
| 4 | R110-A60 | Install A+B → B fills details/player slots; A still owns rails/open/meta | ⬜ |

---

## Summary

**One-liner:** Packs declare **what surfaces they fill**. Host merges by **slot**. Open identity stays on the **source** catalog plugin. UI stays foundation mounts — never “open a details pack.”

Today packs compose only as: extra hub tabs, cumulative providers, declared enrich companions, addon settings fields, unlock modules. They **cannot** layer a second pack’s details/player chrome onto an existing hub open.

This RFC adds a **contribution slot system** so community packs can split product ownership:

| Pack | Role |
|------|------|
| **A** | Hub browse + stream providers |
| **B** | Details layout + player chrome |

Install both → same open path, layered product.

---

## Problem

1. **Monolithic hub packs** — browse, details meta, and chrome expectations live in one pack (or host debt). Authors cannot ship “details skin” without forking Home/Anime.
2. **Enrich is data-only** — `"enrich": "…"` improves meta; it does not own details layout or player overlay.
3. **Open remapping is the wrong escape hatch** — pointing `open` at another pluginId breaks cache keys, list pin, extract boundary, and enrich pipe.
4. **One-off hooks proliferate** — Live chrome hooks, PackDetailsHost, addon settings, unlock modules are the same idea without a shared vocabulary.
5. **Community composition is weak** — users can install many providers; they cannot install a details/player UX pack that layers onto any hub.

---

## Goals

1. Fixed **slot catalog** packs can fill (exclusive or additive).
2. Manifest **`contributes[]`** with binds (`open.surface` / `types`) and priority.
3. **ContributionRegistry** in host — generic, no pack-id branches.
4. Foundation **mount points** for details + player chrome read the registry.
5. **Conflict UX** for exclusive slots in Addons.
6. Migrate existing mechanisms into the same vocabulary without breaking legacy manifests.
7. Prove composition with reference Pack A + Pack B.

---

## Non-goals

| Out | Why |
|-----|-----|
| Free hierarchy of arbitrary screens | Breaks TV focus, foundation, RFC-109 |
| Pack-shipped Dart/Flutter UI binaries | Host stays capability-only; foundation owns widgets |
| Remapping open to contribution pack | Breaks identity / cache / extract |
| Pack inventing new route surfaces without RFC | Surfaces stay host-owned names |
| Replacing stream provider cumulativity with exclusive “player pack” | Providers stay additive |
| Backlog / ship-semver coupling | Status lives in this RFC only |

---

## Capability matrix (plan past status quo)

| Surface family | Platform / library | Forja today | Plan target |
|----------------|-------------------|-------------|-------------|
| Hub browse | Pack layout JSON + MetaRuntime | Hub owns layout+details actions | Unchanged for browse; details chrome separable |
| Meta enrich | Companion plugin pipe | `"enrich"` on source plugin | Slot `meta.enrich` (legacy alias) |
| Details UI | Foundation details widgets | Host PackDetailsHost + hub meta | Exclusive `details.layout` + additive `details.sections` |
| Player chrome | Player overlay widgets | Host/player owned | Exclusive `player.chrome` + additive `player.actions` |
| Stream sources | Provider plugins | Cumulative providers | Additive `player.resolve` / sources (keep) |
| Addon settings | Manifest `settings` | RFC-089 | Slot `addons.settings` (alias) |
| Unlock modules | Pack files + `runUnlock` | RFC-099 | Slot `unlock.module` (alias) |
| Conflict UI | Settings | None | Addons exclusive-slot picker |

---

## Concepts

### Layers (ordered pipes on one open)

```text
1. source meta     (hub pluginId — identity)
2. meta.enrich     (optional companion / contribution)
3. details.layout  (optional exclusive chrome)
4. details.sections(optional additive)
5. play / resolve  (additive providers)
6. player.chrome   (optional exclusive overlay)
7. player.actions  (optional additive)
```

Layers are **ordered responsibilities**, not a tree of screens.

### Modules

Optional capability blobs inside a pack (unlock recipes, enrich entry, layout JSON). Modules **declare** which slot they fill via `contributes`.

### Slots

Named host mount contracts. Packs fill slots; host never special-cases pack ids.

### Hierarchy (only for conflict)

`user override > priority > install time > pluginId sort`. Not a screen tree.

---

## Slot catalog (normative v1)

| Slot | Mode | Payload | Owner of mount |
|------|------|---------|----------------|
| `shell.nav` | additive | `nav` block | Host shell (exists) |
| `shell.layout` | exclusive per tab | kit layout JSON | PackLayoutHost / foundation (exists) |
| `meta.source` | exclusive per open | `details`/`rail`/`feed` actions | Source catalog plugin (exists) |
| `meta.enrich` | exclusive* | enrich plugin id / action | MetaRuntime pipe (exists as `enrich`) |
| `details.layout` | exclusive | layout JSON path | PackDetailsHost → foundation |
| `details.sections` | additive | section ids / layout fragments | Foundation details body |
| `player.chrome` | exclusive | chrome layout / hook set | Player overlay mount |
| `player.actions` | additive | action ids | Player overlay |
| `player.resolve` | additive | provider plugins | Sources panel (exists) |
| `addons.settings` | additive | settings fields | Addons detail (RFC-089) |
| `unlock.module` | additive | pack files + recipes | unlock runner (RFC-099) |

\*Enrich is exclusive **per source plugin declaration** today (`"enrich": id`). v1 keeps that; later may allow additive enrich stages if needed (⏭️).

**Extension rule:** new slots require an RFC append (new `R110-A*` rows) + foundation mount. Packs must not invent slots that host ignores silently in production builds without debug log.

---

## Manifest contract

### `contributes[]` (plugin or pack root)

```json
{
  "id": "cinematic-chrome",
  "plugins": [
    {
      "id": "cinematic-details",
      "kind": "catalog",
      "capabilities": ["layout"],
      "contributes": [
        {
          "slot": "details.layout",
          "mode": "exclusive",
          "priority": 10,
          "binds": {
            "surfaces": ["tmdb", "anime", "drama", "arabic"],
            "types": ["movie", "tv", "anime"]
          },
          "layout": "details.json"
        },
        {
          "slot": "player.chrome",
          "mode": "exclusive",
          "priority": 10,
          "binds": {
            "surfaces": ["tmdb", "anime", "drama", "arabic"]
          },
          "chrome": "player_chrome.json"
        },
        {
          "slot": "details.sections",
          "mode": "additive",
          "priority": 10,
          "binds": { "surfaces": ["tmdb"] },
          "sections": ["cast", "trailers", "because"]
        }
      ]
    }
  ]
}
```

### Hub + providers pack (unchanged role)

```json
{
  "id": "forjahq-home",
  "plugins": [
    {
      "id": "tmdb",
      "capabilities": ["nav", "layout", "rail", "search", "details"],
      "contributes": [
        { "slot": "shell.nav", "mode": "additive" },
        { "slot": "shell.layout", "mode": "exclusive", "layout": "layout.json" },
        { "slot": "meta.source", "mode": "exclusive" }
      ]
    }
  ]
}
```

Providers continue as separate `kind: provider` plugins (additive resolve). Optional explicit:

```json
{ "slot": "player.resolve", "mode": "additive" }
```

### Legacy aliases (must keep working)

| Legacy field | Slot |
|--------------|------|
| `"enrich": "anime-enrich-tmdb"` | `meta.enrich` |
| `capabilities` includes `layout` + layout file | `shell.layout` |
| `settings.addon` + `fields` | `addons.settings` |
| Unlock `bundle` modules + recipes | `unlock.module` |

---

## Open identity law (non-negotiable)

```text
openMetaItem(pluginId = SOURCE hub, item)
  → MetaRuntime.run(details, SOURCE)
  → pipe meta.enrich (if any)
  → ContributionRegistry.resolve(details.*, bind from open/type)
  → PackDetailsHost mounts winning layout with SOURCE meta
  → play uses SOURCE + providers
  → ContributionRegistry.resolve(player.*, …)
```

**Forbidden:** remapping `pluginId` to the contribution pack so “details pack opens.”

**Allowed:** contribution pack also declares `meta.enrich` **bound** to surfaces — still keyed by source open, enrich plugin id separate.

---

## Resolve / merge algorithm

```text
candidates = installed+enabled contributions where slot matches AND binds match bindCtx
if userOverride[slot] in candidates → winner = that
else sort by (-priority, installTime, pluginId)
if mode == exclusive → take first
if mode == additive → take all in sort order
if empty → host/foundation default for that slot
```

**Bind context** (opaque, no pack allowlists in Dart):

- `open.surface` string (may be empty)
- `meta.type` / engine type tokens
- optional `kind` of source plugin

---

## Host / foundation / pack ownership

| Layer | Owns | Forbidden |
|-------|------|-----------|
| **Host** | ContributionRegistry, prefs overrides, thin mounts, pack install | Pack-id product branches, product screens |
| **Foundation** | Details/player widgets + layout runner for contribution payloads | Knowing which community pack won |
| **Pack** | `contributes` payloads (JSON layouts, section lists, enrich JS) | Dart UI injection, open identity theft |

Sniff test (RFC-109): if contribution pack is uninstalled, host Dart still makes sense — yes (defaults). If source hub is uninstalled, contribution chrome has nothing to bind to — open gone, chrome idle.

---

## Conflict UX (Addons)

When ≥2 exclusive contributions bind the same slot for overlapping surfaces:

1. Addons → Contributions (or under each Addon detail) lists **slot**, **candidates**, **active winner**.
2. User picks winner → stored override.
3. Clear → back to priority.
4. Uninstall winner → re-resolve; toast optional.

Without this UI, community packs will fight and users will blame “broken details.”

---

## Worked example

| Installed | Browse | Open identity | Details paint | Player chrome | Sources |
|-----------|--------|---------------|---------------|---------------|---------|
| A only | A layout | A `tmdb` | foundation default / A details meta | host default | A’s providers + others |
| A + B | A layout | A `tmdb` | B `details.layout` | B `player.chrome` | cumulative providers |
| B only | no Home tab from A | n/a | idle | idle | providers if B ships any |

B never appears as a nav tab unless it also contributes `shell.nav`.

---

## Slices (implementation order)

| Slice | IDs | Outcome |
|-------|-----|---------|
| **0 — Spec** | A01–A28 | This RFC + rule pointer + cross-links |
| **1 — Registry** | C01–C02, A29–A40 | Parse + resolve + legacy aliases; no UI change |
| **2 — Details slots** | C03, A41–A44, A48–A50 | `details.layout` / `sections` mount |
| **3 — Player slots** | C04, A45–A47 | `player.chrome` / `actions` mount |
| **4 — Conflict UX** | C05, A51–A56 | Addons picker + feature/changelog |
| **5 — Migrate one-offs** | C06 | Document enrich/settings/unlock as slots; thin code aliases |
| **6 — Reference packs** | C08, A57–A60 | Prove A+B composition |
| **7 — Gates** | C07 | Grep + synthetic host tests |

Do not schedule Slice 2+ until Slice 1 lands. Do not mark RFC `[fixed]` until A50 + A60 verified.

---

## Migration of existing one-offs

| Today | Target |
|-------|--------|
| `EnginePlugin.enrich` | `meta.enrich` contribution (auto-derived) |
| Hub `layout` capability | `shell.layout` |
| Live chrome hooks | eventually `player.chrome` / panel slots for live binds |
| RFC-089 settings | `addons.settings` |
| RFC-099 unlock files | `unlock.module` |
| Hardcoded PackDetailsHost sections | default when no `details.*` contribution |

No big-bang rewrite — aliases first, then packs opt into explicit `contributes`.

---

## Tests & gates

| Gate | Rule |
|------|------|
| Host tests | Synthetic plugin ids / slots only ([host tests rule](../../.cursor/rules/forja-host-tests-no-pack-contracts.mdc)) |
| Grep | No shipped hub ids in contribution resolver |
| Grep | No `openMetaItem` remap to contribution pluginId |
| Manual | A alone / A+B / B alone / uninstall B mid-session |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Exclusive slot wars | Conflict UX + overrides mandatory before community docs push |
| Layout JSON too weak for “player chrome” | Start with hook ids + known foundation chrome recipes; expand JSON carefully |
| Authors remap open anyway | Spec + grep gate + SDK “don’t” |
| Scope explosion into IPTV/Live | v1 = details + player + registry; live/IPTV bind later via A24 |

---

## Related

- [RFC-070](070-[partial]-catalog-hub-protocol.md) — catalog protocol + enrich companions
- [RFC-089](fixed/089-[fixed]-pack-addon-settings.md) — pack-contributed settings (alias target)
- [RFC-099](099-[open]-live-unlock-pack-modules.md) — unlock modules (alias target)
- [RFC-106](fixed/106-[fixed]-forja-foundation-design-system-package.md) — foundation mounts
- [RFC-109](109-[open]-forja-pack-product-host.md) — pack-product host law
- [RFC-020](020-[draft]-media-details-routing.md) · [RFC-026](026-[draft]-media-details-player-ux.md) — details UX history
- Cursor: [pack-product host](../../.cursor/rules/forja-pack-product-host.mdc) · [host tests](../../.cursor/rules/forja-host-tests-no-pack-contracts.mdc)
