# Backlog

One file **per release version**. Specs live in [RFCs](../rfc/README.md); each file links RFCs, issues, and migration slices for that ship.

**Rules:** [docs-rfc-issues](../../.cursor/rules/docs-rfc-issues.mdc)

## Semver

| Level | Example | Codename? |
|-------|---------|-----------|
| Major era | v0, v1, v2 | **Theme** (Tunisia category) |
| Minor | `0.1.0`, `1.0.0` | **One codename** per minor open |
| Patch | `0.1.3`, `1.0.1` | **None** |

Filename = `{semver}-[{status}].md`. Tag matches `**Status:**` in the body.

```
plan     →  1.0.0-[draft].md
shipping →  1.0.0-[open].md
shipped  →  done/1.0.0-[done].md
dropped  →  canceled/1.0.0-[canceled].md
```

Every file body: **RFCs** · **Issues** · **Migration** · **Shipped** sections.

Partial RFC slices and version slip: [Version ↔ RFC ↔ issue](../../.cursor/rules/docs-rfc-issues.mdc#version--rfc--issue-three-layers).

## Major themes

| Major | Theme | Era |
|-------|-------|-----|
| **v0** | Tell & land | Engine migration + foundation |
| **v1** | Souk & métier | Player overlay, casting, providers |
| **v2** | Diwan & mer | Sync, LAN, watch party |
| **v3** | TBD | Web client |

## Active

| File | Codename | Status |
|------|----------|--------|
| [0.8.1-[open].md](0.8.1-[open].md) | — | open |

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

† = slice only; RFC/issue may stay `[partial]` or `[draft]` until fully done.

## Canceled

[canceled/](canceled/) — versions dropped (note why in the file body).

## Related

- [RFC index](../rfc/README.md)
- [Issues](../issues/README.md)
- [Migration](../migration/README.md)
