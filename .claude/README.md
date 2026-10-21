# Claude Code setup for Forja

One source of truth for agent rules: `.cursor/rules/*.mdc` and `.cursor/skills/*/SKILL.md`. Everything under `.claude/` either points at those or adds behavior Cursor cannot express (hooks, permissions, subagents, workflows). Set up 2026-10-20.

```
CLAUDE.md                 always-on laws + repo map (loaded every session, < 200 lines)
.claude/
  settings.json           permissions (allow / ask / deny), hook wiring, MCP approval
  rules/*.md              path-scoped bridges → which .cursor/rules/*.mdc to read for the files you touch
  agents/*.md             8 subagents (scout, architect, 3 engineers, qa, law reviewer, docs keeper)
  hooks/*.sh              session facts · bash guard · edit guard · post-edit law lint · stop changelog nudge
  workflows/forja-law-review.js   multi-agent review: finder per law dimension → adversarial verify
  skills -> ../.cursor/skills     symlink (shared with Cursor) — 6 original + 7 pipeline skills
.mcp.json                 dart (official SDK server), context7, github (token), supabase read-only (token)
```

## Pipelines (skills you invoke with `/`)

| Skill | Flow |
|-------|------|
| `/forja-fix <issue \| bug>` | scope gate → `forja-scout` → classify symptom/root/workaround (ask before workaround or any hide) → track issue → implement (engineer agent) → `/forja-verify` → `forja-law-reviewer` → `forja-docs-keeper` → honest report |
| `/forja-feature <goal>` | scope gate → `forja-architect` plan (3-layer table, placement) → RFC/issue → engineers by layer (parallel) → verify → review → changelog + feature guide → report |
| `/forja-verify [scope]` | boundary scripts → foundation analyze/test → app analyze → targeted tests → cargo → pnpm, against the known-bad baseline; delegates to `forja-qa` |
| `/forja-review [ref] [--thorough]` | `forja-law-reviewer` on the diff; `--thorough` runs the `forja-law-review` workflow |
| `/forja-issue <title> [--open]` | next NNN, template, README row, cross-links |
| `/forja-rust-engine` | build/test/port checklist, bump policy |
| `/forja-tv-dpad [tab]` | leanback grep sweep + per-screen checklist |

Original skills (Cursor-era, still the detail layer): `forja-changelog`, `forja-docs-rfc-issues`, `forja-live-native-playback`, `forja-pack-product-host`, `forja-simple-writing`, `forja-user-facing-copy`.

## Subagents

| Agent | Role | Writes code? |
|-------|------|--------------|
| `forja-scout` | locate code, layer verdict, trackers, tests — evidence only | no |
| `forja-architect` | plan past the status quo, placement, docs to file | no |
| `forja-flutter-engineer` | `apps/forja`, `packages/forja_foundation` | yes |
| `forja-rust-engineer` | `crates/*`, `packages/rust` | yes |
| `forja-web-engineer` | `apps/web`, TS packages, Supabase migrations (create only) | yes |
| `forja-qa` | run the ladder, separate regressions from baseline | no |
| `forja-law-reviewer` | findings with `path:line` + rule file, verdict | no |
| `forja-docs-keeper` | changelog, issue/RFC tags + README rows, feature guide | docs only |

## Hooks (`.claude/settings.json` → `.claude/hooks/`)

| Event | Script | Effect |
|-------|--------|--------|
| SessionStart | `session-start.sh` | injects app/engine versions, codename, active drafts, toolchain presence, packs checkout |
| PreToolUse Bash | `guard-bash.sh` | deny: Supabase reset/push/link, reset script, `git stash`, force-push, secrets reads, backlog/done edits, Cursor trailers · ask: commit/push, release/version scripts, full app test suite, recursive deletes |
| PreToolUse Edit/Write | `guard-edit.sh` | deny: `docs/backlog`, `docs/changelog/done`, shipped migrations, deleted shim tree, `.claude/skills` (symlink), `.env` · ask: `fixed/` and `canceled/` docs |
| PostToolUse Edit/Write | `post-edit.sh` | `dart format` / `rustfmt`; **blocks** foundation importing host/Riverpod, `ShellTokens.isTvLayout` in widgets, sync FFI outside allowlist, playback surface branches, per-crate versions, status tag ≠ body, bad changelog prefixes; **warns** on raw colors/blur/Switch/TextField/autofocus/clamps/copy words |
| Stop | `stop-changelog.sh` | once per session: product code changed but no draft bullet → asks for the bullet or an explicit "not user-visible" |

Patterns match only at command position, so prose that mentions a forbidden command passes; a shell command whose text contains one at that position is blocked (use the Write tool or base64 for such fixtures). Test: `bash <scratch>/hook_tests.sh` style — see `.claude/rules/claude-setup.md`.

## Permissions summary

Allowed without prompts: analyze/test/format/build for Flutter, Dart, Cargo, melos, pnpm lint/build; read-only git and `gh`; the `scripts/check_*` boundary scripts; read-only shell tools; docs fetches from Flutter/Dart/Rust/Supabase/GitHub domains; `dart` and `context7` MCP tools. Asked: commits, pushes, release/packaging/version scripts, `flutter build/run`, any `supabase` command, `npx`, `rm`. Denied: `.env` and signing material reads, database reset/push/link, `git stash`/force-push/hard reset, lockfile edits, backlog and frozen notes. `defaultMode` is `acceptEdits`; `../forja-packs` is an additional directory when present.

## MCP servers (`.mcp.json`)

| Server | Needs | Enabled by default |
|--------|-------|--------------------|
| `dart` — official Dart/Flutter MCP (`dart mcp-server`, SDK ≥ 3.9): analyze, tests, hot reload, widget tree of a running app | `dart` on PATH | yes |
| `context7` — current library docs (Flutter, Riverpod, media_kit, axum, tokio, TanStack) | npx | yes |
| `github` — issues/PRs on mGhassen/Forja | `GITHUB_PERSONAL_ACCESS_TOKEN` env | no — enable in `settings.local.json` |
| `supabase` — read-only project introspection | `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` env | no — read-only flag is deliberate |

Enable an optional server locally: add it to `enabledMcpjsonServers` in `.claude/settings.local.json` (gitignored).

## Run it locally

`/forja-run` holds the exact env exports and launch commands. `.claude/bootstrap-macos.sh` installs the whole toolchain on a fresh Apple Silicon Mac (Flutter, Rust, cmake, bash 5, JDK 21, Android SDK/NDK/emulator, AVDs `forja_phone` + `forja_tv`). Xcode.app must be installed by hand for the macOS/iOS targets. Packs install through `forja://install` deep links (see the skill) or Settings → Forja Packs.

## Repo analysis snapshot (2026-10-20, commit d2228f0c9)

- Monorepo: Flutter host `apps/forja` (574 Dart files, 204 test files, v2.0.35 "Serrajin"), design system `packages/forja_foundation` (201 files, 42 tests), Rust engine `crates/*` (18 active crates + archive, ~35k lines, workspace v3.1.4), web portal `apps/web` (React 19 / TanStack / Supabase, 73 migrations), `apps/tmdb-gateway`, `packages/forja-auth`. 2 570 commits, ~295 in the last 30 days, one primary author.
- Governance is unusually explicit: 23 Cursor rules, 6 skills, status-tagged RFC/issue/migration docs with README indexes, changelog drafts frozen by CI at tag time. The agent setup mirrors that governance instead of replacing it.
- All GitHub workflows are manual (`workflow_dispatch`), so the boundary scripts have drifted without anyone noticing. With `rg` on PATH they fail today: `check_tv_shell_boundary.sh` reports 21 hits (its allowlist still names the deleted `apps/forja/lib/shared/design/src/` files), `check_sync_ffi.sh` reports 23 unallowed `RustLib.instance` call sites (LAN services, portals, engine request) plus 2 stale allowlist rows, `check_foundation_import_zone.sh` expects `primitives/` and `theme/` dirs that no longer exist. When `rg` is absent the scripts print OK or exit 0 by accident. These are repo issues to file, not fixed here.
- On this machine `flutter`, `dart`, `cargo`, `melos` are not installed; `supabase`, `pnpm`, `node`, `gh`, `jq` are. The SessionStart hook reports this so no agent claims a green run it could not execute.
- `../forja-packs` (product packs) is not checked out; pack-dependent app tests fail for that reason alone.
