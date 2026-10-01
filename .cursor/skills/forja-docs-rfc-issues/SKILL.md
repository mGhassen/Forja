---
name: forja-docs-rfc-issues
description: >-
  RFC, issue, migration, and feature user-guide lifecycle for Forja.
  Progress trackers, status filename tags, append-only task tables, same-turn
  doc updates after code. Use when creating or editing docs under docs/rfc,
  docs/issues, docs/migration, docs/features; renaming status tags; filing
  substantial work before coding; or when the user mentions RFC, issue, or
  feature docs.
---

# RFC, issue, and feature doc management

Indexes: [RFC](../../../docs/rfc/README.md) · [issues](../../../docs/issues/README.md) · [features](../../../docs/features/README.md)

Always-on law stub: [docs-rfc-issues.mdc](../../rules/docs-rfc-issues.mdc)

## Golden rule

**Every doc has a status tag in the filename. Tag must match `**Status:**` in the body.**

Update the folder README index and grep cross-links in the same turn as any rename.

---

## Backlog (`docs/backlog/`) — disabled

Do **not** create, update, rename, close, schedule, or git-tag from `docs/backlog/`. Those files do **not** follow live app versions.

**Versions live in:** `pubspec` / `kReleaseCodename` · `docs/changelog/` · git tags from the release workflow.

**Do not:**

- Flip `B*-S*` rows or treat a backlog semver as a ship target
- Wire RFCs/issues into a backlog version file
- Add `**Target version:**` or backlog links to RFC/issue bodies
- Close a backlog file and tag `vX.Y.Z` from it
- Update backlog README **Active** / **Backlog** columns as part of normal work

Leave `docs/backlog/` alone unless the user explicitly asks to edit it.

---

## Progress tracker format (mandatory — RFC / issue / migration)

**Same visual language as migration phases.** Migration [Phase 2](../../../docs/migration/fixed/02-[fixed]-rust-engine-complete.md) is the canonical reference.

### Legend (required line immediately after glance table)

```markdown
**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)
```

Issues omit ⏭️ unless deferred work exists.

### Task table shape (required)

```markdown
---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R23-C01 | Short description | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R23-A01 | Short description | ⬜ |
```

Use `---` before and after each task section block.

### Status column — only these emojis

| Emoji | Meaning |
|-------|---------|
| ✅ | Done / shipped / verified in code |
| 🔄 | Actively in progress (partial implementation) |
| ⬜ | Not started or not verified (incl. manual QA not run) |
| ⏭️ | Explicitly deferred to a later slice |

**Forbidden in task tables:** `Shipped`, `Stub`, `done`, `- [x]`, `- [ ]`.

### ID prefixes

| Layer | Components | Acceptance / tasks |
|-------|------------|--------------------|
| RFC NNN | `R{nnn}-C{nn}` | `R{nnn}-A{nn}` |
| Issue NNN | `I{nnn}-T{nn}` (fix tasks) | `I{nnn}-A{nn}` |
| Migration | `P{n}-XX` (existing) | same |

Zero-pad RFC/issue numbers: RFC-023 → `R23-`, issue 002 → `I02-`.

### Status at a glance — required

Do **not** put ship semver in RFC/issue bodies. Implementation state only.

**RFC** (reference: [RFC-023](../../../docs/rfc/fixed/023-[fixed]-app-shell-redesign.md)):

```markdown
## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **10 / 14** acceptance (desktop slice) · **0 / 1** mobile deferred |
| **Current slice** | Desktop shipped — mobile bottom nav not started |
```

**Issue** (reference: [018](../../../docs/issues/018-[draft]-migration-playback-parity-unverified.md)):

```markdown
## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 13** verification |
```

**Forbidden in RFC/issue bodies:** `**Target version:**`, `**Backlog**` row in glance, links to backlog files.

### Progress counts

- Count ✅ / 🔄 / ⬜ / ⏭️ rows in task tables for the **current slice**
- **Glance `Progress` must match the tables** — never hand-waved aggregates
- Multiple slices: `**7 / 7** acceptance (v1.0) · **0 / 7** acceptance (v1.1 slice)`
- **`[fixed]` RFC:** `**Complete**` or `**Complete · 20/21** · 1 ⏭️ WASM`
- **`[draft]` spec-only:** all acceptance rows ⬜ → `0 / N`
- **Meta RFCs** (012, 013, 014): bundle acceptance table; may cite child RFC counts in **Current slice**

**One source of truth:** emoji task tables. No parallel checkbox lists.

When any row changes: update RFC/issue glance **Progress** (and **Current slice** when relevant) **and** folder README **Progress** column in the **same turn**.

### RFC / issue task history — append-only (mandatory)

Task rows are **historical records**. Never rewrite or delete them.

| Rule | Detail |
|------|--------|
| **Never delete rows** | Do not remove acceptance/component/task table lines to “simplify” an RFC. |
| **Never rewrite body** | Do not replace the whole RFC with a shorter summary. **Append** new sections/slices below existing content. |
| **Frozen statuses** | Rows marked **🔄 in progress** or **✅ done** must **keep that status forever**. Do not revert to ⬜ or change the description. |
| **New work → new rows** | New slices get **new IDs** (`R16-A06`, `R24-A01`, …) or a **child RFC**. Do not renumber existing IDs. |
| **New RFC instead of erase** | If scope diverges, add a new RFC — do not overwrite the old one. |

---

## RFCs (`docs/rfc/`)

### Filename tags

`[draft]` · `[planned]` · `[open]` · `[partial]` · `[fixed]` (in `fixed/`) · `[canceled]` (in `canceled/`)

| Body status | Filename tag | Location |
|-------------|--------------|----------|
| `draft` | `[draft]` | Spec exists; not scheduled |
| `planned` | `[planned]` | You explicitly scheduled it |
| `open` | `[open]` | Actively in progress |
| `partial` / `stub` | `[partial]` | Code started, not shippable |
| `fixed` | `[fixed]` | `docs/rfc/fixed/` |
| `canceled` | `[canceled]` | `docs/rfc/canceled/` — will not build |

### Mandatory RFC body section order

After `#` title + metadata block:

**Metadata — allowed fields only:** `**Status:**`, `**Depends on:**`, `**Area:**`. Optional product-era `**Version:**` (not ship semver).

1. **`## Status at a glance`** — **Progress** + **Current slice** only
2. **`**Legend:**`**
3. **`## Components`** — when buildable pieces exist
4. **`## Acceptance (slice)`** — name slices by work batch, not version number
5. **`## Summary`** — then Goals / Problem / Contracts / Related

**Reference:** [RFC-023](../../../docs/rfc/fixed/023-[fixed]-app-shell-redesign.md)

---

## Issues (`docs/issues/`)

### Filename tags

| Body status | Filename tag | Location |
|-------------|--------------|----------|
| `draft` | `[draft]` | Filed, not being worked |
| `open` | `[open]` | Actively fixing |
| `workaround` | `[workaround]` | Symptom fix only |
| `fixed` | `[fixed]` | `docs/issues/fixed/` |
| `canceled` | `[canceled]` | `docs/issues/canceled/` |

Workaround requires user permission per [honesty-and-completion.mdc](../../rules/honesty-and-completion.mdc).

### Mandatory issue body section order

After metadata (`**Status:**`, `**Priority:**`, `**Severity:**`, `**Area:**` — no `**Target version:**`):

1. **`## Status at a glance`** — **Progress** only
2. **`**Legend:**`**
3. **`## Acceptance`** / **`## Fix tasks`** — emoji tables (`I*-A*`, `I*-T*`)
4. **`## Summary`**, root cause, related links

Update [issues README](../../../docs/issues/README.md) **Progress** when rows change.

---

## Feature user guides (`docs/features/`)

User-facing docs — how the app works today. Not progress trackers.

Index: [features/README.md](../../../docs/features/README.md) · Template: [TEMPLATE.md](../../../docs/features/TEMPLATE.md)

### When to update (mandatory — same turn as code)

| Code change | Update |
|-------------|--------|
| Nav tab added/removed/renamed, shell chrome | [navigation.md](../../../docs/features/getting-started/navigation.md) · [navigation-bar.md](../../../docs/features/settings/navigation-bar.md) |
| Settings screen toggle/section/label | Matching `docs/features/settings/*.md` |
| Player controls, PiP, subtitles, speed | Matching `docs/features/playback/*.md` |
| Scraper/source/provider UX | `docs/features/scrapers/*` · `docs/features/sources/*` |
| Tab feature UX | Matching `docs/features/**/<name>.md` |
| Platform limits | Affected feature doc + [platforms.md](../../../docs/features/getting-started/platforms.md) |
| Feature ships / removed | Move in/out of `coming-soon/`; update features README |

**Read the code or run the UI before editing.** Code is source of truth.

### New or renamed features

1. Create/rename from [TEMPLATE.md](../../../docs/features/TEMPLATE.md)
2. Link in features README (+ **I want to…** if user-facing)
3. Grep old slug under `docs/features/` and fix links

---

## RFC ↔ issue

| Layer | Owns | When status changes |
|-------|------|---------------------|
| **RFC** | Feature spec + full acceptance | Same file — when implementation state changes |
| **Issue** | Bug, debt, verifiable sub-work | Same file — `[fixed]` or `[canceled]` when done |

Ship version is **changelog + git tag**, not RFC/issue filenames.

### Scope big work before coding

Substantial work → create or extend docs first, then implement.

| Kind | Create | Examples |
|------|--------|----------|
| **RFC** | `docs/rfc/NNN-[draft\|planned\|open\|partial]-….md` | New subsystem, multi-component architecture |
| **Issue** | `docs/issues/NNN-[draft\|open]-….md` | Concrete bug, engine debt, test gap |
| **Extend existing** | Add rows to existing tables | Fits RFC-023 → `R23-A*` — do not clone a new number |

**Same turn when creating:**

1. Grep highest NNN; use NNN+1
2. Full format (glance, legend, emoji tables)
3. Update RFC/issues README **Progress**
4. No `**Target version:**` or backlog links

Small ask inside an existing slice → extend that table only.

Do **not** wait for “create the RFC” — if big and untracked, file it same turn as (or before) implementation.

### Partial RFC — do not split

One RFC per feature; slices inside. Stays `[partial]` until **all** acceptance ✅ → then `[fixed]`. Do not `[fixed]` because one slice shipped.

| Situation | Action |
|-----------|--------|
| Same feature, shipped in chunks | One RFC — slices inside |
| Different subsystem | Separate RFCs |
| Release theme / milestone index | Meta RFC linking children |
| Concrete bug / debt | Child issue |

Do not invent IDs outside the prefixes above. Migration `P2-XX` stays in migration docs only.

---

## On status change

1. Rename file (tag + move to `fixed/` / `canceled/` when terminal)
2. Update `**Status:**` in body
3. Update folder README index
4. Grep old path in `docs/` and fix links

## After code changes (mandatory — same turn)

When you land or materially advance work tied to an RFC, issue, or **user-visible feature**:

1. **RFC** — flip `R*-C*` / `R*-A*`; glance Progress / Current slice; Status if terminal
2. **Issue** — flip `I*-A*` / `I*-T*`; glance Progress; filename tag if terminal
3. **Feature user guide** — match live UI
4. **Changelog** — active draft; see skill [forja-changelog](../forja-changelog/SKILL.md)
5. **Indexes** — RFC / issues / features README as needed
6. **Cross-links** — grep old slug under `docs/`

**Forbidden:** code shipped with rows still ⬜; aggregate-only glance; checkbox lists parallel to emoji tables; feature docs describing dead UI.

Skip RFC/issue only for pure refactor/typo/tooling. Still update feature docs + changelog if user-visible. **Never** update `docs/backlog/` as part of this checklist.

| Folder | Terminal folders | Terminal statuses |
|--------|------------------|-------------------|
| `rfc/` | `fixed/` · `canceled/` | `fixed` · `canceled` |
| `issues/` | `fixed/` · `canceled/` | `fixed` · `canceled` |
| `migration/` | `fixed/` · `canceled/` | `fixed` · `canceled` |

## Migration (`docs/migration/`)

Phases `01`–`03`, not RFCs. Same progress tracker format.

Pattern: `NN-[{status}]-slug.md`

| Body status | Filename | Location |
|-------------|----------|----------|
| `draft` | `NN-[draft]-….md` | Not started |
| `open` | `NN-[open]-….md` | Actively migrating |
| `partial` | `NN-[partial]-….md` | In progress |
| `fixed` | `NN-[fixed]-….md` | `docs/migration/fixed/` |
| `canceled` | `NN-[canceled]-….md` | `docs/migration/canceled/` |

All current phases (1–3) are **`fixed`**. Index: [migration/README.md](../../../docs/migration/README.md).
