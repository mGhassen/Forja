# Backlog

One file **per release version**. Specs live in [RFCs](../rfc/README.md); each file links RFCs, issues, and migration slices for that ship.

**Rules:** [docs-rfc-issues](../../.cursor/rules/docs-rfc-issues.mdc)

## Semver

| Level | Example | Codename? |
|-------|---------|-----------|
| Major era | v0, v1, v2 | **Theme** (Tunisia category) |
| Minor | `0.1.0`, `1.0.0` | **One codename** per minor open |
| Patch | `0.1.3`, `1.0.1`, `1.2.3` | **None** — ever |

**Codename applies to the minor only** (`1.2.0` → codename **Menzah**; `1.2.1` / `1.2.3` patches inherit it, no new name).

Filename = `{semver}-[{status}].md`. Tag matches `**Status:**` in the body.

```
plan     →  1.0.1-[draft].md  ·  1.0.2-[draft].md
shipping →  1.0.1-[open].md
shipped  →  done/1.0.0-[done].md
dropped  →  canceled/1.0.0-[canceled].md
```

Every file body: **RFCs** · **Issues** · **Migration** · **Shipped** sections.

Partial RFC slices and version slip: [Version ↔ RFC ↔ issue](../../.cursor/rules/docs-rfc-issues.mdc#version--rfc--issue-three-layers).

## Major themes

| Major | Theme | Era |
|-------|-------|-----|
| **v0** | Tell & land | Engine migration + foundation |
| **v1** | Souk & craft | Shell → details/player → TV → overlay/casting → v1 capstone |
| **v2** | Diwan & mer | Sync, LAN, watch party, cross-device |
| **v3** | Digital medina | Web client + WASM |
| **v4** | Ksour & horizon | TBD — post-web expansion |

## Codename runway

**Source of truth** for minor codenames. Format matches shipped backlog intros: `*Name* — tagline.`

**Voice** (read [Ichkeul](done/0.0.1-[done].md), [Halfaouine](done/0.7.0-[done].md)): **English taglines only.** Codenames = what Tunisians actually live — souk craft, home ritual, café habit, shared wall, louage seat — **not** cities, gates, beaches, ruins, or tour-loop landmarks. Halfaouine is the model: *behind the tour-loop medina.* Arc meaning stays buried. Patches inherit the minor.

App constant: [`kReleaseCodename`](../../apps/forja/lib/shared/services/app_version.dart) — name only.

### v1 — Souk & craft

| Minor | Codename | Tagline |
|-------|----------|---------|
| **1.0** ✅ | **Bab Souika** | Tunis medina gate and souk quarter; v1 opens with polished shell / Home hero. |
| **1.1** 🔄 | **Mratab** | Hide on the drying frame; stiff when you walk past, soft by Thursday. |
| **1.2** 🔄 | **Salon el-Khotla** | Wall bench faces the screen; nobody sits with their back to it. |
| **1.3** ⬜ | **R'ha el-Blat** | Mortar grinding blends you never smell from the main aisle. |
| **1.4** ⬜ | **Bej el-Qbab** | Two doors, one courtyard — each caravan swears theirs is faster. |
| **1.5** ⬜ | **Glaya** | Bent dish on the roof; half the alley catches the same beam. |
| **1.6** ⬜ | **Keskes** | Top basket empty after Friday couscous; stack before next week. |
| **1.7** ⬜ | **Jeb el-Khotla** | Phone in the bench corner; shade on the packed tram. |
| **1.8** ⬜ | **Qaleb** | Plaster mold still wet with the last palm print. |
| **1.9** ⬜ | **Msarra** | Dye runoff in the gutter; rinse until the water runs clean. |
| **1.10** ⬜ | **Ghlaka** | Metal shutter rolling down; last light on the lane. |

### v2 — Diwan & mer

| Minor | Codename | Tagline |
|-------|----------|---------|
| **2.0** ⬜ | **Diwan el-Bait** | Household ledger copied when someone marries out. |
| **2.1** ⬜ | **Qafqafa** | Knock on the shared wall; neighbor knows which rhythm. |
| **2.2** ⬜ | **Mnajra** | Same well rope for every door; bucket echo in the shaft. |
| **2.3** ⬜ | **Naql** | Hand-copy of the chief's stamp on plain paper. |
| **2.4** ⬜ | **Zira** | Neighbor who keeps your spare key and changes the channel. |
| **2.5** ⬜ | **Louage** | Eight seats, one route; you don't pick the music. |
| **2.6** ⬜ | **Mdakhla** | Houses share a wall and the same courtyard argument. |
| **2.7** ⬜ | **Maalma** | She sets the track; the room claps on her beat. |
| **2.8** ⬜ | **Hrza** | Tea tin locked before the road gets hot. |
| **2.9** ⬜ | **Bil Ma** | Cash in the palm; no card, no name on the line. |
| **2.10** ⬜ | **Korsi** | Plastic chairs ring one small café screen after dark. |

### v3 — Digital medina

| Minor | Codename | Tagline |
|-------|----------|---------|
| **3.0** ⬜ | **El-Grill** | Shutter half down; regulars still buy through the bars. |
| **3.1** ⬜ | **Mleha** | Salt in the sack; same crystals, no hoofprints. |
| **3.2** ⬜ | **Rkhif** | Hard biscuit in the tin; good when the oven's cold. |
| **3.3** ⬜ | **Rih el-Dar** | Draft under the door; nobody asked who let it in. |
| **3.4** ⬜ | **Zapta** | Thumb worn smooth hopping channels before reading names. |
| **3.5** ⬜ | **Meraya** | Numbers in the glass; the book stays shut. |
| **3.6** ⬜ | **Tekna** | Pit-room ceiling taken off; sky where plaster was. |
| **3.7** ⬜ | **Mekhzan** | Stash in the ceiling niche; not priced on the counter. |
| **3.8** ⬜ | **Safha el-Akhira** | Last notebook page before the blank desert. |

### v4 — Ksour & horizon

| Minor | Codename | Tagline |
|-------|----------|---------|
| **4.0** ⬜ | **Hbila** | First blue tile on the wall; room not measured yet. |
| **4.1** ⬜ | **Mlaha** | Crystals after the water left; shape still unnamed. |
| **4.2** ⬜ | **Remel** | Dune spine where the wind changes its mind. |
| **4.3** ⬜ | **Sawt el-Barr** | Whistle from the cliff; answer from the far side. |
| **4.4** ⬜ | **Zit el-Arbi** | Cedar shade at the turnoff with no sign. |
| **4.5** ⬜ | **Akher Tel** | Last hill before the map goes blank. |

## Active

| File | Minor | Codename | Status |
|------|-------|----------|--------|
| [1.0.1-[open].md](1.0.1-[open].md) | 1.1 patch train | Mratab | open — details & player UX (10/19 shipped) |
| [1.0.2-[draft].md](1.0.2-[draft].md) | 1.3 patch train (pre-rename) | R'ha el-Blat | draft — overlay, providers, casting (1/10) |
| `feat/android-tv` | **1.2** minor | Salon el-Khotla | shipping — leanback + D-pad (no backlog file yet) |

## Done — v1

| Version | Codename | RFCs | Issues | Migration |
|---------|----------|------|--------|-----------|
| [1.0.0](done/1.0.0-[done].md) | Bab Souika | 025 | — | — |

## Done — v0 master index

| Version | Codename | RFCs | Issues | Migration |
|---------|----------|------|--------|-----------|
| [0.0.1](done/0.0.1-[done].md) | Ichkeul | 001, 011, 002, 004†, 015†, 003† | — | — |
| [0.1.0](done/0.1.0-[done].md) | Zaghouan | 009† | — | 01† |
| [0.1.1](done/0.1.1-[done].md) | — | 009† | — | 01† |
| [0.1.2](done/0.1.2-[done].md) | — | 009† | — | 01† |
| [0.1.3](done/0.1.3-[done].md) | — | 009† | — | 01 |
| [0.1.4](done/0.1.4-[done].md) | — | 009† | — | 01 |
| [0.1.5](done/0.1.5-[done].md) | — | 009† | — | 01 |
| [0.1.6](done/0.1.6-[done].md) | — | 009† | — | 01 |
| [0.1.7](done/0.1.7-[done].md) | — | 009 | — | 01 ✅ |
| [0.2.0](done/0.2.0-[done].md) | El Haïdra | 009† | 003 | 02† |
| [0.2.1](done/0.2.1-[done].md) | — | 009† | — | 02 ✅ |
| [0.3.0](done/0.3.0-[done].md) | Kerkennah | 009† | — | 03† |
| [0.3.1](done/0.3.1-[done].md) | — | 009† | — | 03† |
| [0.3.2](done/0.3.2-[done].md) | — | — | 023 | 03† |
| [0.3.3](done/0.3.3-[done].md) | — | 009† | — | 03 ✅ |
| [0.4.0](done/0.4.0-[done].md) | Ressas | 009† | 016 | — |
| [0.4.1](done/0.4.1-[done].md) | — | — | 004 | — |
| [0.4.2](done/0.4.2-[done].md) | — | — | 001, 005, 006 | — |
| [0.4.3](done/0.4.3-[done].md) | — | — | 007, 010, 011 | — |
| [0.4.4](done/0.4.4-[done].md) | — | — | 009, 008, 015 | — |
| [0.4.5](done/0.4.5-[done].md) | — | — | 014, 017, 012, 013 | — |
| [0.5.0](done/0.5.0-[done].md) | Tamerza | 017†, 018† | — | — |
| [0.5.1](done/0.5.1-[done].md) | — | 016†, 018† | — | — |
| [0.6.0](done/0.6.0-[done].md) | Degache | 009† | — | — |
| [0.6.1](done/0.6.1-[done].md) | — | 009† | — | — |
| [0.6.2](done/0.6.2-[done].md) | — | 009† | — | — |
| [0.6.3](done/0.6.3-[done].md) | — | 015† | — | — |
| [0.7.0](done/0.7.0-[done].md) | Halfaouine | — | — | index |
| [0.8.0](done/0.8.0-[done].md) | Sidi Bou Said | 023† | — | — |
| [0.8.1](done/0.8.1-[done].md) | — | 023† | — | — |
| [0.8.2](done/0.8.2-[done].md) | — | 016†, 024 | — | — |

† = slice only; RFC/issue may stay `[partial]` or `[draft]` until fully done.

## Canceled

[canceled/](canceled/) — versions dropped (note why in the file body).

## Related

- [RFC index](../rfc/README.md)
- [Issues](../issues/README.md)
- [Migration](../migration/README.md)
