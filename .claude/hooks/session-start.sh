#!/usr/bin/env bash
# SessionStart — inject repo facts Claude otherwise re-derives every session.
source "$(dirname "$0")/lib/common.sh"
cd "$ROOT" || exit 0

have() { command -v "$1" >/dev/null 2>&1 && echo "yes" || echo "MISSING"; }

app_ver="$(grep -m1 '^version:' apps/forja/pubspec.yaml 2>/dev/null | sed 's/version: *//')"
engine_ver="$(awk '/^\[workspace.package\]/{f=1} f && /^version/{gsub(/[" ]/,"",$3); print $3; exit}' crates/Cargo.toml 2>/dev/null)"
codename="$(fgrep_n 'kReleaseCodename *=' apps/forja/lib/shared/services/update/app_version.dart 2>/dev/null | head -1 | sed -E "s/.*= *'([^']*)'.*/\1/")"
drafts="$(ls docs/changelog/*-\[draft\].md 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
packs="absent"
if [[ -n "${FORJA_PACKS_ROOT:-}" && -d "${FORJA_PACKS_ROOT}" ]]; then packs="FORJA_PACKS_ROOT=$FORJA_PACKS_ROOT"
elif [[ -d "$ROOT/../forja-packs" ]]; then packs="sibling ../forja-packs"; fi

ctx="Forja session facts (hook, $(date +%Y-%m-%d)):
- git: branch=$branch, dirty files=$dirty
- app version (apps/forja/pubspec.yaml): ${app_ver:-?} · codename: ${codename:-?} · Rust engine (crates/Cargo.toml): ${engine_ver:-?}
- active changelog drafts: ${drafts:-none}
- toolchain on this machine: flutter=$(have flutter) dart=$(have dart) cargo=$(have cargo) melos=$(have melos) rustfmt=$(have rustfmt) supabase=$(have supabase) pnpm=$(have pnpm) gh=$(have gh) rg=$([[ -n "$RG_BIN" ]] && echo yes || echo MISSING)
- forja-packs checkout: $packs (app test suite reads it; missing → extra failures that are not regressions)
If flutter/cargo are MISSING: never claim analyze/tests passed; say they could not be run here.
Setup map: .claude/README.md · laws: CLAUDE.md · rules auto-load from .claude/rules/ by path · pipelines: /forja-fix /forja-feature /forja-verify /forja-review /forja-issue"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$(json_escape "$ctx")"
exit 0
