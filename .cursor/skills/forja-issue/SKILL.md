---
name: forja-issue
description: >-
  File a new Forja issue the way the repo expects: next NNN id, status tag in
  filename and body, status-at-a-glance table, append-only fix and acceptance
  task tables, README index row, cross-links. Use before starting substantial
  untracked work, when a bug is found but not fixed now, or when the user says
  file an issue, track this, open a ticket.
argument-hint: "<short title> [--open]"
---

# /forja-issue $ARGUMENTS

Highest existing issue id (new id = this + 1, zero-padded to 3 digits):

!`ls docs/issues docs/issues/fixed docs/issues/canceled 2>/dev/null | grep -oE '^[0-9]{3}' | sort -n | tail -1`

Read `docs/issues/README.md` for the tag table and the index row format. Skill `forja-docs-rfc-issues` has the full lifecycle.

## Status

`[draft]` = filed, not being worked (default). `[open]` = you start fixing in this turn (`--open`). Never `[fixed]` while a root cause remains; symptom-only → `[workaround]` plus a linked `[open]` root issue.

## File `docs/issues/NNN-[draft]-<kebab-slug>.md`

```markdown
# NNN — <Title>

**Status:** draft  
**Priority:** P1 | P2 | P3  
**Severity:** High | Medium | Low  
**Area:** <platform · surface · subsystem>  
**Reported:** <YYYY-MM-DD> (<how it was observed>)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / N** fix · **0 / M** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

<what the user sees, device/platform, repro steps>

## Root cause (hypothesis until verified in code)

<path:line evidence, or "unverified">

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | INNN-T01 | … | ⬜ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | INNN-A01 | … | ⬜ |

## Links

- RFC / related issues
```

Rules: no `**Target version:**`, no backlog links, no file paths in anything users read (this file is dev-facing, paths are fine here). Task rows are append-only once written.

## Same turn

1. Add the row to the table in `docs/issues/README.md` (File · Title · P · Sev · Status · Progress · Backlog `—`).
2. Cross-link from the related RFC or issue if one exists.
3. If `--open`: filename `[open]`, body `**Status:** open`, README row `open`.

Return the file path and the README row you added.
