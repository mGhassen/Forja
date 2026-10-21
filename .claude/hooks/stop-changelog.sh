#!/usr/bin/env bash
# Stop — once per session, if user-visible code changed and no changelog draft
# did, make Claude either add the bullet or state the change is not user-visible.
source "$(dirname "$0")/lib/common.sh"
cd "$ROOT" || exit 0
[[ "$(json_get '.stop_hook_active')" == "true" ]] && exit 0
marker="$(state_file changelog-nagged)"
[[ -f "$marker" ]] && exit 0

changed="$( { git diff --name-only; git diff --name-only --cached; git ls-files --others --exclude-standard; } 2>/dev/null | sort -u)"
[[ -z "$changed" ]] && exit 0

visible="$(grep -E '^(apps/forja/lib/|packages/forja_foundation/lib/|apps/web/src/|crates/)' <<<"$changed" | grep -vE '_test\.dart$|/test/' | head -5)"
[[ -z "$visible" ]] && exit 0
grep -qE '^docs/changelog/[^/]*-\[draft\]\.md$' <<<"$changed" && exit 0

touch "$marker"
reason="Changelog law (changelog.mdc): product code changed ($(tr '\n' ' ' <<<"$visible")) but no docs/changelog/*-[draft].md changed. Either add the user-facing bullet(s) now (**Add:** / **Change:** / **Fix:** / **Remove:**, one group, no paths/IDs) in the active draft, or state in one sentence that the change is not user-visible and why. Also confirm any touched RFC/issue has its status tag + **Status:** + README row in sync."
printf '{"decision":"block","reason":%s}\n' "$(json_escape "$reason")"
exit 0
