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
| [1.3.x-[draft].md](1.3.x-[draft].md) | Elblat | v1.3.9 | drafting |

## Released

| Version | Codename | File |
|---------|----------|------|
| 1.3.9 | Elblat | [done/1.3.9-[released].md](done/1.3.9-[released].md) |
| 1.3.0 | Elblat | [done/1.3.0-[released].md](done/1.3.0-[released].md) |
| 1.2.434 | Dabaghin | [done/1.2.434-[released].md](done/1.2.434-[released].md) |
| 1.2.406 | Dabaghin | [done/1.2.406-[released].md](done/1.2.406-[released].md) |
| 1.2.403 | Dabaghin | [done/1.2.403-[released].md](done/1.2.403-[released].md) |
| 1.2.366 | Dabaghin | [done/1.2.366-[released].md](done/1.2.366-[released].md) |
| 1.2.365 | Dabaghin | [done/1.2.365-[released].md](done/1.2.365-[released].md) |
| 1.2.357 | Dabaghin | [done/1.2.357-[released].md](done/1.2.357-[released].md) |
| 1.2.342 | Dabaghin | [done/1.2.342-[released].md](done/1.2.342-[released].md) |
| 1.2.337 | Dabaghin | [done/1.2.337-[released].md](done/1.2.337-[released].md) |
| 1.2.336 | Dabaghin | [done/1.2.336-[released].md](done/1.2.336-[released].md) |
| 1.2.333 | Dabaghin | [done/1.2.333-[released].md](done/1.2.333-[released].md) |
| 1.2.308 | Dabaghin | [done/1.2.308-[released].md](done/1.2.308-[released].md) |
| 1.2.298 | Dabaghin | [done/1.2.298-[released].md](done/1.2.298-[released].md) |
| 1.2.283 | Dabaghin | [done/1.2.283-[released].md](done/1.2.283-[released].md) |
| 1.2.281 | Dabaghin | [done/1.2.281-[released].md](done/1.2.281-[released].md) |
| 1.2.267 | Dabaghin | [done/1.2.267-[released].md](done/1.2.267-[released].md) |
| 1.2.264 | Dabaghin | [done/1.2.264-[released].md](done/1.2.264-[released].md) |
| 1.2.222 | Dabaghin | [done/1.2.222-[released].md](done/1.2.222-[released].md) |
| 1.2.192 | Dabaghin | [done/1.2.192-[released].md](done/1.2.192-[released].md) |
| 1.2.186 | Dabaghin | [done/1.2.186-[released].md](done/1.2.186-[released].md) |
| 1.2.164 | Dabaghin | *(no changelog file — tracking starts after this tag)* |
