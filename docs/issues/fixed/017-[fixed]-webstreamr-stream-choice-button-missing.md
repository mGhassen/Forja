# 017 — WebStreamr stream-choice button missing in direct streaming player

**Priority:** P2  
**Severity:** Medium  
**Status:** fixed (2026-07-07)  
**Area:** `apps/forja/lib/shared/player/player/`, `packages/api/lib/playback/webstreamr_service.dart`, `apps/forja/lib/features/home/streaming_details_screen.dart`, `crates/webstreamr/src/resolver.rs`  
**Reported:** 2026-07-07
## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** |
| **Backlog** | [0.4.5](../backlog/done/0.4.5-[done].md) |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---


## Summary

In **Direct streaming mode**, when playback started via **WebStreamr**, the player hid the **Video Sources** button (`Icons.video_library_outlined`) whenever only one stream was resolved. Users could not open the sources menu without multiple links.

The button was **not deleted** — it was gated on `_currentSources.length > 1`.


## Root cause (before fix)

1. **UI gate** — player overlays required `length > 1` to render `video_library` button.
2. **Hubdrive extractor bug** — regex `href…HubCloud` matched the first stylesheet `<link href=…>` on hubdrive.tips pages, so HDHub4u embeds never chained to HubCloud (PlayTorrio showed 2160p/1080p FSL/FSLv2; Forja only got KinoGer).
3. **Missing User-Agent** — Rust fetcher sent no browser UA (Dart fetcher always did).
4. **Parsing** — `ytId`-only Rust entries were skipped (no `url` / `externalUrl`).
5. **Resolver parity** — Rust ran all sources before country filter; old Dart pre-filtered `activeSources`.

## Fix (shipped — 2026-07-07)

### Symptom

- `desktop_player_screen.dart` / `mobile_player_screen.dart`: `length > 1` → `isNotEmpty`.

### Root / parity

- `crates/webstreamr/src/extractors/hubdrive.rs`: parse `<a>` tags whose text contains `HubCloud` (not cross-page regex).
- `crates/webstreamr/src/fetcher.rs`: default browser `User-Agent` on client + `FetchConfig`.
- `webstreamr_service.dart`: `resolveStreamUrl()` maps `url` → `externalUrl` → YouTube watch URL from `ytId`; logs resolved/skipped counts.
- `streaming_details_screen.dart`: logs source count before `pushPlayer`.
- `crates/webstreamr/src/resolver.rs`: `source_country_enabled()` pre-filter before parallel resolve.

### Tests

- `crates/webstreamr/src/extractors/hubdrive.rs`: ignores stylesheet before HubCloud anchor
- `crates/webstreamr`: `source_country_enabled_matches_config`
- `crates/webstreamr/tests/stream_resolver.rs`: `enola_holmes3_resolves_multiple_streams` (live, `#[ignore]`)
- `packages/rust/test/parity/webstreamr_service_parse_test.dart`: URL / ytId parsing

**Verify:**

```bash
cd crates/webstreamr && cargo test
cd crates/webstreamr && cargo test enola_holmes3 -- --ignored --nocapture  # live: expect 10+ streams for tt32278481
cd packages/rust && flutter test test/parity/webstreamr_service_parse_test.dart
```

Console during play: `[WebStreamrService] resolved N streams for …` and `[StreamingDetails] webstreamr pushing N sources`.


## Related

- [001](001-[fixed]-webstreamr-blocks-ui.md) — WebStreamr UI blocking (separate)
- [015](015-[fixed]-rust-blocking-http-engine-debt.md) — Rust async resolve

## If this file is deleted

Player gate: `desktop_player_screen.dart` / `mobile_player_screen.dart` (`isNotEmpty`). WebStreamr wiring: `streaming_details_screen.dart`, `webstreamr_service.dart`. Resolver: `crates/webstreamr/src/resolver.rs`.
