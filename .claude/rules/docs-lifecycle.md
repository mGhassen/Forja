---
paths:
  - "docs/**"
---

# Docs lifecycle

Skills: `forja-docs-rfc-issues` (RFC / issue / migration / feature guides) and `forja-changelog` (release notes). Laws: `.cursor/rules/docs-rfc-issues.mdc`, `changelog.mdc`, `user-facing-copy-truth.mdc`.

- Filename tag `NNN-[status]-slug.md` must equal `**Status:**` in the body. Rename + body + folder README row + cross-links in the same turn. `[fixed]` lives in `fixed/`, `[canceled]` in `canceled/`. The `post-edit` hook blocks mismatches.
- Task tables are append-only. New work → new row IDs. No `**Target version:**` or backlog links in RFC/issue bodies.
- `docs/backlog/` is frozen; `docs/changelog/done/` is frozen.
- Changelog bullets: `- **Add:** | **Change:** | **Fix:** | **Remove:**`, one of six groups (Features · Player · UI · Sources · Live & IPTV · TV), no paths / IDs / crate names. Active drafts: `docs/changelog/*-[draft].md` (currently 2.0.x and 1.5.x).
- `docs/features/**` is the user guide: describe what the product does now.
