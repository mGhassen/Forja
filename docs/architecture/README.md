# Architecture index

Cross-cutting architecture docs for the Forja Flutter app. **Code is source of truth** — refresh line counts when god files grow.

## Documents

| Doc | Purpose |
|-----|---------|
| [Feature file map](feature-file-map.md) | Full `features/` inventory, tier classification, target folder trees, phased extraction roadmap (Phases A–E) |
| [Services map](services-map.md) | Service/API inventory — engine vs host vs hub catalog placement |
| [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) | Rust FFI / isolate boundary |
| [Features (user guide)](../features/README.md) | How the app works for users — not progress tracking |

## Related RFCs

| RFC | Topic |
|-----|-------|
| [RFC-019](../rfc/019-[draft]-god-file-decomposition.md) | God-file splits — line budget, target layouts, migration order |
| [RFC-026](../rfc/026-[draft]-media-details-player-ux.md) | Media details + player UX; shared `media_details/` widgets |
| [RFC-028](../rfc/028-[draft]-adaptive-shell-profiles.md) | `ShellProfile`, `ShellMetrics`, `ShellInputPolicy`, TV coordinator |
| [RFC-048](../rfc/fixed/048-[fixed]-tv-focus-graph.md) | `TvFocusGraph` + screen recipes (Home / hubs / Search / Live Matches / IPTV / player overlays) |
| [RFC-025](../rfc/fixed/025-[fixed]-flat-cinematic-shell.md) | Design tokens, flat cinematic shell |

## Three layers (feature code)

| Layer | Location | Use in widgets |
|-------|----------|----------------|
| **Shell / profile** | `shared/design/`, `shell/adapters/`, `shared/tv/` | `ShellScope.metricsOf`, `ShellScope.inputPolicyOf` — never `ShellTokens.isTvLayout` |
| **Shared presentation** | `shared/widgets/` — `hero/`, `media_details/`, `hub/` | Reusable UI; screen passes data + callbacks |
| **Tab browse** | `features/<name>/` | Orchestrator screens (&lt;800 lines target), `widgets/`, `catalog/`, `controller/` |
| **Media routes** | `features/media/` | TMDB-global details + Stremio catalog screens — entry via `AppRouter` |

## Cursor rules

- [forja-shared-ui.mdc](../../.cursor/rules/forja-shared-ui.mdc) — when to extract to `shared/widgets/`
- [forja-design-system.mdc](../../.cursor/rules/forja-design-system.mdc) — tokens, buttons, TV focus patterns
- [forja-tv-scope.mdc](../../.cursor/rules/forja-tv-scope.mdc) — supported TV tabs for D-pad QA

## Backlog

God-file **code splits** are deferred in [1.0.1](../backlog/1.0.1-[open].md) (UX slice first). Use [feature-file-map.md](feature-file-map.md) **Decision guide** to pick Phase A–E when starting splits. Home + settings remainder scheduled in [1.0.2](../backlog/1.0.2-[draft].md) (B102-S05).
