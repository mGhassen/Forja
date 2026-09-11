# forja_foundation

Forja design system package (RFC-106).

Tokens → theme → primitives → components → widgets → blocks, plus protocol / kit / platform / utils.

## Entry points

| Import | Use |
|--------|-----|
| `package:forja_foundation/forja_foundation.dart` | Full public API (sectioned) |
| `package:forja_foundation/forja_foundation_primitives.dart` | Leaf tokens / primitives / components |
| `package:forja_foundation/forja_foundation_kit.dart` | Protocol + kit + blocks |

## Zones

- **A (UI):** no Riverpod, no `features/**`, no `TmdbApi`
- **B (kit):** opaque contracts only — layout walk, registries, hooks

## Status

Part 1 scaffold: tokens (copied), `ForjaThemeExtension`, `Button` / `ButtonGroup` / `VerticalMenu`. See [MIGRATION.md](MIGRATION.md) and [RFC-106](../../docs/rfc/106-[open]-forja-foundation-design-system-package.md).

App still owns `apps/forja/lib/shared/foundation/` until Part 2 cutover. Prefer new APIs via `package:forja_foundation` or the thin `ds_bridge.dart` / `compat_exports.dart` shims.
