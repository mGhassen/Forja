# Migrating to `forja_foundation` (RFC-106)

App code imports the **file for the widget**, not the root barrel.

```dart
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/kit/kit_types.dart';
```

`forja_foundation.dart` is a gallery/test barrel. Do not import it next to
`material.dart` (that is what produced the `hide Switch, Chip, …` lists).

Full export list: `docs/rfc/106-export-inventory.txt`. Pack wire: [PACK_AUTHORS.md](PACK_AUTHORS.md).

## Symbol map

| Old | New |
|-----|-----|
| `ForjaGhostButton` | `Button(variant: ghost)` |
| `ForjaPlainIcon` | `Button(variant: plainIcon, size: icon)` |
| `ForjaIconButton` | `Button(size: icon)` / `Button(variant: outline, size: icon)` |
| `ForjaCloseButton` | `Button(variant: ghost, size: icon)` + close icon |
| `ForjaSwitch` | `Switch` (package; hide Material) |
| `VerticalFiltersRail` | `LogoMenuRail` + `VerticalMenu` (host rail wraps until PackAssets props-only) |
| `VerticalFiltersSpec` | host registry + `toLogoMenuItems()` |
| `DesignTokens` / `ForjaShellColors` | `ForjaThemeExtension` / package tokens |
| `ShellTokens` | package `ShellTokens` (+ host TV overrides where still needed) |
| `package:forja/shared/foundation/...` | `package:forja_foundation/...` |

## Compat (until G14-E)

- `package:forja/shared/foundation/compat_exports.dart`
- `package:forja/shared/foundation/ds_bridge.dart`
- Per-path re-export stubs (e.g. `lib/match_event.dart` → `shared/host/live_sports/`)

**Shim death** (delete `apps/forja/lib/shared/foundation/`) only after Q1–Q12 QA
and inventory greps — see RFC-106 A19. Per G14-G, that is a **separate** PR.

## Host APIs — do not replace `primitives.dart` wholesale

`package:forja_foundation` does **not** export host shell/TV/splash widgets.
Keep host imports for:

| Stay on host | Why |
|--------------|-----|
| `ForjaInteractive` / `ForjaPlainIcon` / `ForjaCloseButton.compact` | Package compat aliases are incomplete (no `color`/`size`/`compact`) — not barrel-exported |
| `ShellScope` / `shellScaled` / `shellUsesWideLayout` / `resolveShellProfile` | Host shell |
| `shellFocusableTap` / `shellRoundedInkHost` / `shellMenuItemStyle` | Host chrome |
| `TvBrowseTextField` / splash (`SplashLoadingDots`, …) / `ForjaToast` | Host-only |
| Host `ForjaNetworkImage` | Extra args (`alignment`, `useOldImageOnUrlChange`) |

Never add `import` lines to `part of` files — put them on the library parent.

Compat `Forja*` button aliases: import `package:forja_foundation/compat/legacy_buttons.dart` **explicitly**. The package barrel does not export them (they shadow host buttons).
