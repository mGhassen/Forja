---
name: forja-user-facing-copy
description: >-
  User-facing product copy must match current truth — no migration notes,
  architecture lectures, or “formerly / only” history in manifests, UI strings,
  or feature docs. Use when editing manifest name/description/nav.label,
  settings labels, toasts, pack catalog blurbs, docs/features, or changelog
  wording users read.
---

# User-facing copy = current product truth (detail)

Always-on stub: [user-facing-copy-truth.mdc](../../rules/user-facing-copy-truth.mdc)

Strings users see must describe **what the product does now**. Not what you changed. Not how packs are split. Not a changelog in a `description` field.

## Surfaces

| Surface | Examples |
|--------|----------|
| Plugin / pack | `manifest.json` `name`, `description`, `nav.label` |
| App UI | settings labels, empty states, toasts, dialogs, tooltips |
| Catalog / portal | plugin catalog blurbs, install prompts, pack cards |
| Docs users read | `docs/features/**`, changelog bullets |

Dev notes belong in RFCs, issues, commit messages, PR bodies — **never** in those surfaces.

## Forbidden patterns

| Bad pattern | Why |
|-------------|-----|
| Migration / split notes | `"Larozaa only (Brstej / كرتون are separate packs)"` |
| “Only / no longer / removed / formerly” | Documents history, not the product |
| Architecture lectures | `"host-owned"`, `"kit protocol"`, `"companion enrich"`, `"separate packs"` |
| Implementation leftovers | Old provider names still listed after code dropped them |
| Fake completeness | Listing sources/features the pack no longer ships |
| Contrastive product copy | `"Not X — Y"` pitched at end users |

```
❌ "Arabic hub — Larozaa only (Brstej / كرتون are separate packs)."
✅ "Larozaa Arabic movies and TV hub."

❌ "Live sports hub — schedule browse and stream resolve via host live kit."
✅ "Live sports schedule and streams."
```

(Match peer packs: short, what it is, optional upstream name if that *is* the product.)

## Mandatory when behavior changes

If you remove a provider, source, setting, or capability:

1. **Read** the live UI / manifest / feature doc — do not trust memory.
2. **Rewrite** every user-facing string that still mentions the old thing.
3. **Grep** the changed ids/names in `plugins/**`, `apps/forja/**`, `apps/web/**`, `docs/features/**`, changelog.
4. Leave **zero** “we used to / now only / see other pack” residue in product copy.

Stale copy that contradicts the code is a **lie to the user**. Treat it like a bug.

## Allowed elsewhere

- Commit / PR: “split Brstej into aflem pack”
- RFC / issue: architecture and migration notes
- Code comments: why a path exists (sparingly)

## Sniff test

Would a normal user care about this sentence? If it only helps a developer understand a refactor, delete it from the product string.
