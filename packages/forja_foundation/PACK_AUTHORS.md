# Pack authors — kit layout wire (RFC-106)

Layout JSON types are **frozen**. The Dart design-system package cutover does
**not** require pack JSON changes.

## Art URLs (mandatory)

`poster`, `background`, and `logo` on meta (and episode `videos[].thumbnail`)
must be **absolute `https://` URLs**. Never emit relative TMDB paths like
`/abc.jpg` or `/t/p/w500/…` — host will not resolve them via `TmdbApi`.

Title logos: prefer English (or lang-null) from TMDB `images.logos`, as
`https://image.tmdb.org/t/p/w500` + `file_path`.

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
alias in `LayoutTypes.normalize`.
