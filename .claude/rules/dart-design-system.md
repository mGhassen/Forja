---
paths:
  - "apps/forja/lib/**/*.dart"
  - "packages/forja_foundation/**/*.dart"
---

# Dart paint / widgets / tokens — read the full rules before editing

Read now, in this order (the law text lives there, not here):

1. `.cursor/rules/forja-design-system.mdc` — tokens, colors, buttons, flat cinematic shell, text inputs
2. `.cursor/rules/forja-foundation-no-hardcode.mdc` — reused sizes/clamps/radii → `packages/forja_foundation/lib/tokens/*`
3. `.cursor/rules/forja-shared-ui.mdc` — hero / media-details extraction map

Hard lines the `post-edit` hook blocks on: `package:forja/` or Riverpod inside `forja_foundation`, `ShellTokens.isTvLayout` in widgets, imports of the deleted `shared/foundation/` shim, `RustLib.instance` outside the allowlist. It warns on raw `Colors.whiteNN`, `BackdropFilter`, raw `Switch`, raw `TextField`, `autofocus: true`, numeric clamp literals.

Import the foundation **file** you use, never the `forja_foundation.dart` gallery barrel. Foundation widgets take props + callbacks only.
