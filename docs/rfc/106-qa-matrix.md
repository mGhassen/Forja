# RFC-106 G14-E — QA matrix (before shim death)

Manual sign-off required. Automated gates below do **not** replace Q1–Q12.

| ID | Scenario | Auto gate | Manual |
|----|----------|-----------|--------|
| Q1 | Home: platforms menu, top-bar logo, hero, rails | `kit_types_wire_freeze` + vertical_filters normalize | ⬜ |
| Q2 | Anime / Asian Drama / kids / cartoon / arabic / aflem / shahid hubs | synthetic layout fixtures | ⬜ |
| Q3 | Live Sports list+cards, details, providers | host live_sports stubs compile | ⬜ |
| Q4 | Movie/TV details hero + play + sources | — | ⬜ |
| Q5 | IPTV portals + side panel | — | ⬜ |
| Q6 | Settings rows | — | ⬜ |
| Q7 | Player popup + volume slider | package Slider smoke | ⬜ |
| Q8 | TV focus≠activate; D-pad + VerticalMenu | `TvFocusPolicy` + import zone | ⬜ |
| Q9 | Search + my list status | — | ⬜ |
| Q10 | Update / pack install entry | — | ⬜ |
| Q11 | Archive screens that imported foundation | analyze on importers | ⬜ |
| Q12 | Cold boot: nav from packs | — | ⬜ |

## Shim tree

`apps/forja/lib/shared/foundation/` is **deleted** (A22). Dart `rg` empty.

Q1–Q12 below are still the visual sign-off (A18 / A19).
