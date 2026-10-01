# Widget convergences (RFC-106 G7 · RFC-109 catalog slots)

Dual stacks that used to fork in host chrome map to one naming pair in this package:

| Concern | Package widgets |
|---------|-----------------|
| Hub catalog hero (carousel) | `CinematicHero` + `CinematicHeroSlide` + `RotatingHeroBackdrop` / `KenBurnsBackdrop` |
| Details hero (single title) | `DetailsHero` + same backdrop primitives |
| Posters | `PosterFrame` + `PosterRail` + `InteractivePosterCard` |
| Continue / Because / Mood | `ContinueSection` · `BecauseSection` · `MoodSection` (+ `MoodCircle`) |

Do not add parallel hero/poster families. Host kit mounts these props-only widgets via `PackPaintTree` / `kit/paint_*.dart`.
