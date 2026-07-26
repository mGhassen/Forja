#!/usr/bin/env bash
set -euo pipefail

# Bump apps/forja semver and increment build number.
# Default: patch (used by release.yml / release_local on new version).
#
# Always:
#   - apps/forja/pubspec.yaml
#   - installer/windows/setup.iss MyAppVersion
#
# On minor / major (same process as opening a new arc — not patch-only):
#   - kReleaseCodename from docs/backlog runway
#   - runway status emojis (previous arc ✅, new arc 🔄)
#
# Prints new semver to stdout (for CI: echo "version=$NEW" >> "$GITHUB_OUTPUT").

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUMP="${1:-patch}"

PUBSPEC="$ROOT/apps/forja/pubspec.yaml"
SETUP_ISS="$ROOT/installer/windows/setup.iss"
VERSION_DART="$ROOT/apps/forja/lib/shared/services/app_version.dart"
BACKLOG_README="$ROOT/docs/backlog/README.md"

current="$(grep '^version:' "$PUBSPEC" | sed 's/version: *//')"
semver="${current%%+*}"
build="${current#*+}"
[[ "$build" == "$current" ]] && build=0

IFS=. read -r major minor patch <<<"$semver"
prev_major="$major"
prev_minor="$minor"

# Sync only with tags on the current minor arc that are ancestors of HEAD.
# Stale tags from other eras (e.g. May v1.3.*) must not jump the bump.
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r latest_tag; do
    [[ -z "$latest_tag" ]] && continue
    if git -C "$ROOT" merge-base --is-ancestor "$latest_tag" HEAD 2>/dev/null; then
      tag_semver="${latest_tag#v}"
      semver="$(printf '%s\n%s\n' "$semver" "$tag_semver" | sort -V | tail -1)"
      IFS=. read -r major minor patch <<<"$semver"
      prev_major="$major"
      prev_minor="$minor"
      break
    fi
  done < <(git -C "$ROOT" tag -l "v${major}.${minor}.*" --sort=-v:refname 2>/dev/null || true)
fi

case "$BUMP" in
  patch) patch=$((patch + 1)) ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  major) major=$((major + 1)); minor=0; patch=0 ;;
  *) echo "invalid bump: $BUMP" >&2; exit 1 ;;
esac

build=$((build + 1))
new="${major}.${minor}.${patch}+${build}"

sed -i.bak "s/^version: .*/version: $new/" "$PUBSPEC"
rm -f "$PUBSPEC.bak"

semver_line="  #define MyAppVersion \"${major}.${minor}.${patch}\""
if [[ "$(uname -s)" == Darwin ]]; then
  sed -i '' "s/^  #define MyAppVersion \".*\"/${semver_line}/" "$SETUP_ISS"
else
  sed -i "s/^  #define MyAppVersion \".*\"/${semver_line}/" "$SETUP_ISS"
fi

# Minor/major: same arc-open work every time (codename + runway). Patch skips.
if [[ "$BUMP" == "minor" || "$BUMP" == "major" ]]; then
  if [[ ! -f "$VERSION_DART" || ! -f "$BACKLOG_README" ]]; then
    echo "bump_version: error — missing app_version.dart or backlog README for arc bump" >&2
    exit 1
  fi

  python3 - "$BACKLOG_README" "$VERSION_DART" \
    "${prev_major}.${prev_minor}" "${major}.${minor}" <<'PY'
import re
import sys
from pathlib import Path

readme_path = Path(sys.argv[1])
dart_path = Path(sys.argv[2])
prev_arc = sys.argv[3]
new_arc = sys.argv[4]

readme = readme_path.read_text(encoding="utf-8")

def codename_for(arc: str):
    pat = re.compile(
        r"\|\s*\*\*" + re.escape(arc) + r"\*\*\s*[^|]*\|\s*\*\*([^*]+)\*\*"
    )
    m = pat.search(readme)
    return m.group(1).strip() if m else None

def set_status(text: str, arc: str, status: str) -> str:
    # | **1.3** ⬜ | **Elblat** |  → status emoji after the arc cell
    pat = re.compile(
        r"(\|\s*\*\*" + re.escape(arc) + r"\*\*\s*)(✅|🔄|⬜)(\s*\|)"
    )
    if not pat.search(text):
        raise SystemExit(f"bump_version: runway row for {arc} not found or has no status emoji")
    return pat.sub(rf"\1{status}\3", text, count=1)

codename = codename_for(new_arc)
if not codename:
    raise SystemExit(f"bump_version: no runway codename for {new_arc}")

dart = dart_path.read_text(encoding="utf-8")
dart_new, n = re.subn(
    r"^const kReleaseCodename = '.*';",
    f"const kReleaseCodename = '{codename}';",
    dart,
    count=1,
    flags=re.M,
)
if n != 1:
    raise SystemExit("bump_version: could not update kReleaseCodename in app_version.dart")
dart_path.write_text(dart_new, encoding="utf-8")
print(f"bump_version: kReleaseCodename → {codename}", file=sys.stderr)

# Previous shipping arc → done; new arc → in progress (same as opening a minor manually).
readme = set_status(readme, prev_arc, "✅")
readme = set_status(readme, new_arc, "🔄")
# Keep the "today …" hint in sync when present.
readme = re.sub(
    r"(\[`kReleaseCodename\`][^)]+\) tracks \*\*app semver minor\*\* \(today \*\*)[^*]+(\*\*)",
    rf"\g<1>{new_arc} → {codename}\2",
    readme,
    count=1,
)
readme_path.write_text(readme, encoding="utf-8")
print(f"bump_version: runway {prev_arc} ✅ → {new_arc} 🔄 ({codename})", file=sys.stderr)
PY
fi

echo "${major}.${minor}.${patch}"
