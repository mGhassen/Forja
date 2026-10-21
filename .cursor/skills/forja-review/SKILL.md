---
name: forja-review
description: >-
  Review the working tree (or a ref/PR) against Forja laws and for correctness
  using the forja-law-reviewer subagent, or the forja-law-review workflow for a
  thorough multi-agent pass. Use when the user says review, check my diff,
  before I commit, or law check.
argument-hint: "[base-ref | PR#] [--thorough]"
allowed-tools: Agent, Workflow, Bash, Read, Grep, Glob
---

# /forja-review $ARGUMENTS

Diff summary:

!`git diff --stat HEAD 2>/dev/null | tail -15; git ls-files --others --exclude-standard | head -15`

## Default pass

Spawn `forja-law-reviewer` with: the base ref (default `HEAD`; a PR number → `gh pr diff <n>`), the file list above, and the instruction to open every cited file. Relay its Findings / Docs status / Verdict verbatim, then fix **block** and **fix** items if the user asked for fixes, otherwise stop at the report.

## Thorough pass (`--thorough`, or the user says "use a workflow" / "thorough")

Run the saved workflow `forja-law-review` (`.claude/workflows/forja-law-review.js`) with `args: { base: "<ref>" }`. It fans out one finder per law dimension, adversarially verifies each finding, and returns `confirmed` and `dropped`. Report confirmed findings ranked block → fix → nit, each with `path:line` and the rule file. Mention how many candidate findings the verify stage dropped.

## Always

- No praise sections. If nothing is wrong, one sentence plus the docs status line.
- A user-visible code change with no bullet in `docs/changelog/*-[draft].md` is a **fix**-level finding, not a nit.
- A hidden/disabled/forced user option presented as a fix is a **block** (`no-hide-as-fix.mdc`).