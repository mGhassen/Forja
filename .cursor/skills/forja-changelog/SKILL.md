---
name: forja-changelog
description: >-
  Forja user-facing release changelog workflow. Draft X.Y.x bullets, freeze on
  tag, action prefixes, thematic groups, CI release body. Use when editing
  docs/changelog, shipping user-visible changes, writing release notes, or when
  the user mentions changelog, release notes, or draft bullets.
---

# Changelog management

Index: [docs/changelog](../../../docs/changelog/README.md)

Always-on law stub: [changelog.mdc](../../rules/changelog.mdc)

Changelogs are **user-facing release notes**, not a commit log. One **in-progress file per minor line** (`1.2.x`), frozen to the **exact patch** on ship (`1.2.165`), not per push.

**The changelog does not decide the version or codename.** The release admin picks the exact version at release time; the codename comes from `kReleaseCodename` in [`app_version.dart`](../../../apps/forja/lib/shared/services/update/app_version.dart). The changelog only carries the **bullets**.

## Golden rules

1. **One draft per minor arc** — while shipping `1.2.x` patches, all pushed work updates `docs/changelog/1.2.x-[draft].md` until the next tag.
2. **Same turn as code** — when a change is user-visible, update the active changelog in the **same turn** as code and [feature docs](../../../docs/features/README.md).
3. **Final truth only** — edit or remove bullets when a later push corrects or reverts earlier work. No history of wrong attempts.
4. **Short and readable** — complete for users, synthesized. No RFC/issue IDs, file paths, or implementation detail.
5. **Version & codename are external** — admin sets version at release; codename lives in `kReleaseCodename`. Never treat the changelog title as the source for either.

## Which file is active?

| App minor (`pubspec` / `kReleaseCodename`) | Draft file |
|--------------------------------------------|------------|
| `1.2.x` (today) | `docs/changelog/1.2.x-[draft].md` |
| `1.3.x` (future) | `docs/changelog/1.3.x-[draft].md` |

Minor bumps (`1.2` → `1.3`) start a **new** `X.Y.x-[draft].md`. Changelog draft name follows **app minor + `x`**.

## File lifecycle

```
pushing     →  docs/changelog/1.2.x-[draft].md
admin ships →  admin picks version (e.g. 1.2.165); CI builds release body from draft
freeze      →  docs/changelog/done/1.2.165-[released].md
next pushes →  docs/changelog/1.2.x-[draft].md (fresh; **Since release:** 1.2.165)
minor 1.3.0 →  update kReleaseCodename + new docs/changelog/1.3.x-[draft].md
```

On release (admin picks version, then git tag `vX.Y.Z`):

1. **Human:** Prune bullets that did not ship; wording must match the tagged build — **before** the release workflow (freeze snapshots the draft into the tag).
2. **CI:** `Release Forja` runs [`scripts/changelog_freeze.sh <version>`](../../../scripts/changelog_freeze.sh) in the version-bump step:
   - moves draft → `docs/changelog/done/X.Y.Z-[released].md` (`# X.Y.Z — <codename>`, `**Status:** released`)
   - refreshes [changelog README](../../../docs/changelog/README.md)
   - starts fresh empty `docs/changelog/X.Y.x-[draft].md` with `**Since release:**` — **no group headings** until the first bullet

Freeze is **idempotent**. Only run `changelog_freeze.sh` by hand if a tag was cut without it.

New minor: update `kReleaseCodename` + start `1.3.x-[draft].md`.

## CI integration (automatic release body)

`publish_release` runs [`scripts/changelog_release_notes.sh <version>`](../../../scripts/changelog_release_notes.sh):

- codename from `kReleaseCodename` (not changelog title)
- title `# <version> — <codename>`
- bullets from frozen `done/<version>-[released].md`, fallback to `{major}.{minor}.x-[draft].md`
- drops empty groups + scaffolding → GitHub Release body / in-app update dialog

If no draft / no bullets, CI falls back to `generate_release_notes` (raw commits). Keep bullets user-facing.

## When to add a bullet

| Change | Changelog? |
|--------|------------|
| New user-visible feature, screen, setting, provider | ✅ |
| Bug fix users would notice | ✅ |
| UX copy, layout, or behavior change users see | ✅ |
| Internal refactor, tests, CI, docs-only (no user impact) | ❌ |
| Workaround shipped — describe user impact honestly | ✅ |

Derive bullets from **what changed for the user**, not RFC/issue IDs.

## Writing style

- Audience: someone updating the app
- One line per item — [action prefix](#action-prefixes) then outcome
- Thematic groups — [groups](#thematic-groups-forja); add `### Group` only when that group has bullets
- Group related items into one bullet when they share one user story
- No task IDs, issue numbers, crate names, or internal refactors unless user-visible

## Action prefixes

Every bullet **must** start with one of these — **bold** Title case + colon:

| Prefix | Use when |
|--------|----------|
| `**Add:**` | New capability, screen, setting, provider, or option |
| `**Change:**` | Existing behavior or layout updated (not a bug) |
| `**Fix:**` | Bug or broken UX users would notice |
| `**Remove:**` | Something taken away |

Format: `- **Fix:** Live match embeds on Windows no longer open white.`

Do **not** invent extra verbs (`Improve:`, `Update:`, `Refactor:`). Map to the four above.

## Thematic groups (Forja)

Six groups — pick **one** per bullet. No sub-groups.

| Group | Use for | Examples |
|-------|---------|----------|
| **Features** | New screens, tabs, workflows, integrations | Anime hub, Cmd+F search, settings hub |
| **Player** | Playback, controls, subtitles, PiP, speed, next episode | Flat menus, seek preview |
| **UI** | Shell, home, details, nav, cards, hero, About | Home hero, details metadata |
| **Sources** | Stream providers, torrent, embeds, scrapers, debrid | VidSrc, dead-cache re-resolve |
| **Live & IPTV** | Live Sports, Xtream, M3U, sports/IPTV playback | Stream picker, channel grid |
| **TV** | Android TV, leanback, D-pad, TV-only shell | ATV tab focus |

**Engine / Rust:** no separate group. Phrase as Sources / Player / Features outcome.

**Platform-specific:** under the feature group (e.g. Windows live → **Live & IPTV**), not a “Windows” section.

### Template (draft file)

Start with no group headings. Add `###` when the first bullet for that group lands:

```markdown
### UI
- **Change:** …

### Sources
- **Add:** …
- **Fix:** …
```

### Good

```markdown
### Live & IPTV
- **Fix:** Live match embeds on Windows no longer open as a white transparent surface.

### Sources
- **Fix:** Auto-resolve skips dead cached links and tries the next server.
- **Add:** VidSrc.sbs as a stream provider.
```

### Bad

```markdown
### Fixed
- Issue 053: WebView2 transparent background workaround.

### Engine
- Renamed resolver-engine crate.

### UI
- Settings About cleaned up.
- Fix: missing bold on the prefix.
```

## Correcting earlier entries (mandatory)

| Situation | Action |
|-----------|--------|
| Fix changes user-visible outcome | **Edit** the existing bullet |
| Feature dropped or reverted before ship | **Remove** the bullet |
| Two pushes same fix | **One** bullet |
| Push A added X, push B removed X | **No bullet** for X |

## Relationship to other docs

| Layer | Purpose |
|-------|---------|
| **Changelog draft** | What users get in the **next** tagged release |
| **Changelog released** | Frozen notes for that exact `vX.Y.Z` tag |
| [Feature docs](../../../docs/features/README.md) | How to use what shipped |
| RFC / issue | Implementation status — not ship version |

Related skill: [forja-docs-rfc-issues](../forja-docs-rfc-issues/SKILL.md)

## Checklist (same turn as code)

- [ ] `docs/changelog/*-[draft].md` updated (add / edit / remove bullets)
- [ ] Bullets user-facing and match current code
- [ ] Before release workflow: bullets pruned to what ships
- [ ] Freeze / README / fresh draft are **automatic** via `changelog_freeze.sh` — backfill by hand only if a tag skipped it
