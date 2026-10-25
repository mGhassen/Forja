# Forja — agent working rules

**The rules live in [`.cursor/rules/`](.cursor/rules/) and [`.cursor/skills/`](.cursor/skills/). They are editor-neutral — they apply here too.** This file carries the always-on laws inline and points to the rest. The Claude Code layer (`.claude/`) adds what Cursor cannot express: path-scoped rule bridges, subagents, hooks, permissions, pipelines, MCP. Map: [`.claude/README.md`](.claude/README.md).

`.claude/skills` is a **symlink** to `.cursor/skills`, so both editors load the same skills from one source. Edit skills in `.cursor/skills/`. Never add a parallel copy under `.claude/`.

Do not fork rule text into this file. When a rule changes, it changes in `.cursor/rules/`; if its `globs` change, update the matching bridge in `.claude/rules/`.

---

## Always-on laws (apply every turn)

### Honesty — [honesty-and-completion.mdc](.cursor/rules/honesty-and-completion.mdc)

- Never claim something is fixed, done, tested, or verified unless it is true in code **right now**.
- Never answer from memory or prior conversation. **Read the source first** — grep, open the file, run the command. Cite paths and line numbers you actually read.
- Docs are not proof. Code is.
- **Symptom fix ≠ root fix.** Say which one you shipped, every time. Workarounds need permission first: explain the symptom fix, the root fix, why the workaround, and what the user loses.
- Finish the stated scope or stop and ask. No silent half-fixes.
- End fix work with a plain report: symptom fix · root fix (or linked open issue) · workaround yes/no · issue file status.
- If a toolchain is missing on this machine (the SessionStart hook says which), say the check could not run. Never report green you did not see.

### Never hide as a fix — [no-hide-as-fix.mdc](.cursor/rules/no-hide-as-fix.mdc)

Fixing a bug never means hiding, removing, disabling, or force-defaulting a user-facing option. If you think a hide is the only safe path — **stop and ask**.

### Changelog — [changelog.mdc](.cursor/rules/changelog.mdc) · skill `forja-changelog`

User-visible change → update the active `docs/changelog/*-[draft].md` **in the same turn as the code**. Prefixes only: `**Add:**` · `**Change:**` · `**Fix:**` · `**Remove:**`. Final truth only — edit or delete bullets, never log wrong attempts. No file paths, issue IDs, or crate names. One bullet per user story; don't inflate the list. The Stop hook asks once per session when product code changed without a bullet.

### Docs lifecycle — [docs-rfc-issues.mdc](.cursor/rules/docs-rfc-issues.mdc) · skill `forja-docs-rfc-issues`

Filename status tag must match `**Status:**` in the body. Same turn: rename + body + README + cross-links. Task tables are append-only. **Substantial untracked work → file an issue** (same turn as starting; `/forja-issue`). Never touch `docs/backlog/` unless asked.

### User-facing copy — [user-facing-copy-truth.mdc](.cursor/rules/user-facing-copy-truth.mdc) · skill `forja-user-facing-copy`

Product strings say what the thing does **now**. No "only / no longer / formerly", no architecture lectures, no stale provider lists.

### Answer the question — [answer-the-question.mdc](.cursor/rules/answer-the-question.mdc)

The first sentence is the answer. Then stop. Do not explain anything the user did not ask.

### Writing — [simple-writing.mdc](.cursor/rules/simple-writing.mdc) · skill `forja-simple-writing`

Short sentences. One claim each. Lead with the answer. Banned: contrarian openers, "Not X — Y" cadence, hedge fog ("should work", "mostly fixed"), empty scaffolding ("Here's how…"), list inflation, bold/emoji theater.

### Expert-first — [expert-first.mdc](.cursor/rules/expert-first.mdc) · [plan-better-than-status-quo.mdc](.cursor/rules/plan-better-than-status-quo.mdc)

Asked "what should Forja do?" → recommend the best answer, then verify, then implement. Never answer "how it works today" to a "what's best" question. Plans design **past** current Forja; a gap is one line of target design, never "we can't".

### Scope — [forja-feature-scope.mdc](.cursor/rules/forja-feature-scope.mdc) · [forja-pack-product-host.mdc](.cursor/rules/forja-pack-product-host.mdc)

In-scope tabs: Search, Home, Anime, Asian Drama, IPTV, Live Sports, Lists, Settings, plus the player/shell/sources they share. **Pack vs host first:** packs (`forja-packs`) own product UX; host owns generic engines + paints pack props only — never invent My List / Simkl / hub chrome in host (see pack-product-host sniff tests). Live Sports: native play URL or nothing ([no-embed-playback.mdc](.cursor/rules/no-embed-playback.mdc)), catalog rows carry schedule only ([live-catalog-schedule-only.mdc](.cursor/rules/live-catalog-schedule-only.mdc)).

### Git — [git-attribution.mdc](.cursor/rules/git-attribution.mdc)

No Cursor attribution trailers in commits, PRs, or code comments.

**Do not stage or commit unless asked.** Leave finished edits unstaged — this repo's owner builds and tests on device before accepting work. Never `git stash` this tree to get a baseline; use a detached worktree (and see the test caveat below). Hooks deny `git stash` and force-push and ask before commit/push.

---

## Read before you touch these areas

`.claude/rules/*.md` auto-load a bridge when you open matching files; the bridge names the `.mdc` to read. Read it before the first edit.

| Touching | Read first |
|----------|-----------|
| Any Dart paint / widget / tokens / colors | [forja-design-system.mdc](.cursor/rules/forja-design-system.mdc) · [forja-foundation-no-hardcode.mdc](.cursor/rules/forja-foundation-no-hardcode.mdc) |
| D-pad, focus, TV, **any text or search field** | [forja-tv-scope.mdc](.cursor/rules/forja-tv-scope.mdc) · skill `/forja-tv-dpad` |
| Shared hero / media-details components | [forja-shared-ui.mdc](.cursor/rules/forja-shared-ui.mdc) |
| Pack vs host vs foundation placement, kit painter | [forja-pack-product-host.mdc](.cursor/rules/forja-pack-product-host.mdc) · skill `forja-pack-product-host` |
| `apps/forja/lib/shared/playback/**` | [forja-playback-host-generic.mdc](.cursor/rules/forja-playback-host-generic.mdc) |
| Live Sports resolve / unlock / catalog | skill `forja-live-native-playback` |
| `apps/forja/test/**` | [forja-host-tests-no-pack-contracts.mdc](.cursor/rules/forja-host-tests-no-pack-contracts.mdc) |
| Rust engine / crates | [rust-migration.mdc](.cursor/rules/rust-migration.mdc) · [rust-engine-versioning.mdc](.cursor/rules/rust-engine-versioning.mdc) · [docs/ENGINE_BOUNDARY.md](docs/ENGINE_BOUNDARY.md) · skill `/forja-rust-engine` |
| Supabase | [supabase-migrations.mdc](.cursor/rules/supabase-migrations.mdc) |
| Web portal (`apps/web`) | [.claude/rules/web-portal.md](.claude/rules/web-portal.md) |

### Two that bite hardest

**Text inputs.** Leanback TV: D-pad focus on a text field **only highlights** — activate on OK / Enter / click. Desktop and phone: type on focus. Use `TvBrowseTextField` / `SettingsTextField` (gate via `browseTextUntilActivate`), or give the design-system widget a field-builder prop and let the host pass one.

**No magic numbers in foundation paint.** Reused sizes, clamps, radii, and density go in `packages/forja_foundation/lib/tokens/*`. Prefer `ForjaShellColors` tokens over raw `Colors.white54`.

---

## Repo map

| Path | What |
|------|------|
| `apps/forja/` | Flutter app — thin shell chassis + engine hosts (`app/ shell/ shared/ features/{account,settings}`). Not a second design system. |
| `packages/forja_foundation/` | Design system — paint only, props + callbacks, no product Riverpod (`tokens/ components/ widgets/ blocks/ brand/ protocol/`) |
| `packages/rust/` | Dart FFI bridge to `libffi` + parity tests (permanent) |
| `crates/` | Rust engine workspace → `libffi` (`ffi` aggregates domain crates; `archive/` not linked). Workspace version = engine version. |
| `apps/web/` | Web account portal — React 19, TanStack Start/Router, Vite, Tailwind 4, Supabase (73 migrations, production) |
| `apps/tmdb-gateway/` · `packages/forja-auth/` | Vercel function · shared TS auth helpers |
| `apps/archive/` · `crates/archive/` · `docs/features/archive/` | Out-of-scope verticals, kept for reference |
| `docs/` | `changelog/` `issues/` `rfc/` `migration/` `features/` `architecture/` — all have a README index; `backlog/` is frozen |
| `scripts/` | build/release/check scripts; `check_*.sh` are the boundary gates CI runs |
| `../forja-packs/` | Hub packs (**sibling repo**, product lives here; `FORJA_PACKS_ROOT` overrides) |

Melos workspace; scripts in `melos.yaml` (`rust:build`, `rust:test`, `rust:check-*`, …).

## Build and test

```bash
cd packages/forja_foundation && flutter analyze && flutter test   # fast, ~2s + ~2s
cd apps/forja               && flutter analyze                    # ~6s
cd apps/forja               && flutter test test/<x>_test.dart    # targeted; full suite is 10+ min
source scripts/lib/macos_rust_sdk.sh && cd crates && cargo test --workspace && cargo clippy --workspace
./scripts/check_tv_shell_boundary.sh; ./scripts/check_foundation_import_zone.sh; ./scripts/check_sync_ffi.sh; ./scripts/check_foundation_shim_alive.sh
```

**Known-bad before you blame yourself:** on a clean `main`-line checkout the `apps/forja` suite already fails ~30 tests — `catalog_protocol_test.dart`, `sources_panel_filters_nuvio_lazy_test.dart`, and a 10-minute timeout in `forja_logo_halo_pixels_test.dart`. The four `check_*.sh` scripts also fail on `main` today (stale allowlists, deleted zone dirs) and need `rg` on PATH to report anything at all. Verify a baseline before attributing a failure to your change. `/forja-verify` encodes this ladder.

The app suite reads the **sibling** `../forja-packs` tree. A git worktree created elsewhere reports extra failures for that reason alone — it is not a real regression.

## Claude Code layer

| Piece | Where | Use |
|-------|-------|-----|
| Pipelines | `/forja-fix`, `/forja-feature`, `/forja-verify`, `/forja-review`, `/forja-issue`, `/forja-rust-engine`, `/forja-tv-dpad` | the default way to run a bug fix, feature, verification, review |
| Subagents | `.claude/agents/` — `forja-scout`, `forja-architect`, `forja-flutter-engineer`, `forja-rust-engineer`, `forja-web-engineer`, `forja-qa`, `forja-law-reviewer`, `forja-docs-keeper` | locate → plan → implement by layer → verify → review → docs |
| Hooks | `.claude/hooks/` | block Supabase resets, `git stash`, secrets, frozen docs, foundation/TV/FFI boundary leaks, status-tag mismatches; nudge changelog |
| Permissions | `.claude/settings.json` | analyze/test/format/read-only git run freely; commit, push, release, `supabase`, `rm` ask; destructive ops denied |
| Workflow | `.claude/workflows/forja-law-review.js` | thorough multi-agent law review (`/forja-review --thorough`) |
| MCP | `.mcp.json` | `dart` (official SDK server) and `context7` on; `github` and `supabase` (read-only) need tokens |
