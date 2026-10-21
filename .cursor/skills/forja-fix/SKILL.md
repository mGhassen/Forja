---
name: forja-fix
description: >-
  End-to-end bug-fix pipeline for Forja: scope gate, locate, classify symptom
  vs root vs workaround, track in docs/issues, implement, verify, law review,
  docs same turn, honest report. Use when the user says fix, bug, crash, ANR,
  broken, regression, or names an issue number.
argument-hint: "<issue number | short bug description>"
---

# /forja-fix $ARGUMENTS

Issue files matching the argument (if a number was given):

!`n="$(grep -oE '^[0-9]+' <<<"$ARGUMENTS" | head -1)"; [ -n "$n" ] && ls docs/issues/*"$n"-* docs/issues/*/*"$n"-* 2>/dev/null || echo "(no number given)"`

## Pipeline

Each phase has a gate. Do not skip a gate to move faster.

### 0 · Scope gate
In-scope tabs: Search, Home, Anime, Asian Drama, IPTV, Live Sports, Lists, Settings, plus shared player/shell/sources they use (`forja-feature-scope.mdc`). Out of scope (Amri, books, music, manga, Jellyfin, downloader, magnet…) → stop and ask unless the user expanded scope.

### 1 · Locate (subagent `forja-scout`)
Ask for: where the behavior lives, layer verdict, existing issue/RFC, tests covering it. If the layer verdict is **pack**, the fix belongs in the `forja-packs` repo; report that and stop unless a generic host capability is also missing.

### 2 · Classify before touching code
Write one line each: **symptom**, **root cause (path:line)**, **fix layer** (symptom / root / workaround).
- Root fix possible → do it.
- Only a symptom fix or workaround is feasible → **ask the user first** with: symptom fix, root fix, why the workaround, what the user loses (`honesty-and-completion.mdc`).
- The only "fix" you see hides, disables, or force-defaults a user-facing option → **stop and ask** (`no-hide-as-fix.mdc`). Never ship that.

### 3 · Track
If the issue exists: flip to `NNN-[open]-…` (filename + `**Status:** open` + README row) in this turn. If none exists and the work is substantial: `/forja-issue <title>` first.

### 4 · Implement
Dart → `forja-flutter-engineer`; Rust → `forja-rust-engineer`; web → `forja-web-engineer`; or do it yourself for a small change after reading the `.cursor/rules/*.mdc` the path rules point at. Keep user-facing surface area identical unless the user said otherwise.

### 5 · Verify
`/forja-verify` (or `forja-qa`). A failure you cannot attribute to pre-existing baseline blocks the report.

### 6 · Law review (subagent `forja-law-reviewer`)
Fix every **block** and **fix** finding, rerun step 5 for touched files.

### 7 · Docs, same turn (subagent `forja-docs-keeper` or yourself)
- Changelog bullet in the active `docs/changelog/X.Y.x-[draft].md` if users notice (`**Fix:**`, one group).
- Issue: `[fixed]` → move to `fixed/`; symptom-only → `[workaround]` + linked `[open]` root issue. Tag = body = README row = cross-links.
- Feature guide if behavior users read about changed.

### 8 · Report (plain, this shape — `honesty-and-completion.mdc`)
```
Symptom fix — what, path:line / command to verify
Root fix — done | not done → docs/issues/NNN-[open]-…
Workaround — yes (approved by user: yes/no) | no
Verification — what ran, what could not
Issue file — filename tag + **Status:** + README updated: yes/no
Changelog — bullet added (group) | not user-visible because …
```