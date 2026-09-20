# Forja — agent working rules

**The rules live in [`.cursor/rules/`](.cursor/rules/) and [`.cursor/skills/`](.cursor/skills/). They are editor-neutral — they apply here too.** This file carries the always-on laws inline (Cursor's `alwaysApply: true` has no auto-load equivalent in Claude Code) and points to the rest.

`.claude/skills` is a **symlink** to `.cursor/skills`, so both editors load the same six skills from one source. Edit the skill in `.cursor/skills/`. Never add a parallel copy under `.claude/`.

Do not fork rule text into this file. When a rule changes, it changes in `.cursor/rules/`.

---

## Always-on laws (apply every turn)

### Honesty — [honesty-and-completion.mdc](.cursor/rules/honesty-and-completion.mdc)

- Never claim something is fixed, done, tested, or verified unless it is true in code **right now**.
- Never answer from memory or prior conversation. **Read the source first** — grep, open the file, run the command. Cite paths and line numbers you actually read.
- Docs are not proof. Code is.
- **Symptom fix ≠ root fix.** Say which one you shipped, every time. Workarounds need permission first: explain the symptom fix, the root fix, why the workaround, and what the user loses.
- Finish the stated scope or stop and ask. No silent half-fixes.
- End fix work with a plain report: symptom fix · root fix (or linked open issue) · workaround yes/no · issue file status.

### Never hide as a fix — [no-hide-as-fix.mdc](.cursor/rules/no-hide-as-fix.mdc)

Fixing a bug never means hiding, removing, disabling, or force-defaulting a user-facing option. If you think a hide is the only safe path — **stop and ask**.

### Changelog — [changelog.mdc](.cursor/rules/changelog.mdc) · skill `forja-changelog`

User-visible change → update the active `docs/changelog/*-[draft].md` **in the same turn as the code**. Prefixes only: `**Add:**` · `**Change:**` · `**Fix:**` · `**Remove:**`. Final truth only — edit or delete bullets, never log wrong attempts. No file paths, issue IDs, or crate names. One bullet per user story; don't inflate the list.

### Docs lifecycle — [docs-rfc-issues.mdc](.cursor/rules/docs-rfc-issues.mdc) · skill `forja-docs-rfc-issues`

Filename status tag must match `**Status:**` in the body. Same turn: rename + body + README + cross-links. Task tables are append-only. **Substantial untracked work → file an issue** (same turn as starting). Never touch `docs/backlog/` unless asked.

### User-facing copy — [user-facing-copy-truth.mdc](.cursor/rules/user-facing-copy-truth.mdc) · skill `forja-user-facing-copy`

Product strings say what the thing does **now**. No "only / no longer / formerly", no architecture lectures, no stale provider lists.

### Writing — [simple-writing.mdc](.cursor/rules/simple-writing.mdc) · skill `forja-simple-writing`

Short sentences. One claim each. Lead with the answer. Banned: contrarian openers, "Not X — Y" cadence, hedge fog ("should work", "mostly fixed"), empty scaffolding ("Here's how…"), list inflation, bold/emoji theater.

### Expert-first — [expert-first.mdc](.cursor/rules/expert-first.mdc) · [plan-better-than-status-quo.mdc](.cursor/rules/plan-better-than-status-quo.mdc)

Asked "what should Forja do?" → recommend the best answer, then verify, then implement. Never answer "how it works today" to a "what's best" question. Plans design **past** current Forja; a gap is one line of target design, never "we can't".

### Git — [git-attribution.mdc](.cursor/rules/git-attribution.mdc)

No Cursor attribution trailers in commits, PRs, or code comments.

**Do not stage or commit unless asked.** Leave finished edits unstaged — this repo's owner builds and tests on device before accepting work. Never `git stash` this tree to get a baseline; use a detached worktree (and see the test caveat below).

---

## Read before you touch these areas

Cursor auto-loads these by glob. Here, load them yourself.

| Touching | Read first |
|----------|-----------|
| Any Dart paint / widget / tokens / colors | [forja-design-system.mdc](.cursor/rules/forja-design-system.mdc) · [forja-foundation-no-hardcode.mdc](.cursor/rules/forja-foundation-no-hardcode.mdc) |
| D-pad, focus, TV, **any text or search field** | [forja-tv-scope.mdc](.cursor/rules/forja-tv-scope.mdc) |
| Shared hero / media-details components | [forja-shared-ui.mdc](.cursor/rules/forja-shared-ui.mdc) |
| Pack vs host vs foundation placement, kit painter | [forja-pack-product-host.mdc](.cursor/rules/forja-pack-product-host.mdc) · skill `forja-pack-product-host` |
| Live Sports resolve / unlock / catalog | [no-embed-playback.mdc](.cursor/rules/no-embed-playback.mdc) · [live-catalog-schedule-only.mdc](.cursor/rules/live-catalog-schedule-only.mdc) · skill `forja-live-native-playback` |
| `apps/forja/test/**` | [forja-host-tests-no-pack-contracts.mdc](.cursor/rules/forja-host-tests-no-pack-contracts.mdc) |
| Rust engine / crates | [rust-migration.mdc](.cursor/rules/rust-migration.mdc) · [rust-engine-versioning.mdc](.cursor/rules/rust-engine-versioning.mdc) |
| Supabase | [supabase-migrations.mdc](.cursor/rules/supabase-migrations.mdc) |
| Feature scope questions | [forja-feature-scope.mdc](.cursor/rules/forja-feature-scope.mdc) |

### Two that bite hardest

**Text inputs (desktop + TV).** Keyboard / D-pad focus on a text field **only highlights**. It must never open the IME, enter edit mode, expand search, or submit. Activate on OK / Enter / click only. A raw `TextField` that takes focus on desktop or TV is forbidden — use `TvBrowseTextField` / `SettingsTextField`, or give the design-system widget a field-builder prop and let the host pass one.

**No magic numbers in foundation paint.** Reused sizes, clamps, radii, and density go in `packages/forja_foundation/lib/tokens/*`. Prefer `ForjaShellColors` tokens over raw `Colors.white54`.

---

## Repo map

| Path | What |
|------|------|
| `apps/forja/` | Flutter app — thin shell chassis + engine hosts. Not a second design system. |
| `packages/forja_foundation/` | Design system — paint only, props + callbacks, no product Riverpod |
| `crates/` | Rust engine (ffi) |
| `apps/web/` | Web account portal (React) |
| `docs/` | `changelog/` `issues/` `rfc/` `features/` `migration/` — all have a README index |
| `../forja-packs/` | Hub packs (**sibling repo**, product lives here) |

Melos workspace; scripts in `melos.yaml` (`rust:build`, `rust:test`, …).

## Build and test

```bash
cd packages/forja_foundation && flutter analyze && flutter test   # fast, ~2s + ~2s
cd apps/forja               && flutter analyze                    # ~6s
cd apps/forja               && flutter test                        # slow — 10+ min
```

**Known-bad before you blame yourself:** on a clean `main`-line checkout the `apps/forja` suite already fails ~30 tests — `catalog_protocol_test.dart`, `sources_panel_filters_nuvio_lazy_test.dart`, and a 10-minute timeout in `forja_logo_halo_pixels_test.dart`. Verify a baseline before attributing a failure to your change.

The app suite reads the **sibling** `../forja-packs` tree. A git worktree created outside `~/Workspace` reports extra failures for that reason alone — it is not a real regression.
