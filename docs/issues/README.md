# Issues

**Rules:** [docs-rfc-issues](../../.cursor/rules/docs-rfc-issues.mdc) · [honesty](../../.cursor/rules/honesty-and-completion.mdc)

Every issue filename includes a status tag matching `**Status:**` in the body.

| Tag | Body status | Meaning |
|-----|-------------|---------|
| `[draft]` | `draft` | Filed, not being worked |
| `[open]` | `open` | Actively fixing |
| `[workaround]` | `workaround` | Symptom fix only |
| `[fixed]` | `fixed` | Root fixed — in `fixed/` |
| `[canceled]` | `canceled` | Won't fix — in `canceled/` (document why) |

```
file     →  NNN-[draft]-slug.md
fixing   →  NNN-[open]-slug.md
symptom  →  NNN-[workaround]-slug.md
fixed    →  fixed/NNN-[fixed]-slug.md
drop     →  canceled/NNN-[canceled]-slug.md
```

| File | Title | P | Sev | Status | Progress | Backlog |
|------|-------|---|-----|--------|----------|---------|
| [001-[fixed]-…](fixed/001-[fixed]-webstreamr-blocks-ui.md) | WebStreamr blocks UI thread | P1 | High | fixed | Complete | [0.4.2](../backlog/done/0.4.2-[done].md) |
| [002-[draft]-…](002-[draft]-torrent-disk-cache-not-cleaned.md) | Torrent cache never purged | P2 | High | draft | 0/6 | — |
| [003-[fixed]-…](fixed/003-[fixed]-stremio-platform-playback-model.md) | Stremio playback model | P2 | Medium | fixed | 7/7 | [0.2.0](../backlog/done/0.2.0-[done].md) |
| [004-[fixed]-…](fixed/004-[fixed]-sync-ffi-ui-thread-audit.md) | Sync FFI UI thread audit | P1 | High | fixed | 4/4 | [0.4.1](../backlog/done/0.4.1-[done].md) |
| [005-[fixed]-…](fixed/005-[fixed]-stremio-http-blocks-ui.md) | Stremio HTTP blocks UI | P1 | High | fixed | 1/2 · QA ⬜ | [0.4.2](../backlog/done/0.4.2-[done].md) |
| [006-[fixed]-…](fixed/006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md) | Vidsrc/Videasy blocks UI | P1 | High | fixed | 1/2 · QA ⬜ | [0.4.2](../backlog/done/0.4.2-[done].md) |
| [007-[fixed]-…](fixed/007-[fixed]-torrent-search-blocks-ui.md) | Torrent search blocks UI | P1 | High | fixed | 1/2 · QA ⬜ | [0.4.3](../backlog/done/0.4.3-[done].md) |
| [008-[fixed]-…](fixed/008-[fixed]-ci-enforce-no-sync-ffi.md) | CI reject sync FFI | P1 | High | fixed | 3/3 | [0.4.4](../backlog/done/0.4.4-[done].md) |
| [009-[fixed]-…](fixed/009-[fixed]-post-migration-resilience-audit.md) | Resilience audit | P2 | Medium | fixed | 3/5 | [0.4.4](../backlog/done/0.4.4-[done].md) |
| [010-[fixed]-…](fixed/010-[fixed]-webview-js-extractors-main-thread.md) | WebView extractors main thread | P2 | Medium | fixed | 3/3 | [0.4.3](../backlog/done/0.4.3-[done].md) |
| [011-[fixed]-…](fixed/011-[fixed]-kisskh-hls-sync-ffi.md) | Kisskh/HLS sync FFI | P2 | Medium | fixed | 2/2 | [0.4.3](../backlog/done/0.4.3-[done].md) |
| [012-[fixed]-…](fixed/012-[fixed]-mobile-magnet-e2e-p2-14.md) | Mobile magnet E2E | P2 | Medium | fixed | 3/3 | [0.4.5](../backlog/done/0.4.5-[done].md) |
| [013-[fixed]-…](fixed/013-[fixed]-site111477-captcha-still-dart.md) | 111477 Dart by design | P3 | Low | fixed | 2/2 | [0.4.5](../backlog/done/0.4.5-[done].md) |
| [014-[fixed]-…](fixed/014-[fixed]-iptv-reddit-catalog-cursor-loop.md) | IPTV Reddit cursor loop | P1 | High | fixed | Complete | [0.4.5](../backlog/done/0.4.5-[done].md) |
| [015-[fixed]-…](fixed/015-[fixed]-rust-blocking-http-engine-debt.md) | Rust blocking HTTP debt | P2 | Medium | fixed | 6/6 | [0.4.4](../backlog/done/0.4.4-[done].md) |
| [016-[fixed]-…](fixed/016-[fixed]-async-job-ffi-hard-cancel.md) | Async job FFI cancel | P2 | Medium | fixed | Complete | [0.4.0](../backlog/done/0.4.0-[done].md) |
| [017-[fixed]-…](fixed/017-[fixed]-webstreamr-stream-choice-button-missing.md) | WebStreamr stream-choice button | P2 | Medium | fixed | 4/4 | [0.4.5](../backlog/done/0.4.5-[done].md) |
| [018-[draft]-…](018-[draft]-migration-playback-parity-unverified.md) | Playback parity unverified | P1 | High | draft | 3/13 | [1.0.1](../backlog/1.0.1-[draft].md) |
| [019-[draft]-…](019-[draft]-webstreamr-enginejobs-e2e-test-gap.md) | WebStreamr E2E test gap | P2 | Medium | draft | 0/3 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [020-[draft]-…](020-[draft]-cancel-gen-token-discard-unverified.md) | Cancel gen-token unverified | P2 | Medium | draft | 0/3 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [021-[draft]-…](021-[draft]-catalog-vertical-import-smoke-unverified.md) | Catalog import smoke unverified | P3 | Low | draft | 0/3 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [022-[draft]-…](022-[draft]-playback-widget-integration-tests.md) | No playback widget tests | P3 | Low | draft | 0/3 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [023-[fixed]-…](fixed/023-[fixed]-packages-api-delete-blocked-host-relocation.md) | packages/api delete | P2 | Medium | fixed | 4/4 | [0.3.2](../backlog/done/0.3.2-[done].md) |
| [024-[open]-…](024-[open]-local-torrent-mpv-format-probe-race.md) | Local torrent mpv format probe race | P1 | High | open | 5/6 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [025-[open]-…](025-[open]-android-tv-leanback-smoke-unverified.md) | Android TV leanback smoke unverified | P1 | High | open | 6/14 | [1.0.1](../backlog/1.0.1-[open].md) |
| [026-[open]-…](026-[open]-lan-stream-playback-bearer-token.md) | LAN stream Bearer not sent to player | P1 | High | open | 0/2 · 0/2 | — |
| [027-[draft]-…](027-[draft]-lan-server-client-manual-qa.md) | RFC-022 LAN manual QA matrix | P2 | Medium | draft | 0/10 | — |
| [028-[draft]-…](028-[draft]-desktop-lan-client-not-implemented.md) | Desktop LAN client not implemented | P2 | Medium | draft | 0/3 · 0/2 | — |
| [029-[draft]-…](029-[draft]-lan-range-seek-unverified.md) | LAN range seek unverified | P3 | Low | draft | 0/2 | — |
| [030-[draft]-…](030-[draft]-lan-hdr-passthrough-unverified.md) | LAN HDR passthrough unverified | P3 | Low | draft | 0/1 | — |
| [031-[workaround]-…](031-[workaround]-android-tv-webview-gles-crash.md) | Android TV WebView GLES crash | P1 | High | workaround | 5/5 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [032-[draft]-…](032-[draft]-exoplayer-parity-gaps.md) | ExoPlayer vs media_kit parity gaps | P2 | Medium | draft | 5/11 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [033-[open]-…](033-[open]-vod-decoder-recovery.md) | VOD player decoder recovery | P2 | Medium | open | 4/5 | — |
| [034-[open]-…](034-[open]-windows-release-missing-libmpv.md) | Windows release missing libmpv | P1 | High | open | 3/4 · A 0/1 | — |
| [035-[fixed]-…](fixed/035-[fixed]-nuvio-torrent-scraper-in-direct-streaming.md) | Nuvio torrent scraper (Torrentio) in Direct Streaming | P1 | High | fixed | Complete · 7/7 | — |
| [036-[fixed]-…](fixed/036-[fixed]-vidsrc-cloudnestra-cdn-host-stale.md) | Vidsrc CDN host cloudnestra → dynamic | P1 | High | fixed | 2/2 · 2/2 | — |
| [037-[open]-…](037-[open]-webstreaming-all-providers-open-validate.md) | Webstreaming open-validate all providers | P1 | High | open | 8/9 · A 7/7 · smoke ⬜ | [1.0.1](../backlog/1.0.1-[open].md) |
| [038-[fixed]-…](fixed/038-[fixed]-webstreamr-resolver-drops-country-config.md) | WebStreamr Resolver drops country config | P1 | High | fixed | Complete · 3/3 · 2/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [039-[fixed]-…](fixed/039-[fixed]-resolver-missing-template-embed-plugins.md) | Resolver missing template embed plugins (WebView sniff) | P1 | High | fixed | Complete · 2/2 · 2/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [040-[fixed]-…](fixed/040-[fixed]-mpv-open-rejects-working-cdn-urls.md) | mpv open rejects working CDN mp4/HLS URLs | P1 | High | fixed | Complete · 5/5 · 4/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [041-[fixed]-…](fixed/041-[fixed]-videasy-hangs-before-cdn-yoru.md) | Videasy hangs on neon2 before Yoru/cdn | P1 | High | fixed | Complete · 4/4 · A 2/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [042-[fixed]-…](fixed/042-[fixed]-provider-reliability-not-global.md) | Provider reliability not global across titles | P1 | High | fixed | Complete · 5/5 · A 4/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [043-[fixed]-…](fixed/043-[fixed]-dead-cache-full-auto-reresolve.md) | Dead cache → full Auto re-resolve like first Play | P1 | High | fixed | Complete · 3/3 · A 2/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [044-[fixed]-…](fixed/044-[fixed]-settings-cache-data-cleaner.md) | Settings cache / data cleaner | P2 | Medium | fixed | — | — |
| [045-[open]-…](045-[open]-kisskh-extract-cache-pageload-cancel-races.md) | KissKh extract: cache + page-load wait + cancel races | P1 | High | open | 21/21 · A 0/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [046-[open]-…](046-[open]-streamed-live-embed-white-screen.md) | Streamed live embed white screen / unlimited loading | P1 | High | open | 5/5 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [048-[open]-…](048-[open]-vidsrc-sbs-iframe-playback-restricted.md) | VidSrc.sbs iframe playback restricted | P1 | High | open | 1/1 · A 1/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [047-[fixed]-…](fixed/047-[fixed]-vidsrc-vsembed-su-and-broken-plugin.md) | Vidsrc: broken plugin request + vsembed.su host | P1 | High | fixed | Complete · 3/3 · 2/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [049-[open]-…](049-[open]-live-embed-ad-hijack-crash.md) | Live embed ad main-frame hijack crash | P1 | High | open | 3/3 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [050-[fixed]-…](fixed/050-[fixed]-template-embed-one-file-per-plugin.md) | Template embed one file per plugin | P2 | Medium | fixed | Complete · 2/2 · 2/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [051-[open]-…](051-[open]-embed-multiserver-sniff-proxy-cookies.md) | Embed multi-server sniff / proxy body / cookies | P1 | High | open | 13/13 · A 0/7 | [1.0.1](../backlog/1.0.1-[open].md) |
| [052-[fixed]-…](fixed/052-[fixed]-extractor-ownership-playback-layout.md) | Host extractor ownership + playback package layout | P2 | Medium | fixed | 4/4 · A 2/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [053-[workaround]-…](053-[workaround]-windows-live-embed-webview2-transparent.md) | Windows Live Matches WebView2 transparent / blank embed | P1 | High | workaround | 3/3 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [054-[fixed]-…](fixed/054-[fixed]-vidsrc-cloudstream-referer-blocks-segments.md) | Vidsrc CloudStream Referer blocks HLS segments | P1 | High | fixed | Complete · 3/3 · A 2/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [055-[fixed]-…](fixed/055-[fixed]-vidnest-moviebox-referer-429.md) | VidNest MovieBox CDN Referer → HTTP 429 | P1 | High | fixed | Complete · 3/3 · A 2/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [056-[fixed]-…](fixed/056-[fixed]-autoembed-player-sandbox-playback-blocked.md) | AutoEmbed player sandbox / Playback blocked | P1 | High | fixed | Complete · 3/3 · A 2/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [057-[fixed]-…](fixed/057-[fixed]-2embed-stale-cc-url-multiserver.md) | 2Embed stale `.cc` URL / multi-server sniff | P1 | High | fixed | Complete · 3/3 · A 2/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [058-[fixed]-…](fixed/058-[fixed]-live-embed-audio-continues-after-exit.md) | Live Matches embed audio continues after exit | P1 | High | fixed | Complete · 6/6 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [059-[fixed]-…](fixed/059-[fixed]-vod-player-audio-continues-after-exit.md) | Movie/TV player audio continues after exit | P1 | High | fixed | Complete · 7/7 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [060-[open]-…](060-[open]-vidsrc-win-multiserver-provider.md) | VidSrc.win multi-server provider + VSEmbed relabel | P1 | High | open | 4/4 · A 3/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [061-[fixed]-…](fixed/061-[fixed]-engine-worker-hang-on-quit.md) | Engine worker hang on quit (AniList uncancellable) | P1 | High | fixed | Complete · 4/4 · 2/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [062-[fixed]-…](fixed/062-[fixed]-windows-quit-freeze-unbounded-mpv-teardown.md) | Windows quit freezes (unbounded mpv teardown) | P1 | High | fixed | Complete · 4/4 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [063-[fixed]-…](fixed/063-[fixed]-iptv-catalog-scrape-extract-still-dart.md) | IPTV catalog scrape extract still Dart | P2 | Medium | fixed | Complete · 4/4 · 3/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [064-[fixed]-…](fixed/064-[fixed]-stremio-nuvio-player-sources-panel-missing.md) | Stremio/Nuvio player Sources panel missing | P2 | Medium | fixed | Complete · 6/6 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [065-[open]-…](065-[open]-source-fetch-continues-after-leave.md) | Source fetch continues after leave | P1 | High | open | 10/10 · A 0/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [066-[open]-…](066-[open]-canonical-settings-persistence.md) | Canonical settings persistence (KV file + secure secrets) | P1 | High | open | 7/7 · A 4/6 | [1.0.2](../backlog/1.0.2-[draft].md) |
| [067-[fixed]-…](fixed/067-[fixed]-server-panel-reload-ignores-disk-cache.md) | Server panel reload no-op from disk cache | P1 | Medium | fixed | Complete · 4/4 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [068-[fixed]-…](fixed/068-[fixed]-catalog-sources-panel-ttl-cache-lazy-reload.md) | Catalog Sources TTL cache + lazy kind + per-kind reload | P2 | Medium | fixed | Complete · 9/9 · A 0/5 | [1.0.1](../backlog/1.0.1-[open].md) |
| [069-[fixed]-…](fixed/069-[fixed]-stremio-magnet-url-opened-as-file.md) | Stremio magnet `url` opened as file / torrent switch throw | P1 | High | fixed | Complete · 4/4 · A 1/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [070-[fixed]-…](fixed/070-[fixed]-sources-filters-nuvio-scraper-lazy-load.md) | Sources: no All; providers in Filters; lazy Nuvio scrapers | P2 | Medium | fixed | Complete · 8/8 · A 2/5 | [1.0.1](../backlog/1.0.1-[open].md) |
| [071-[fixed]-…](fixed/071-[fixed]-videasy-grace-discards-mirror-streams.md) | Videasy grace discarded collected mirror streams | P1 | High | fixed | Complete · 3/3 · A 2/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [072-[fixed]-…](fixed/072-[fixed]-torrent-early-eof-false-completed-autonext.md) | Local torrent early EOF false completed / auto-next | P1 | High | fixed | Complete · 9/9 · A 4/6 | [1.0.1](../backlog/1.0.1-[open].md) |
| [073-[fixed]-…](fixed/073-[fixed]-stremio-provider-filter-stuck-on-failed-addon.md) | Stremio Filters stuck on failed addon (Torrentio 403) | P1 | High | fixed | Complete · 4/4 · A 2/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [074-[fixed]-…](fixed/074-[fixed]-vod-eof-seek-bar-stuck.md) | VOD EOF sticks seek bar / mislabels real end | P1 | High | fixed | Complete · 5/5 · A 3/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [075-[fixed]-…](fixed/075-[fixed]-anime-dead-cache-empty-sources.md) | Anime dead session cache pins one stream / empty Sources | P1 | High | fixed | Complete · 12/12 · A 4/6 | [1.0.1](../backlog/1.0.1-[open].md) |
| [076-[fixed]-…](fixed/076-[fixed]-provider-score-negatives-floored.md) | Provider fail (−2) verdicts floored away from global Σ | P1 | High | fixed | Complete · 3/3 · A 2/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [077-[fixed]-…](fixed/077-[fixed]-iptv-portal-passwords-plaintext-prefs.md) | IPTV portal passwords in plaintext prefs | P1 | High | fixed | Complete · 4/4 · A 3/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [078-[fixed]-…](fixed/078-[fixed]-switches-not-in-design-system.md) | Switches not in design system | P2 | Medium | fixed | Complete · 4/4 · A 3/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [079-[fixed]-…](fixed/079-[fixed]-scrub-back-forced-eof.md) | Scrub-back forced back to EOF | P1 | High | fixed | Complete · 4/4 · A 3/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [080-[open]-…](080-[open]-miruro-cf-pipe-webview-unlock.md) | Miruro CF pipe WebView unlock fails | P1 | High | open | 5/7 · A 0/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [081-[fixed]-…](fixed/081-[fixed]-macos-quit-mpv-demux-sigsegv.md) | macOS quit mpv demux SIGSEGV | P1 | High | fixed | Complete · 4/4 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [082-[open]-…](082-[open]-multi-server-collect-all.md) | Multi-server must show every mirror | P1 | High | open | 7/7 · A 1/5 | [1.0.1](../backlog/1.0.1-[open].md) |
| [083-[open]-…](083-[open]-anime-first-hit-no-background-scan.md) | Anime first playable wins (no background scan) | P1 | High | open | 4/4 · A 0/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [084-[open]-…](084-[open]-megaplay-nekostream-cdn-referer.md) | Megaplay nekostream Referer + `/stream/ani/` | P1 | High | open | 29/29 · A 3/11 | [1.0.1](../backlog/1.0.1-[open].md) |
| [085-[open]-…](085-[open]-desktop-involuntary-signout-dumps-login.md) | Session loss → login + wipe (no Guest portal leak) | P1 | High | open | 5/5 · A 0/2 · 1⏭️ | [1.0.1](../backlog/1.0.1-[open].md) |
| [086-[fixed]-…](fixed/086-[fixed]-provider-score-running-total-floor.md) | Provider score re-sum buried ups under Auto fails | P1 | High | fixed | Complete · 3/3 · A 2/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [087-[open]-…](087-[open]-update-dialog-empty-changelogs.md) | Update dialog empty notes (R2 changelog archive) | P1 | High | open | 2/2 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [088-[fixed]-…](fixed/088-[fixed]-stale-webstreaming-cache-token-replay.md) | Stale webstreaming cache / history token replay | P1 | High | fixed | Complete · 4/4 · A 2/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [089-[fixed]-…](fixed/089-[fixed]-windows-msvcp140-not-found.md) | Windows install: MSVCP140.dll not found | P1 | High | fixed | Complete · 3/3 · A 0/1 | — |
| [090-[fixed]-…](fixed/090-[fixed]-details-resume-progress-missing.md) | Details Resume / progress missing | P1 | High | fixed | Complete · 5/5 · A 2/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [091-[open]-…](091-[open]-simple-resolve-budgets-kill-webstreamr-embeds.md) | Simple resolve budgets kill WebStreamr + embeds | P1 | High | open | 2/2 · A 0/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [092-[open]-…](092-[open]-windows-iptv-stream-freeze-after-20s.md) | Windows IPTV freezes after ~20s (no reconnect) | P1 | High | open | 3/3 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [093-[open]-…](093-[open]-webstreamr-mbg-source-parity.md) | WebStreamr local scrape out of sync with MBG | P1 | High | open | 4/4 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [094-[fixed]-…](fixed/094-[fixed]-iptv-catalog-refetch-every-launch.md) | IPTV catalog re-fetches on every launch | P1 | High | fixed | Complete · 4/4 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [095-[fixed]-…](fixed/095-[fixed]-anime-english-titles-server-miss.md) | Anime English titles + SPECIALS server miss | P1 | High | fixed | Complete · 5/5 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [096-[fixed]-…](fixed/096-[fixed]-iptv-empty-local-cache-wipes-cloud.md) | Empty local IPTV cache wiped cloud portals | P0 | Critical | fixed | Complete · 5/5 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [097-[open]-…](097-[open]-auto-watched-series-progress-details.md) | Auto watched + series % on details | P2 | Medium | open | 5/6 · A 0/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [098-[open]-…](098-[open]-anime-details-season-chain.md) | Anime details AniList season chain | P2 | Medium | open | 7/8 · A 0/6 | [1.0.1](../backlog/1.0.1-[open].md) |
| [099-[open]-…](099-[open]-profile-settings-cloud-master-local-cache.md) | Profile settings: cloud master, local cache | P1 | High | open | 5/5 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [100-[open]-…](100-[open]-anime-details-cast-recs-trailers.md) | Anime details cast / recs / trailers | P2 | Medium | open | 5/6 · A 0/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [101-[open]-…](101-[open]-player-back-lands-on-loading.md) | Player Back lands on stream loading | P1 | High | open | 4/4 · A 0/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [102-[open]-…](102-[open]-android-tv-exoplayer-tiled-frames.md) | Android TV ExoPlayer tiled / shifted frames | P1 | High | open | 3/3 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [103-[open]-…](103-[open]-android-tv-anime-details-hero-focus.md) | Android TV anime details hero + focus chrome | P1 | High | open | 4/4 · A 0/4 | [1.0.1](../backlog/1.0.1-[open].md) |
| [104-[open]-…](104-[open]-android-tv-live-matches-embed-dpad.md) | Android TV Live Matches embed Play/Back/player D-pad | P1 | High | open | 3/3 · A 0/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [105-[open]-…](105-[open]-exoplayer-sources-dialog-missing.md) | ExoPlayer Sources button / 2-column dialog | P1 | High | open | 3/3 · A 0/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [106-[open]-…](106-[open]-desktop-session-profile-chrome-desync.md) | Long-idle session / profile chrome desync | P1 | High | open | 5/5 · A 0/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [107-[fixed]-…](fixed/107-[fixed]-android-7-tmdb-lets-encrypt-trust.md) | Android ≤7.0 TMDB posters (Let's Encrypt trust) | P1 | High | fixed | Complete · 4/4 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [108-[open]-…](108-[open]-android-tv-iptv-exo-choppy-fps.md) | Android TV IPTV Exo choppy FPS (weak / Android 7) | P1 | High | open | 8/8 · A 0/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [109-[open]-…](109-[open]-android-tv-boot-jwt-expired-discard-race.md) | ATV/desktop boot JWT expired (gotrue discard) | P1 | High | open | 5/5 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [110-[open]-…](110-[open]-android-tv-iptv-player-top-bar-dpad.md) | ATV IPTV player top-right Player D-pad chrome | P1 | Medium | open | 2/2 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [111-[open]-…](111-[open]-macos-keychain-consent-local-file.md) | macOS Keychain consent + local-file fallback | P1 | Medium | open | 5/5 · A 0/3 | — |
| [112-[fixed]-…](fixed/112-[fixed]-iptv-share-self-contained-tokens.md) | IPTV share: self-contained `F1.` tokens | P1 | High | fixed | Complete · 5/5 · A 2/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [113-[open]-…](113-[open]-android-tv-trailer-player-white-screen.md) | Android TV trailer player white screen | P1 | High | open | 2/2 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [114-[open]-…](114-[open]-android-tv-movie-mediakit-audio-only.md) | Android TV movie MediaKit audio-only | P1 | High | open | 4/4 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [115-[open]-…](115-[open]-android-tv-iptv-player-menu-mpv-sigsegv.md) | Android TV IPTV Player menu mpv SIGSEGV | P1 | High | open | 2/2 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [116-[open]-…](116-[open]-android-tv-live-matches-embed-cors-native-handoff.md) | Android TV Live Matches embed CORS → native handoff | P1 | High | open | 2/2 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [117-[open]-…](117-[open]-android-live-embedindia-handoff-stuck.md) | Android Live embedindia / Streamed Exo handoff black | P1 | High | open | 7/7 · A 0/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [118-[open]-…](118-[open]-iptv-thin-local-cache-shrinks-cloud.md) | Thin local IPTV cache shrinks cloud portals | P0 | Critical | open | 4/4 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |
| [119-[open]-…](119-[open]-android-tv-double-back-exit.md) | Android TV double Back / Exit to quit | P1 | Medium | open | 4/4 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [120-[open]-…](120-[open]-android-tv-player-memory-purge.md) | Player open: purge sibling tabs + image RAM | P1 | High | open | 5/5 · A 0/3 | [1.0.1](../backlog/1.0.1-[open].md) |
| [121-[open]-…](121-[open]-android-tv-skip-shell-slide.md) | Android TV skip shell slide transitions | P1 | Medium | open | 3/3 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [122-[open]-…](122-[open]-android-tv-iptv-player-lost-dpad.md) | Android TV IPTV player lost D-pad | P1 | High | open | 3/3 · A 0/2 | [1.0.1](../backlog/1.0.1-[open].md) |
| [123-[open]-…](123-[open]-android-tv-iptv-catalog-focus-after-player.md) | Android TV IPTV catalog focus after player | P1 | Medium | open | 2/2 · A 0/1 | [1.0.1](../backlog/1.0.1-[open].md) |

**Migration parity (draft):** [018](018-[draft]-migration-playback-parity-unverified.md) → [019](019-[draft]-webstreamr-enginejobs-e2e-test-gap.md)–[022](022-[draft]-playback-widget-integration-tests.md).

**LAN (RFC-022):** [026](026-[open]-lan-stream-playback-bearer-token.md) blocks playback · [027](027-[draft]-lan-server-client-manual-qa.md)–[030](030-[draft]-lan-hdr-passthrough-unverified.md) verification / gaps.

## Related

- [RFC index](../rfc/README.md)
- [Backlog](../backlog/README.md)
