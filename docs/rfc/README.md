# Forja RFC Index

**Rules:** [docs-rfc-issues](../../.cursor/rules/docs-rfc-issues.mdc)

Every RFC filename includes a status tag matching `**Status:**` in the body.

| Tag | Body status | Meaning |
|-----|-------------|---------|
| `[draft]` | `draft` | Spec exists — **not scheduled**, not being worked |
| `[planned]` | `planned` | **You committed to build it** — not started yet |
| `[open]` | `open` | Actively in progress |
| `[partial]` | `partial` / `stub` | Code started, not shippable |
| `[fixed]` | `fixed` | Shipped — in `fixed/` |
| `[canceled]` | `canceled` | Won't build — in `canceled/` (document why) |

Do **not** mark `[planned]` just because an RFC mentions a future version. Use `[draft]` until you explicitly schedule the work.

Migration: [docs/migration/README.md](../migration/README.md) — [fixed/](migration/fixed/) phases 1–3

## Index

| File | Title | Version | Status | Progress | Backlog |
|------|-------|---------|--------|----------|---------|
| [001-[fixed]-…](fixed/001-[fixed]-monorepo.md) | Monorepo + feature boundaries | v1.0 | fixed | Complete · 4/4 | [0.0.1](../backlog/done/0.0.1-[done].md) |
| [002-[fixed]-…](fixed/002-[fixed]-iptv-groups.md) | IPTV portal groups | v1.0 | fixed | Complete · 4/4 | [0.0.1](../backlog/done/0.0.1-[done].md) |
| [003-[partial]-…](003-[partial]-player-overlay.md) | Player overlay + server grid | v1.1 | partial | 4/6 · 0/4 | [0.0.1](../backlog/done/0.0.1-[done].md) slice → [1.0.2](../backlog/1.0.2-[draft].md) |
| [004-[partial]-…](004-[partial]-provider-registry.md) | Stream provider registry | v1.0 / v1.1 | partial | 3/3 · 7/10 | [0.0.1](../backlog/done/0.0.1-[done].md) → [1.0.1](../backlog/1.0.1-[open].md) / [1.0.2](../backlog/1.0.2-[draft].md) |
| [005-[partial]-…](005-[partial]-casting.md) | AirPlay + Chromecast | v1.1 | stub | 0/1 · 0/4 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [006-[partial]-…](006-[partial]-supabase-sync.md) | Settings sync | v1.2 | partial | 2/3 · 3/4 · 4/5 · 8/8 · 7/8 · 8/8 · 3/3 · 3/3 · 2/5 | [1.0.4](../backlog/1.0.4-[draft].md) · [1.0.2](../backlog/1.0.2-[draft].md) RFC-036 |
| [007-[draft]-…](007-[draft]-lan-companion.md) | LAN remote API | v1.2 | draft | 0/4 | v2 |
| [008-[partial]-…](008-[partial]-watch-party.md) | Watch party sync | v1.2+ | stub | 0/4 | v2 |
| [009-[fixed]-…](fixed/009-[fixed]-rust-ffi.md) | Rust core FFI | v1.0 engine | fixed | Complete · 20/21 · 1 ⏭️ | [0.1.0](../backlog/done/0.1.0-[done].md)–[0.6.2](../backlog/done/0.6.2-[done].md) |
| [010-[draft]-…](010-[draft]-web-client.md) | Web client | v3.0 | draft | 0/5 | v3 |
| [011-[fixed]-…](fixed/011-[fixed]-v1.0-mvp.md) | v1.0 MVP | v1.0 | fixed | Complete · 13/14 | [0.0.1](../backlog/done/0.0.1-[done].md) |
| [012-[draft]-…](012-[draft]-v1.1-casting-providers.md) | v1.1 casting + providers | v1.1 | draft | 0/8 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [013-[draft]-…](013-[draft]-v1.2-sync-lan-party.md) | v1.2 sync + LAN party | v1.2 | draft | 0/6 | v2 |
| [014-[draft]-…](014-[draft]-v3-web-rust.md) | v3.0 web + Rust/WASM | v3.0 | draft | 0/5 | v3 |
| [015-[partial]-…](015-[partial]-in-app-updates.md) | In-app updates | v1.0 / v1.1 | partial | 7/7 · 11/13 · 3/3 · 2/2 · 5/5 · 5/6 · 1/1 · 3/3 · 2/3 · 4/4 · 4/4 · 1/1 · 2/2 · 1/1 | [0.0.1](../backlog/done/0.0.1-[done].md), [0.6.3](../backlog/done/0.6.3-[done].md), [1.0.1](../backlog/1.0.1-[open].md), [1.0.2](../backlog/1.0.2-[draft].md), [1.0.4](../backlog/1.0.4-[draft].md) |
| [016-[partial]-…](016-[partial]-lazy-tab-mounting.md) | Lazy tab mounting | v0.8.x | partial | 5/5 mount | [0.8.2](../backlog/done/0.8.2-[done].md) |
| [024-[partial]-…](024-[partial]-tab-cache-eviction-stale.md) | Tab cache eviction + stale | v0.8.x | partial | 21/22 · 1 ⏭️ | [0.8.2](../backlog/done/0.8.2-[done].md) · [1.0.1](../backlog/1.0.1-[open].md) |
| [017-[open]-…](017-[open]-deferred-engine-boot.md) | Deferred / profile-gated engine boot | v1.0.1 | open | 0/6 ⏭️ · 8/8 profile-gated · 3/3 switch=intro · 4/4 instant splash · **3/3 pack-gated** | [1.0.1](../backlog/1.0.1-[open].md) · [0.5.0](../backlog/done/0.5.0-[done].md) hist |
| [018-[draft]-…](018-[draft]-startup-splash-home.md) | Splash + Home perf | v1.0.1 | draft | 0/4 · 2 fetch · 3⏭️ | [0.5.0](../backlog/done/0.5.0-[done].md), [0.5.1](../backlog/done/0.5.1-[done].md) |
| [019-[draft]-…](019-[draft]-god-file-decomposition.md) | God file splits | v1.0.1 / v1.0.2 | draft | 5/5 | [1.0.1](../backlog/1.0.1-[draft].md) + [1.0.2](../backlog/1.0.2-[draft].md) |
| [020-[draft]-…](020-[draft]-media-details-routing.md) | Media details routing | v1.0.1 | draft | 3/4 | [RFC-026](026-[draft]-media-details-player-ux.md) |
| [026-[draft]-…](026-[draft]-media-details-player-ux.md) | Media details & player UX | v1.0.1 | partial | 18/19 · 28/34 | [1.0.1](../backlog/1.0.1-[open].md) |
| [021-[draft]-…](021-[draft]-release-ship-hygiene.md) | Release ship hygiene | v1.0 | draft | 1/8 · 2 🔄 · 1 ⏭️ | [1.0.2](../backlog/1.0.2-[draft].md) |
| [022-[open]-…](022-[open]-lan-server-client.md) | LAN server/client | post-v1.2 | open | 8/8 · 12/13 · 0/12 | [1.0.9](../backlog/1.0.9-[draft].md) · [1.0.1](../backlog/1.0.1-[open].md) |
| [023-[fixed]-…](fixed/023-[fixed]-app-shell-redesign.md) | App shell redesign | v0.8.x | fixed | Complete · 5/5 · 18/18 | [0.8.1](../backlog/done/0.8.1-[done].md) |
| [025-[fixed]-…](fixed/025-[fixed]-flat-cinematic-shell.md) | Flat cinematic shell & Home hero | v1.0.0 | fixed | Complete · 4/4 · 37/37 · 3/3 deferred | [1.0.0](../backlog/done/1.0.0-[done].md) |
| [027-[draft]-…](027-[draft]-iptv-channel-guide.md) | IPTV in-player channel guide | v1.0.2 | draft | 4/4 · 1/4 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [028-[draft]-…](028-[draft]-adaptive-shell-profiles.md) | Adaptive shell profiles | v1.0.1 | draft | 6/6 · 10/10 · 4/4 · 4/4 · 3/4 · 1/1 · 1/1 · 2/2 · 1/1 · 0/4 ⏭️ | [1.0.1](../backlog/1.0.1-[open].md) — leanback blocks `[fixed]` |
| [029-[open]-…](029-[open]-dual-built-in-playback-engines.md) | Dual built-in engines (MediaKit + ExoPlayer) | v1.0.2 | open | 4/4 · 1/8 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [030-[open]-…](030-[open]-playback-selection-engine.md) | Playback selection engine | v1.0.2 | open | 4/4 · 16/16 · 0/5 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [031-[open]-…](031-[open]-source-engine-middleware.md) | Source Engine middleware | v1.0.2 | open | 3/3 · 8/8 · 4/4 · 2/10 | [1.0.2](../backlog/1.0.2-[draft].md) → [1.0.3](../backlog/1.0.3-[draft].md) |
| [032-[open]-…](032-[open]-rust-resolver-engine.md) | Rust Resolver Engine | v1.0.3 | open | 8/8 · 12/15 | [1.0.3](../backlog/1.0.3-[draft].md) |
| [033-[open]-…](033-[open]-settings-ux-redesign.md) | Settings category-hub UX | v1.0.2 | open | 9/9 · 10/10 hub · 6/6 visibility · 3/3 TV · 1/1 resume · 1/6 Addons | [1.0.1](../backlog/1.0.1-[open].md) · [1.0.2](../backlog/1.0.2-[draft].md) |
| [034-[partial]-…](034-[partial]-web-portal-landing.md) | Web portal + landing + Flutter APIs | v1.0.4 | partial | 6/6 · 11/11 · 3/3 · 3/3 · 1/1 · 7/7 reset+confirm · 6/7 passkeys · 0/1 mobile ⏭️ | [1.0.2](../backlog/1.0.2-[draft].md) · [1.0.4](../backlog/1.0.4-[draft].md) |
| [035-[draft]-…](035-[draft]-design-system-controls.md) | Design-system controls consolidation | — | draft | 0/4 · 0/6 | [1.0.2](../backlog/1.0.2-[draft].md) deferred |
| [036-[open]-…](036-[open]-accounts-iptv-profile-settings.md) | Accounts hub, global IPTV, profile settings | v1.0.2 | open | 3/8 · 22/32 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [037-[open]-…](037-[open]-web-portal-i18n.md) | Web portal French + Arabic i18n | v1.0.4 | open | 0/4 · 0/8 · 1 ⏭️ | [1.0.4](../backlog/1.0.4-[draft].md) |
| [038-[open]-…](038-[open]-simple-streaming-resolve.md) | Simple streaming resolve (experimental) | v1.0.1 | open | 3/3 · 6/10 | [1.0.1](../backlog/1.0.1-[open].md) |
| [039-[fixed]-…](fixed/039-[fixed]-remote-provider-runtime-config.md) | Remote provider runtime config | v1.0.1 | fixed | Complete · 7/7 · 12/12 | [1.0.1](../backlog/1.0.1-[open].md) |
| [040-[open]-…](040-[open]-iptv-catalog-ops.md) | IPTV catalog ops (admin + worker + pool + credits) | v1.0.5 | open | 5/5 · 29/31 | [1.0.5](../backlog/1.0.5-[draft].md) |
| [041-[open]-…](041-[open]-iptv-live-epg-guide.md) | IPTV Live EPG guide view (catalog) | v1.0.6 | open | 4/4 · 0/6 | [1.0.6](../backlog/1.0.6-[draft].md) |
| [042-[open]-…](042-[open]-unified-auth-system.md) | Unified auth (web + Flutter) | v1.0.7 | open | 5/5 · 13/19 | [1.0.7](../backlog/1.0.7-[draft].md) |
| [043-[open]-…](043-[open]-crash-reporting-sentry.md) | Crash reporting (Sentry) + product analytics (PostHog) | v1.0 | open | 6/6 · 8/8 · 7/7 · 4/4 · 6/6 | [1.0.1](../backlog/1.0.1-[open].md) |
| [044-[open]-…](044-[open]-provider-identity-playback.md) | Provider-identity playback (end CDN host chase) | v1.0.1 | open | 11/11 · 21/21 unit · 0/3 manual | [1.0.1](../backlog/1.0.1-[open].md) |
| [045-[open]-…](045-[open]-stream-open-pipeline.md) | Stream open pipeline middleware | v1.0.1 | open | 6/6 · 6/8 | [1.0.1](../backlog/1.0.1-[open].md) |
| [046-[open]-…](046-[open]-android-tv-device-link.md) | Android TV device-code / QR account link | v1.0.7 | open | 5/5 · A 0/8 · net 1/1 | [1.0.7](../backlog/1.0.7-[draft].md) |
| [047-[open]-…](047-[open]-riverpod-state-migration.md) | Riverpod state / async loading migration | v1.x | open | 6/6 · … · **5/5** settings · **8/8** TV | [1.0.2](../backlog/1.0.2-[draft].md) deferred |
| [048-[fixed]-…](fixed/048-[fixed]-tv-focus-graph.md) | TV focus graph + screen recipes | v1.0.1 | fixed | Complete · 6/6 historical · 1/1 spatial C · 4/4 spatial A | [1.0.1](../backlog/1.0.1-[open].md) — B101-S132 ✅ · B101-S169 ✅ |
| [049-[open]-…](049-[open]-live-matches-mutstreams.md) | Live Matches MutStreams catalog | v1.0.1 | open | 3/3 · 4/5 | [1.0.1](../backlog/1.0.1-[open].md) — B101-S173 · smoke R49-A05 ⬜ |
| [050-[open]-…](050-[open]-stremio-addon-feature-targets.md) | Stremio feature targets + Live Matches sports | v1.0.1 | open | 4/4 · 8/10 | [1.0.1](../backlog/1.0.1-[open].md) — B101-S180 · B101-S182 · B101-S183 · smoke R50-A06 ⬜ · R50-A07 ⬜ |
| [051-[open]-…](051-[open]-iptv-multi-protocol-portals.md) | IPTV multi-protocol portals (Xtream / M3U / Stalker) | v1.0.8 | open | 7/7 · 18/19 · 7/7 · 3/3 | [1.0.8](../backlog/1.0.8-[draft].md) |
| [052-[canceled]-…](canceled/052-[canceled]-iptv-progress-aware-recovery.md) | Progress-aware IPTV playback recovery — abandoned; restored v1.3.114 | v1.0.1 | canceled | Canceled · hist 13/14 · 1/10 | [1.0.1](../backlog/1.0.1-[open].md) |
| [053-[partial]-…](053-[partial]-asian-drama-tmdb-details.md) | Asian Drama TMDB details enrichment | v1.0.1 | partial | 4/4 · 5/6 · 3/4 · 2/2 Sources | [1.0.1](../backlog/1.0.1-[open].md) — B101-S199 · B101-S210 · smoke R53-A06/A10 ⬜ |
| [054-[partial]-…](054-[partial]-torrent-search-providers.md) | Torrent search providers | v1.0.1 | partial | 9/9 · 15/16 | [1.0.1](../backlog/1.0.1-[open].md) — B101-S201 · B101-S269 · smoke R54-A06 ⬜ |
| [055-[open]-…](055-[open]-native-youtube-trailer-player.md) | Native YouTube trailer player (resolve + media_kit) | v1.0.1 | open | 3/3 · 14/18 | [1.0.1](../backlog/1.0.1-[open].md) — B101-S202 · B101-S211 · smoke R55-A06/A08/A10/A14 ⬜ |
| [056-[open]-…](056-[open]-installer-download-stats.md) | Installer download stats (admin) | v1.0.1 | open | 3/3 · 4/5 | [1.0.1](../backlog/1.0.1-[open].md) — B101-S214 · env R56-A03 ⬜ |
| [057-[partial]-…](057-[partial]-home-watch-provider-filter.md) | Home watch-provider filter | v1.4 | partial | 4/4 · 8/9 | [1.4.0](../backlog/1.4.0-[draft].md) |
| [058-[partial]-…](058-[partial]-structured-search.md) | Structured Search (person / genre / year / score) | v1.4 | partial | 3/3 · 5/6 · 5/5 · **4/4** kit capability | [1.4.0](../backlog/1.4.0-[draft].md) |
| [059-[fixed]-…](fixed/059-[fixed]-hub-list-follow.md) | Anime & Asian Drama list follow | v1.4 | fixed | Complete · 4/4 · 8/8 | [1.4.0](../backlog/1.4.0-[draft].md) |
| [060-[fixed]-…](fixed/060-[fixed]-enginejs-sources-forja-tab.md) | engineJS + Sources Forja tab | v1.3 | fixed | Complete · 78/80 · 2 ⏭️ | — |
| [061-[fixed]-…](fixed/061-[fixed]-engine-scraper-upstream-parity.md) | Engine scraper upstream parity | v1.3 | fixed | Complete · 4/4 · 10/12 · 2 ⏭️ | — |
| [062-[open]-…](062-[open]-native-iptv-sports-matching.md) | Native IPTV sports matching in Live Matches | v1.3 | open | 6/6 · 14/14 Xtream · 2/2 ATV · 4/4 Stalker · 1/1 EPG pad · 1/1 Mag ch_id · 0/3 M3U ⏭️ | — |
| [063-[fixed]-…](fixed/063-[fixed]-forja-auto-start-green-play.md) | Forja auto start (green Play) | v1.3 | fixed | Complete · 3/3 · 7/7 | — |
| [064-[open]-…](064-[open]-rust-quickjs-engine-runtime.md) | Forja EngineJS runtime (Forja Sources) | v1.3 | open | 7/7 · 11/14 | — |
| [065-[open]-…](065-[open]-live-forja-scrapers.md) | Live sports Forja scrapers | v1.3 | open | 7/7 · 21/25 · EngineJS→flutter_js unlock fallback · WebView GOAT+GASM 🔄 | — |
| [066-[fixed]-…](fixed/066-[fixed]-hub-catalog-top-bar.md) | Anime & Asian Drama hub catalog top bar | — | fixed | Complete · 4/4 · 8/8 | — |
| [067-[fixed]-…](fixed/067-[fixed]-forjahq-remote-plugin-pack.md) | ForjaHQ remote plugin pack (engine JS shell) | v1.4 | fixed | Complete · 5/5 · 10/10 | — |
| [068-[fixed]-…](fixed/068-[fixed]-engine-plugin-registry.md) | Engine PluginRegistry (pack-scoped install) | v1.4 | fixed | Complete · 5/5 · 10/10 | — |
| [069-[fixed]-…](fixed/069-[fixed]-official-plugins-split.md) | Official packs under `plugins/` (providers / live / catalog) | v1.4 | fixed | Complete · 4/4 · 8/8 | — |
| [070-[partial]-…](070-[partial]-catalog-hub-protocol.md) | Catalog hub protocol (shell tabs from `kind: catalog` plugins) | v1.4 | partial | 11/11 · 14/15 · 12/12 hub parity · **1/1** hub contribution · 4/4 host enrich · **6/6** enrich companion · 1/1 required packs · 6/6 shared cache · 2/2 host assets · **7/7** Arabic/open · **5/5** search capabilities · **5/5** My List host · **1/1** Live Sports hub · **5/5** Arabic-family chrome filters · **3/3** anime play audio · **1/1** hub Feature defaults | — |
| [071-[fixed]-…](fixed/071-[fixed]-live-sports-hub-kit.md) | Live Sports catalog hub kit | v1.4 | fixed | **Complete** · 9/9 · 21/21 | — |
| [072-[open]-…](072-[open]-iptv-vod-catalog-details.md) | IPTV VOD catalog details plugin + shared hub kit | v1.4 | open | 4/4 · 6/6 | — |
| [073-[open]-…](073-[open]-live-sports-kit-ownership.md) | Live Sports kit ownership (kill modes → kit browse → details + IPTV service) | v1.4 | open | **2/4** · **4/4** kill modes · **1/4** kit browse · **3/4** details+services | — |
| [074-[open]-…](074-[open]-remote-profile-plugin-install.md) | Remote profile plugin install and uninstall | v1.4 | open | **5/5** · **13/15** | — |
| [075-[fixed]-…](fixed/075-[fixed]-iptv-portal-probe-detail.md) | IPTV portal probe status + desktop detail card | v1.4 | fixed | **Complete** · 4/4 · 8/8 | — |
| [076-[fixed]-…](fixed/076-[fixed]-cartoon-hub-dimatoon.md) | كرتون hub (DimaToon) + provider blank.mp4 fix | v1.4 | fixed | **Complete** · 3/3 · 6/6 | — |
| [077-[fixed]-…](fixed/077-[fixed]-brstej-hub-laroza-only-arabic.md) | Brstej hub + Laroza-only Arabic | v1.4 | fixed | **Complete** · 3/3 · 7/7 | — |
| [078-[fixed]-…](fixed/078-[fixed]-kids-hub-dimakids.md) | Kids hub (Dimakids) + provider | v1.4 | fixed | **Complete** · 3/3 · 6/6 | — |
| [079-[open]-…](079-[open]-sources-id-middleware.md) | Sources ID middleware (catalog → providers / torrents / Stremio / Nuvio) | v1.4 | open | **4 / 4** · **8 / 8** | — |
| [080-[open]-…](080-[open]-post-login-packs-onboarding.md) | Post-login packs onboarding (`onboarded` + official install) | v1.4 | open | **5 / 5** · **11 / 11** | — |
| [081-[fixed]-…](fixed/081-[fixed]-host-only-platform-nav-defaults.md) | Host-only platform nav defaults (no pack hub ids in `PlatformDefaults`) | v1.4 | fixed | **Complete** · **2 / 2** · **6 / 6** | — |
| [082-[open]-…](082-[open]-account-profile-local-data-scope.md) | Account / profile / guest local data scope | v1.4 | open | **3 / 5** · **6 / 10** | — |
| [083-[fixed]-…](fixed/083-[fixed]-pack-manifest-bundle-list.md) | Pack manifest `bundle` file list install | v1.4 | fixed | **Complete** · **3 / 3** · **6 / 6** | — |
| [084-[open]-…](084-[open]-live-sports-host-feature-kit.md) | Live Sports host feature + kit standard layout | v1.4 | open | **5 / 5** · **11 / 11** | — |

## Related

- [Architecture](../architecture/README.md) — [feature file map](../architecture/feature-file-map.md) (god-file inventory + extraction phases)
- [Issues](../issues/README.md)
- [Backlog](../backlog/README.md)
- [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md)
