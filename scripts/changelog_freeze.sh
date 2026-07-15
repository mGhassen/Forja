#!/usr/bin/env bash
set -euo pipefail

# Freeze the active changelog draft into the released file for a shipped version.
#
# Usage: scripts/changelog_freeze.sh <version>
#
# The <version> is decided by the release admin (CI bump / chosen tag). This
# script maps 1.2.186 -> docs/changelog/1.2.x-[draft].md and:
#   - moves the draft to docs/changelog/done/1.2.186-[released].md,
#     setting the title to "# 1.2.186 — <codename>" and **Status:** released,
#   - updates docs/changelog/README.md (Active row + Released table),
#   - starts a fresh empty docs/changelog/1.2.x-[draft].md with
#     **Since release:** pointing at the version just shipped.
#
# Idempotent: if the draft is already frozen (no draft file, or the released
# file already exists), it exits 0 without changes so CI re-runs and the
# "Existing tag" release mode do not fail.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: changelog_freeze.sh <version>}"

IFS=. read -r major minor _patch <<<"$VERSION"
minor_line="${major}.${minor}.x"
draft="$ROOT/docs/changelog/${minor_line}-[draft].md"
released="$ROOT/docs/changelog/done/${VERSION}-[released].md"
readme="$ROOT/docs/changelog/README.md"

# Codename source of truth: kReleaseCodename in app_version.dart.
version_dart="$ROOT/apps/forja/lib/shared/services/app_version.dart"
codename=""
if [[ -f "$version_dart" ]]; then
  codename="$(sed -n "s/^const kReleaseCodename = '\(.*\)';/\1/p" "$version_dart" | head -1)"
fi

if [[ -f "$released" ]]; then
  echo "changelog_freeze: ${released#"$ROOT"/} already exists — nothing to do." >&2
  exit 0
fi

if [[ ! -f "$draft" ]]; then
  echo "changelog_freeze: no draft at ${draft#"$ROOT"/} — nothing to freeze." >&2
  exit 0
fi

mkdir -p "$ROOT/docs/changelog/done"

VERSION="$VERSION" CODENAME="$codename" MINOR_LINE="$minor_line" \
DRAFT="$draft" RELEASED="$released" README="$readme" \
python3 - <<'PY'
import os
import re

version = os.environ["VERSION"]
codename = os.environ["CODENAME"]
minor_line = os.environ["MINOR_LINE"]
draft_path = os.environ["DRAFT"]
released_path = os.environ["RELEASED"]
readme_path = os.environ["README"]

title = f"# {version} — {codename}" if codename else f"# {version}"

with open(draft_path, "r", encoding="utf-8") as fh:
    src = fh.read()

# Keep the bullet body: everything from the first horizontal rule onward.
idx = src.find("\n---")
body = src[idx:].lstrip("\n") if idx != -1 else ""

released_lines = [
    title,
    "",
    "**Status:** released  ",
    f"**Version:** {version} (`v{version}` — {codename})" if codename
    else f"**Version:** {version} (`v{version}`)",
    "",
]
if body:
    released_lines.append(body.rstrip() + "\n")

with open(released_path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(released_lines).rstrip() + "\n")

# Fresh empty draft for the next patch batch on the same minor line.
draft_lines = [
    f"# {minor_line} — {codename}" if codename else f"# {minor_line}",
    "",
    "**Status:** draft  ",
    f"**Since release:** {version} (`v{version}`)",
    "",
    f"User-facing changes for the next **{minor_line}** patch. Update on every "
    "push; edit or remove bullets when later pushes correct earlier work. On "
    "ship, this file becomes `done/X.Y.Z-[released].md` (exact patch from the "
    "release tag) and a fresh `" + minor_line + "-[draft].md` starts.",
    "",
    "Use the [thematic groups](../../.cursor/rules/changelog.mdc#thematic-groups-forja) "
    "below — **add a `### Group` heading only when that group has bullets**; never "
    "leave empty group headers. Every bullet starts with `**Add:**` · `**Change:**` "
    "· `**Fix:**` · `**Remove:**`.",
    "",
    "---",
    "",
]
with open(draft_path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(draft_lines))

# README: refresh Active row, prepend a Released row.
released_rel = f"done/{version}-[released].md"
draft_rel = f"{minor_line}-[draft].md"
active_row = f"| [{draft_rel}]({draft_rel}) | {codename} | v{version} | drafting |"
released_row = f"| {version} | {codename} | [{released_rel}]({released_rel}) |"

with open(readme_path, "r", encoding="utf-8") as fh:
    lines = fh.readlines()

out = []
section = None
released_inserted = False
active_replaced = False
for line in lines:
    stripped = line.strip()
    if stripped.startswith("## Active"):
        section = "active"
        out.append(line)
        continue
    if stripped.startswith("## Released"):
        section = "released"
        out.append(line)
        continue
    if stripped.startswith("## "):
        section = None
        out.append(line)
        continue

    if section == "active" and stripped.startswith("|") and not active_replaced:
        # Header/separator rows contain "File" or dashes; data rows start with "| [".
        if stripped.startswith("| ["):
            out.append(active_row + "\n")
            active_replaced = True
            continue

    if section == "released" and stripped.startswith("|") and not released_inserted:
        # Insert the new released row right after the separator row.
        if set(stripped.replace("|", "").strip()) <= set("- "):
            out.append(line)
            out.append(released_row + "\n")
            released_inserted = True
            continue

    out.append(line)

with open(readme_path, "w", encoding="utf-8") as fh:
    fh.writelines(out)

print(f"changelog_freeze: froze {draft_rel} -> {released_rel}")
PY
