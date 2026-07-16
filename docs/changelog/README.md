# Changelog

User-facing release notes. **One in-progress file per minor line** (`X.Y.x`); frozen to the exact patch on ship.

**Rules:** [changelog](../../.cursor/rules/changelog.mdc) · codenames: [backlog](../backlog/README.md)

## Lifecycle

| Phase | File | Example |
|-------|------|---------|
| Drafting (pushes after last tag) | `X.Y.x-[draft].md` | `1.2.x-[draft].md` |
| Shipped (frozen at tag) | `done/X.Y.Z-[released].md` | `done/1.2.165-[released].md` |
| Next push batch | new empty `X.Y.x-[draft].md` | same minor until `X.(Y+1).0` |

Changelogs track **releases** (git tags), not individual commits. The draft filename uses **`x`** as a placeholder; the released filename uses the **exact** semver the admin ships. The version number is chosen by the **release admin** (CI bump / tag), and the codename comes from `kReleaseCodename` in `app_version.dart` — the changelog only carries the bullets.

**Groups:** Features · Player · UI · Sources · Live & IPTV · TV — see [rule](../../.cursor/rules/changelog.mdc#thematic-groups-forja).  
**Line prefixes (bold):** `**Add:**` · `**Change:**` · `**Fix:**` · `**Remove:**`

## Active

| File | Codename | Since tag | Status |
|------|----------|-----------|--------|
| [1.2.x-[draft].md](1.2.x-[draft].md) | Dabaghin | v1.2.222 | drafting |

## Released

| Version | Codename | File |
|---------|----------|------|
| 1.2.222 | Dabaghin | [done/1.2.222-[released].md](done/1.2.222-[released].md) |
| 1.2.192 | Dabaghin | [done/1.2.192-[released].md](done/1.2.192-[released].md) |
| 1.2.186 | Dabaghin | [done/1.2.186-[released].md](done/1.2.186-[released].md) |
| 1.2.164 | Dabaghin | *(no changelog file — tracking starts after this tag)* |
