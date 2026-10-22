#!/usr/bin/env bash
# PreToolUse(Bash) — enforce repo laws that settings.json prefix rules cannot express.
# deny = hard law · ask = owner decision · no output = fall through to normal permissions.
source "$(dirname "$0")/lib/common.sh"
cmd="$(json_get '.tool_input.command')"
[[ -z "$cmd" ]] && exit 0

# A pattern only counts at "command position": line start or right after ; & | ( $(
# so mentions inside quoted prose, heredocs, or JSON test fixtures do not trigger.
P='(^|[;&|(]|\$\()[[:space:]]*(sudo[[:space:]]+)?'
at_cmd() { grep -qE "${P}$1" <<<"$cmd"; }
mentions() { grep -qE "$1" <<<"$cmd"; }

# --- Supabase is production (supabase-migrations.mdc) ---
if at_cmd 'supabase[[:space:]]+(db[[:space:]]+(reset|push|remote)|link|migration[[:space:]]+(repair|squash))' \
   || at_cmd '(node|pnpm|npm|npx)[[:space:]]+[^;&|]*reset-forja-supabase\.js' \
   || at_cmd 'pnpm[[:space:]]+(run[[:space:]]+)?supabase:reset'; then
  pre_decide deny "Blocked by supabase-migrations.mdc: never reset, push, or link Supabase, and never run the reset script, without the user saying so in this conversation. Create a migration with 'supabase migration new <name>' and ask before applying."
fi
if at_cmd '(sed[[:space:]]+-i|mv|rm|tee)[[:space:]][^;&|]*apps/web/supabase/migrations/' || mentions '>>?[[:space:]]*[^;&|[:space:]]*apps/web/supabase/migrations/'; then
  pre_decide deny "Blocked: shipped migrations under apps/web/supabase/migrations/ are immutable. Add a new forward migration via 'supabase migration new'."
fi

# --- Git hygiene (CLAUDE.md · git-attribution.mdc) ---
if at_cmd 'git[[:space:]]+stash'; then
  pre_decide deny "Blocked by CLAUDE.md: never 'git stash' this tree to get a baseline. Use a detached worktree (git worktree add --detach <dir> <ref>)."
fi
if at_cmd 'git[[:space:]]+push[^;&|]*(--force|-f([[:space:]]|$)|--force-with-lease)'; then
  pre_decide deny "Blocked: force-push is not allowed from an agent session."
fi
if at_cmd 'git[[:space:]]+(reset[[:space:]]+--hard|checkout[[:space:]]+--[[:space:]]+\.|clean[[:space:]]+-[a-zA-Z]*f|branch[[:space:]]+-D)'; then
  pre_decide ask "Destructive git command. The repo owner tests on device before accepting work; confirm you really want to discard local changes."
fi
if at_cmd 'git[[:space:]]+(commit|push|add|tag|rebase|merge|cherry-pick)'; then
  if mentions 'Made-with: Cursor|Co-authored-by: Cursor'; then
    pre_decide deny "Blocked by git-attribution.mdc: no Cursor attribution trailers."
  fi
  pre_decide ask "CLAUDE.md: do not stage/commit/push unless the user asked. Confirm this was requested."
fi

# --- Release / version admin is a human decision (changelog.mdc · rust-engine-versioning.mdc) ---
if at_cmd '(bash[[:space:]]+|sh[[:space:]]+)?[^;&|[:space:]]*scripts/(release_local|release_ci|bump_version|changelog_freeze|changelog_release_notes|backfill_version_tags|upload_release_to_r2|package_[a-z_]+|build_macos|build_windows_release|codesign_macos_adhoc)'; then
  pre_decide ask "Release/version/packaging script. Version and codename are decided by the release admin, not by the agent. Confirm."
fi

# --- Secrets ---
if at_cmd '(cat|less|more|head|tail|bat|sed|awk|grep|rg|open|code|cp|scp|source|\.)[[:space:]]+([^;&|]*[[:space:]/])?\.env([[:space:]]|$|\.local|\.production)' \
   && ! mentions '\.env\.example'; then
  pre_decide deny "Blocked: .env holds real API keys. Read .env.example for the variable list; never print secrets into the transcript."
fi
if at_cmd '(cat|less|more|head|tail|cp|scp|base64|xxd|open)[[:space:]][^;&|]*(key\.properties|release\.keystore|\.pem|\.p12)'; then
  pre_decide deny "Blocked: signing material. Do not read or copy keystores/keys."
fi

# --- Frozen docs (docs-rfc-issues.mdc · changelog) ---
if at_cmd '(sed[[:space:]]+-i|mv|rm|git[[:space:]]+mv|touch|tee)[[:space:]][^;&|]*docs/(backlog|changelog/done)/' || mentions '>>?[[:space:]]*[^;&|[:space:]]*docs/(backlog|changelog/done)/'; then
  pre_decide deny "Blocked: docs/backlog/ (docs-rfc-issues.mdc) and docs/changelog/done/ (frozen release notes) are never edited unless the user explicitly asks."
fi

# --- Slow / misleading test invocations ---
if at_cmd 'flutter[[:space:]]+test([[:space:]]|$)' && mentions 'apps/forja' \
   && ! mentions 'flutter[[:space:]]+test[[:space:]]+[^-[:space:]]*test/'; then
  pre_decide ask "Full apps/forja suite takes 10+ min and has ~30 known-bad tests on main (catalog_protocol_test, sources_panel_filters_nuvio_lazy_test, forja_logo_halo_pixels_test timeout). Prefer a targeted file: flutter test test/<file>_test.dart. Continue anyway?"
fi

# --- Dangerous deletes ---
if at_cmd 'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]' && ! mentions 'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+("?\$?[A-Za-z_./-]*/)?(build|\.dart_tool|target|node_modules|dist|\.tmp[a-z_]*|_hooktest)'; then
  pre_decide ask "Recursive delete outside build/cache dirs. Confirm."
fi

exit 0
