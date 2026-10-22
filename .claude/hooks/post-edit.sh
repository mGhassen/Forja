#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit) — format + enforce the repo's grep-able laws
# on the file that was just changed. Hard laws block (exit 2); soft ones warn.
source "$(dirname "$0")/lib/common.sh"
fp="$(json_get '.tool_input.file_path')"
[[ -z "$fp" || ! -f "$fp" ]] && exit 0
rel="$(rel_path "$fp")"
cd "$ROOT" || exit 0

blocks=()
warns=()

# ---------------- Dart ----------------
if [[ "$rel" == *.dart ]]; then
  if command -v dart >/dev/null 2>&1; then
    dart format --output=write --set-exit-if-changed "$fp" >/dev/null 2>&1 || true
  fi

  is_test=0; [[ "$rel" == *_test.dart || "$rel" == */test/* ]] && is_test=1

  # Foundation zone A must never import the host or Riverpod (check_foundation_import_zone.sh).
  case "$rel" in
    packages/forja_foundation/lib/components/*|packages/forja_foundation/lib/widgets/*|packages/forja_foundation/lib/tokens/*|packages/forja_foundation/lib/blocks/*|packages/forja_foundation/lib/brand/*|packages/forja_foundation/lib/protocol/*)
      fgrep_q 'package:forja/' "$fp"        && blocks+=("forja_foundation must not import package:forja/ (RFC-106 zone A; CI check_foundation_import_zone.sh)")
      fgrep_q 'flutter_riverpod|riverpod_annotation' "$fp" && blocks+=("forja_foundation must not import Riverpod — props + callbacks only (forja-design-system.mdc)")
      fgrep_q "features/" "$fp" && fgrep_q 'import .*features/' "$fp" && blocks+=("forja_foundation must not import features/** (forja-shared-ui.mdc)")
      fgrep_q '\.clamp\([0-9]' "$fp" && warns+=("numeric clamp literal in foundation paint — token it in packages/forja_foundation/lib/tokens/* (forja-foundation-no-hardcode.mdc)")
      ;;
  esac

  if [[ "$rel" == apps/forja/lib/* && $is_test -eq 0 ]]; then
    # TV shell boundary (check_tv_shell_boundary.sh)
    fgrep_q 'ShellTokens\.isTvLayout|ShellTokens\.isAndroidTvDevice' "$fp" \
      && blocks+=("ShellTokens.isTvLayout / isAndroidTvDevice leaked into $rel — use ShellScope.metricsOf / inputPolicyOf (forja-tv-scope.mdc; CI check_tv_shell_boundary.sh)")
    # Shim resurrection
    fgrep_q 'package:forja/shared/foundation/' "$fp" \
      && blocks+=("import of package:forja/shared/foundation/ — that tree is deleted; import packages/forja_foundation files (check_foundation_shim_alive.sh)")
    # Sync FFI outside allowlist (check_sync_ffi.sh)
    if fgrep_q 'RustLib\.instance\.' "$fp" && ! grep -qxF "$rel" docs/issues/sync-ffi-allowlist.txt 2>/dev/null; then
      blocks+=("RustLib.instance.* in $rel is not in docs/issues/sync-ffi-allowlist.txt — route long FFI through packages/rust/lib/src/isolate_runner.dart (rust-migration.mdc; CI check_sync_ffi.sh)")
    fi
    # Playback host stays generic
    if [[ "$rel" == apps/forja/lib/shared/playback/* ]]; then
      fgrep_q "open\.surface|EngineCategories\.(anime|drama|arabic)|mediaType *== *'anime'|kisskhId|anilistId" "$fp" \
        && blocks+=("shared/playback must stay generic — no surface/hub branches (forja-playback-host-generic.mdc)")
    fi
    # Design-system soft checks
    fgrep_q 'Colors\.white54|Colors\.white70|Colors\.white38' "$fp" && warns+=("raw Colors.whiteNN — prefer ForjaShellColors tokens (forja-design-system.mdc)")
    fgrep_q 'BackdropFilter' "$fp" && [[ "$rel" != *frosted* ]] && warns+=("BackdropFilter outside ForjaFrostedPanel — flat cinematic shell forbids ad-hoc blur; never over live video (forja-design-system.mdc)")
    fgrep_q '[^a-zA-Z]Switch\(|SwitchListTile\(' "$fp" && warns+=("raw Switch — use ForjaSwitch / forjaSwitchThemeData (forja-design-system.mdc)")
    fgrep_q 'TextField\(|TextFormField\(' "$fp" && warns+=("raw TextField — on leanback TV D-pad focus must only highlight; use TvBrowseTextField / SettingsTextField gated by browseTextUntilActivate (forja-tv-scope.mdc)")
    fgrep_q 'autofocus: *true' "$fp" && warns+=("autofocus: true — forbidden on editable fields on leanback (forja-tv-scope.mdc)")
    fgrep_q 'width *> *900' "$fp" && warns+=("raw width > 900 breakpoint — read ShellScope.metrics (RFC-028)")
  fi

  if [[ "$rel" == apps/forja/test/* ]]; then
    fgrep_q "'(kisskh|videasy|hianime|larozaa|anime|asian_drama|arabic|iptv|live_sports)'" "$fp" \
      && warns+=("host test names a shipped pack/hub id — host tests prove generic contracts with synthetic fixtures only (forja-host-tests-no-pack-contracts.mdc)")
  fi
fi

# ---------------- Rust ----------------
if [[ "$rel" == crates/*.rs ]]; then
  command -v rustfmt >/dev/null 2>&1 && rustfmt --edition 2021 "$fp" >/dev/null 2>&1 || true
  fgrep_q '_html_json' "$fp" && warns+=("new Pattern A FFI (*_html_json) is forbidden — fetch+parse in Rust (rust-migration.mdc)")
  if [[ "$rel" != crates/Cargo.toml ]] && fgrep_q '^version *= *"' "$fp" 2>/dev/null; then :; fi
fi
if [[ "$rel" == crates/*/Cargo.toml && "$rel" != crates/Cargo.toml ]]; then
  grep -qE '^version *= *"[0-9]' "$fp" && blocks+=("per-crate version in $rel — crates use version.workspace = true; bump via ./scripts/release_local.sh bump-engine (rust-engine-versioning.mdc)")
fi

# ---------------- Docs lifecycle ----------------
case "$rel" in
  docs/rfc/*.md|docs/issues/*.md|docs/migration/*.md)
    base="$(basename "$rel")"
    if [[ "$base" =~ ^[0-9]+-\[([a-z]+)\]- ]]; then
      tag="${BASH_REMATCH[1]}"
      body="$(grep -m1 -E '^\*\*Status:\*\*' "$fp" | sed -E 's/^\*\*Status:\*\* *//; s/[`* ].*$//' | tr 'A-Z' 'a-z')"
      [[ "$tag" == "fixed" && "$rel" != */fixed/* ]] && blocks+=("$base is tagged [fixed] but not under fixed/ — move it in the same turn (forja-docs-rfc-issues)")
      [[ "$tag" == "canceled" && "$rel" != */canceled/* ]] && blocks+=("$base is tagged [canceled] but not under canceled/")
      if [[ -n "$body" && "$body" != "$tag" ]]; then
        # stub/partial alias
        if ! [[ "$tag" == "partial" && "$body" == "stub" ]]; then
          blocks+=("filename tag [$tag] ≠ **Status:** $body in $rel — same turn: rename + body + README index + cross-links (docs-rfc-issues.mdc)")
        fi
      fi
      grep -qE '^\*\*Target version:\*\*|docs/backlog/' "$fp" && warns+=("RFC/issue body carries a ship version or backlog link — forbidden (docs-rfc-issues.mdc)")
    fi
    ;;
  docs/changelog/*-\[draft\].md)
    bad="$(grep -nE '^- ' "$fp" | grep -vE '^[0-9]+:- \*\*(Add|Change|Fix|Remove):\*\* ' | head -3)"
    [[ -n "$bad" ]] && blocks+=("changelog bullets must start with **Add:** / **Change:** / **Fix:** / **Remove:** — offending: $bad")
    grep -qiE '\b(RFC-[0-9]+|issue [0-9]+|crates?/|apps/forja|\.dart\b|\.rs\b)' "$fp" && warns+=("changelog mentions RFC/issue IDs, paths, or crate names — user-facing bullets only (forja-changelog)")
    grep -qE '^- \*\*(Improve|Update|Refactor|Added|Fixed):' "$fp" && blocks+=("invented changelog verb — map to Add/Change/Fix/Remove")
    ;;
  docs/features/*.md|*/manifest.json)
    fgrep_q '\b(formerly|no longer|only \(|host-owned|kit protocol|separate packs)\b' "$fp" && warns+=("user-facing copy carries history/architecture words (formerly / no longer / host-owned …) — describe what it does now (user-facing-copy-truth.mdc)")
    ;;
esac

# ---------------- Rules/skills single source ----------------
if [[ "$rel" == .cursor/rules/*.mdc ]]; then
  warns+=("rule changed in .cursor/rules — if it is path-scoped, check the matching bridge in .claude/rules/ still points at it (paths: globs)")
fi

# ---------------- Emit ----------------
if ((${#blocks[@]})); then
  msg="Forja law violation in $rel:"
  for b in "${blocks[@]}"; do msg+=$'\n'"  ✗ $b"; done
  ((${#warns[@]})) && for w in "${warns[@]}"; do msg+=$'\n'"  ⚠ $w"; done
  post_block "$msg"
fi
if ((${#warns[@]})); then
  msg="Forja checks for $rel (not blocking):"
  for w in "${warns[@]}"; do msg+=$'\n'"  ⚠ $w"; done
  post_context "$msg"
fi
exit 0
