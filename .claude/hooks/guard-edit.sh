#!/usr/bin/env bash
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit) — protect frozen / forbidden paths.
source "$(dirname "$0")/lib/common.sh"
fp="$(json_get '.tool_input.file_path')"
[[ -z "$fp" ]] && fp="$(json_get '.tool_input.notebook_path')"
[[ -z "$fp" ]] && exit 0
rel="$(rel_path "$fp")"

case "$rel" in
  docs/backlog/*)
    pre_decide deny "docs-rfc-issues.mdc: never touch docs/backlog/ unless the user explicitly asks." ;;
  docs/changelog/done/*)
    pre_decide deny "Frozen release notes. Edit the active docs/changelog/*-[draft].md instead." ;;
  apps/web/supabase/migrations/*.sql)
    if [[ -f "$fp" ]]; then
      pre_decide deny "supabase-migrations.mdc: shipped migrations are immutable. Create a new one: cd apps/web && supabase migration new <name>."
    fi ;;
  apps/forja/lib/shared/foundation/*|apps/forja/lib/shared/kit/*)
    pre_decide deny "forja-design-system.mdc: do not recreate apps/forja/lib/shared/foundation/ or shared/kit/. Paint lives in packages/forja_foundation; CI check_foundation_shim_alive.sh fails otherwise." ;;
  .claude/skills/*)
    pre_decide deny "'.claude/skills' is a symlink to '.cursor/skills'. Edit the skill at .cursor/skills/<name>/SKILL.md so both editors stay on one source." ;;
  .env|.env.*|apps/web/.env|apps/web/.env.*)
    [[ "$rel" == *.example ]] || pre_decide deny "Secrets file. Edit .env.example for the variable list; the user manages .env." ;;
  apps/forja/android/key.properties|*/release.keystore)
    pre_decide deny "Signing material is never edited by the agent." ;;
esac

# Shipped docs under fixed/ or canceled/ are historical records.
case "$rel" in
  docs/*/fixed/*|docs/*/canceled/*)
    pre_decide ask "This doc is in fixed/ or canceled/ (historical). Task tables are append-only; confirm the edit is a cross-link/index fix, not a rewrite." ;;
esac

exit 0
