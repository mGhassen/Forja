# Pack authors — kit layout wire (RFC-106)

Layout JSON types are **frozen**. The Dart design-system package cutover does
**not** require pack JSON changes.

## Keep emitting

| Type | Host mounts |
|------|-------------|
| `kit.stack` / `stack` | composition root |
| `kit.menu` / `menu` | menu |
| `kit.tabs` / `tabs` | tabs (`style: kind` → menu) |
| `kit.list` / `my_list` / `host.my_list` | list |
| `kit.row` / `rail` / `ranked` | row |
| `kit.topBar` / `topBar` | top bar |
| `kit.categoryBar` / `kinds` | category bar |
| `hero` / `cinematic_hero` | catalog / cinematic hero |
| `mood` | mood section |
| `continue` / `host.continue` | continue section |
| `because` / `host.because` | because section |
| `vertical_filters` / `host.vertical_filters` / `watch_providers` | `VerticalMenu` + `LogoMenuRail` |

Optional new alias `kit.verticalMenu` is **not** required.

If a type string must change, land a forja-packs PR **before** removing the
alias in `KitTypes.normalize`.
