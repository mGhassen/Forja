# Backlog

One file **per release version**. Specs live in [RFCs](../rfc/README.md); each file links RFCs, issues, and migration slices for that ship.

**Rules:** [docs-rfc-issues](../../.cursor/rules/docs-rfc-issues.mdc)

## Semver

| Level | Example | Codename? |
|-------|---------|-----------|
| Major era | v0, v1, v2 | **Theme** (Tunisia category) |
| Minor | `0.1.0`, `1.0.0` | **One codename** per minor open |
| Patch | `0.1.3`, `1.0.1`, `1.2.3` | **None** — ever |

**Codename applies to the minor only** (`1.2.0` → **Dabaghin**; `1.2.3` inherits it). Patch backlog files (`1.0.1`, `1.0.2`) are ship checklists under **1.0.x** — still **Bab Souika**, no new codename.

[`kReleaseCodename`](../../apps/forja/lib/shared/services/app_version.dart) tracks **app semver minor** (today **1.2 → Dabaghin**), not the patch backlog filename.

Filename = `{semver}-[{status}].md`. Tag matches `**Status:**` in the body.

```
plan     →  1.0.1-[draft].md  ·  1.0.2-[draft].md
shipping →  1.0.1-[open].md
shipped  →  done/1.0.0-[done].md
dropped  →  canceled/1.0.0-[canceled].md
```

Every file body: **RFCs** · **Issues** · **Migration** · **Shipped** sections.

Backlog file title: `# X.Y.Z — {Codename}` — codename from [runway](#codename-runway) for the app **minor** (patch files under 1.0.x → **Bab Souika**). No `**Major:**` / `**Arc:**` lines in backlog bodies.

Partial RFC slices and version slip: [Version ↔ RFC ↔ issue](../../.cursor/rules/docs-rfc-issues.mdc#version--rfc--issue-three-layers).

## Major themes

| Major | Theme | Era |
|-------|-------|-----|
| **v0** | Tell & land | Engine migration + foundation |
| **v1** | Souk | Shell → details/player → TV → overlay/casting |
| **v2** | Diwan | Sync, LAN, watch party, cross-device |
| **v3** | Ink & stone | Web client + WASM |
| **v4** | Ksour | Post-web expansion |

## Codename runway

**Source of truth** for minor codenames. v1 = medina souk quarters; v2 = Diwan; v3–v4 = history. Patches (`X.Y.Z`, `Z > 0`) inherit the minor — no new name. Full runway below; [`kReleaseCodename`](../../apps/forja/lib/shared/services/app_version.dart) must match the **shipping minor**.

### v1 — Souk

| Minor | Codename | 
|-------|----------|
| **1.0** ✅ | **Bab Souika** | 
| **1.1** 🔄 | **Mrabet** | 
| **1.2** 🔄 | **Dabaghin** | 
| **1.3** ⬜ | **Elblat** | 
| **1.4** ⬜ | **Atarin** | 
| **1.5** ⬜ | **Berka** | 

### v2 — Diwan

| Minor | Codename | 
|-------|----------|
| **2.0** ⬜ | **Diwan** | 
| **2.1** ⬜ | **Qoffa** | 
| **2.2** ⬜ | **Chachia** | 
| **2.3** ⬜ | **Herz** | 
| **2.4** ⬜ | **Midha** |  
| **2.5** ⬜ | **Mekhzan** |

### v3 — Ink & stone

| Minor | Codename | 
|-------|----------|
| **3.0** ⬜ | **Muqaddimah** | 
| **3.1** ⬜ | **Capsa** | 
| **3.2** ⬜ | **Kahina** | 
| **3.3** ⬜ | **Uthina** | 
| **3.4** ⬜ | **Tanit** | 
| **3.5** ⬜ | **Magon** |

### v4 — Ksour

| Minor | Codename | 
|-------|----------|
| **4.0** ⬜ | **Chambi** | 
| **4.1** ⬜ | **Sened** | 
| **4.2** ⬜ | **Sbeitla** | 
| **4.3** ⬜ | **Jugurtha** | 
| **4.4** ⬜ | **Jerid** | 
| **4.5** ⬜ | **Borma** |

## Active

| File / source | App semver | Codename | Status |
|---------------|------------|----------|--------|
| [1.0.1-[open].md](1.0.1-[open].md) | 1.0.x patch checklist | Bab Souika | open — details & player UX (72/83 shipped) |
| [1.0.2-[draft].md](1.0.2-[draft].md) | 1.0.x patch checklist | Bab Souika | draft — overlay, providers, casting, settings UX, passkeys (17/28) |
| [1.0.3-[draft].md](1.0.3-[draft].md) | 1.0.x patch checklist | Bab Souika | draft — Resolver Engine (5/8) |
| [1.0.4-[draft].md](1.0.4-[draft].md) | 1.0.x patch checklist | Bab Souika | draft — web portal + desktop account/profile shell + i18n (18/23; hosted secrets + Edge/Turnstile/recovery ops; RFC-037) |
| `apps/forja` (`feat/android-tv`) | **1.2.x** | **Dabaghin** | shipping — leanback + D-pad |

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

- [Architecture](../architecture/README.md) — [feature file map](../architecture/feature-file-map.md)
- [RFC index](../rfc/README.md)
- [Issues](../issues/README.md)
- [Migration](../migration/README.md)
