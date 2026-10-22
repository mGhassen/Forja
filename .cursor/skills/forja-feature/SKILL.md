---
name: forja-feature
description: >-
  Feature pipeline for Forja: scope gate, architect plan past the status quo
  with pack/host/foundation/engine placement, RFC or issue filing, implement by
  layer, verify, law review, changelog and feature guide same turn. Use when the
  user asks to add, build, implement, design, or plan a capability.
argument-hint: "<what the user should be able to do>"
---

# /forja-feature $ARGUMENTS

Open RFCs and issues (for reuse of ids):

!`ls docs/rfc/*-\[open\]-* docs/rfc/*-\[planned\]-* 2>/dev/null | xargs -n1 basename 2>/dev/null | head -20`

## Pipeline

### 0 · Scope gate
In-scope: Search, Home, Anime, Asian Drama, IPTV, Live Sports, Lists, Settings and the shared player/shell/sources they use. Anything else → ask before planning (`forja-feature-scope.mdc`).

### 1 · Plan (subagent `forja-architect`)
Brief it with the goal and the scout findings if any. Require the three-layer capability table (platform allows · Forja today · plan target), placement per piece, steps with laws and verification, docs to touch. Recommendation first; a gap is one line of target design, never "can't" (`plan-better-than-status-quo.mdc`).

Placement rules of thumb:
- Product tab, layout, provider logic, hub chrome → **pack** (`forja-packs` sibling repo). Host side only gets the generic capability.
- Paint (tokens, widgets, blocks) → `packages/forja_foundation`, props + callbacks only.
- Non-platform logic (HTTP, parse, crypto, proxy, persistence) → `crates/*` with Pattern B FFI. No new engine logic in Dart.
- Platform (WebView, Nuvio JS, player, OAuth, OS intents) → host.

### 2 · Present the plan to the user when it is a multi-file change or touches placement; proceed directly for small, obvious work.

### 3 · Track
Substantial work → RFC (`docs/rfc/NNN-[open]-…`) or issue, filed in the same turn as the first code change (`/forja-issue` for issues; the `forja-docs-rfc-issues` skill for RFC shape). Append new task rows; never rewrite existing ones.

### 4 · Implement by layer
`forja-flutter-engineer` / `forja-rust-engineer` / `forja-web-engineer`, one brief each with the step list for their layer. Independent layers may run in parallel. Each returns the Changed / Verification / Fix layer / Docs owed report.

### 5 · Verify — `/forja-verify` or `forja-qa`.

### 6 · Law review — `forja-law-reviewer`; fix blocks and fixes; re-verify touched files.

### 7 · Docs, same turn — `forja-docs-keeper`
Changelog `**Add:**` bullet(s) in the active draft, one per user story, right group. Feature guide page under `docs/features/**` describing what the product does now (no history words). RFC/issue rows flipped; tag = body = README.

### 8 · Report
```
Shipped — what the user can now do (one or two sentences)
Placement — pack / host / foundation / engine pieces and files
Verification — ran / could not run
Tracker — RFC/issue file and status
Changelog + feature guide — done / not user-visible because …
Left out — anything scoped down and why (the user decides, not you)
```