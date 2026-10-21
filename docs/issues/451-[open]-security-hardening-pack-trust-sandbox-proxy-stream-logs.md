# 451: Security hardening: pack install trust, provider sandbox limits, proxy token, stream URL allowlist, log redaction

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** packs install · engine sandbox · proxy · player · logging

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 10** fix · **0 / 8** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I451-T01 | Plugin `id` charset check in `PluginContract.validateManifest` (`apps/forja/lib/shared/engine/packs/registry/plugin_contract.dart:63`, `:231-237`): accept only `[A-Za-z0-9._-]`; reject `/`, `\`, `..`. The disk path join in `plugin_script_disk_store.dart:180-186` writes `plugins/<id>.js` under the pack dir, so an id containing `../` lands outside it | ⬜ |
| 2 | I451-T02 | https floor for the manifest URL and every resolved script / prelude URL: `plugin_registry.dart` `_fetchBytes` (`:263-285`) and `resolveScriptUrl` (`:877-879`), `forja_plugin_deeplink.dart:90-105`. Local `file` paths stay allowed for dev. Optional: per-file `sha256` in manifests, checked after download | ⬜ |
| 3 | I451-T03 | Install prompt shows the manifest host under the display name (`apps/forja/lib/features/settings/packs/pack_prompt_pane.dart:552-562` renders `displayName` / `description` / tags only) | ⬜ |
| 4 | I451-T04 | QuickJS runtime limits in `crates/engine/src/extract.rs`: memory limit, max stack size, and an interrupt handler tied to the cancel token and job deadline (`AsyncRuntime::new()` at `:694`, context at `:706`; today only the outer `tokio::time::timeout` at `:630-633` bounds the job, and a busy JS loop is not interruptible) | ⬜ |
| 5 | I451-T05 | Provider fetch hardening in `native_fetch` (`extract.rs:506-576`) and `chrome_fetch` (`crates/engine/src/chrome_fetch.rs:46-60`): refuse loopback, link-local, RFC1918, CGNAT, and the app's own proxy / LAN ports unless the pack opts in; drop pack-supplied `Host` and `Content-Length` headers (`:540-542` forwards every header verbatim); cap the response body at 16 MiB | ⬜ |
| 6 | I451-T06 | Loopback proxy (`crates/proxy/src/lib.rs`): per-process token required on media routes (`query_proxy_handler` `:241-253` accepts any `?url=`); no wildcard `Access-Control-Allow-Origin` / `Allow-Headers` in `forward_response` (`:208-217`); `build_upstream_request` (`:170-207`) forwards pack-supplied `Cookie` / `Authorization` to any target | ⬜ |
| 7 | I451-T07 | Host-side `isPlayableStreamUrl` allowlist: `http(s)`, the loopback proxy, and `file://` only under the downloads dir. Apply in `classifyStremioStream` (`packages/rust/lib/src/playback/stremio/stremio_stream_resolver.dart:152-161` returns any non-torrent `url` as playable), the sources probe (`apps/forja/lib/shared/playback/probe/engine_catalog_stream_probe.dart:37-47`), `ExoPlayerBridge.open` (`apps/forja/lib/shared/player/exo/exo_player_bridge.dart:219`), and `android_player_launcher.dart:23-33` (any `url` becomes an `ACTION_VIEW` intent) | ⬜ |
| 8 | I451-T08 | Release builds: `debugPrint` no-op, and redact credentials / headers in player, portal, casting, and external-player logs (`mobile_player_playback.dart:154-281` logs full stream URLs; `android_player_launcher.dart:33`; `casting_service.dart:83`; `external_player_service.dart:446-450` prints every header value; `pack_auth_session_handoff.dart:124` prints the full handoff `uri`) | ⬜ |
| 9 | I451-T09 | `apps/forja/android/app/src/main/AndroidManifest.xml` `<application>` (`:17`) declares neither `android:allowBackup="false"` nor `dataExtractionRules`; set one of them and exclude `shared_prefs` | ⬜ |
| 10 | I451-T10 | OTA update verifies a `sha256` from `latest/manifest.json` before install (`apps/forja/lib/shell/update/update_dialog.dart:1023-1027` passes `downloadUrl` straight to `OtaUpdate().execute`; `app_updater_manifest.dart:85-116` reads `version` / `assets` / `published_at` only) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I451-A01 | Installing a crafted manifest whose plugin `id` contains `../` is rejected before any file is written (T01) | ⬜ |
| 2 | I451-A02 | An `http://` manifest or script URL is refused with a clear message in the install prompt (T02) | ⬜ |
| 3 | I451-A03 | The install prompt shows the manifest host under the pack name (T03) | ⬜ |
| 4 | I451-A04 | A plugin with an infinite loop returns an error within the job deadline; the app stays responsive (T04) | ⬜ |
| 5 | I451-A05 | A provider fetch to `127.0.0.1` or a `10.x` address is refused unless the pack opted in (T05) | ⬜ |
| 6 | I451-A06 | A proxy media request without the process token returns 403 (T06) | ⬜ |
| 7 | I451-A07 | A `file://` stream URL outside the downloads dir is refused by the resolver, the probe, Exo, and the external launcher (T07) | ⬜ |
| 8 | I451-A08 | Release logcat during play, cast, external hand-off, and portal sign-in shows no credentials, tokens, or header values (T08) | ⬜ |

---

## Summary

Read-only security review on 2026-10-21 of branch `feat/tv-remote-ux`, covering the deep-link install path, the pack script store, the QuickJS provider sandbox, the loopback proxy, stream URL handling, logging, Android backup, and OTA update. RFC-122 T12 (`R122-C12`) records the review; this issue tracks the fixes.

### Findings (code as read)

**Pack install trust**

- `PluginContract.validateManifest` only requires `id` to be a non-empty string (`plugin_contract.dart:63`, `_requireString` `:231-237`). `PluginScriptDiskStore._engineScriptFile` joins `plugins/<id>.js` under the pack dir (`plugin_script_disk_store.dart:180-186`). An id such as `../../<otherHash>/plugins/x` overwrites another pack's script. Preludes are safe: their path uses `digest(preludeEntry)` (`:194`).
- `_fetchBytes` accepts any scheme the HTTP client accepts (`plugin_registry.dart:263-285`); `resolveScriptUrl` passes through `http://` script URLs (`:877-879`); the deep link accepts any `manifest` / `url` query value (`forja_plugin_deeplink.dart:99-105`). No https floor, no content digest.
- The install prompt shows `displayName`, `description`, version, and tags (`pack_prompt_pane.dart:552-562`) but not the host the manifest is fetched from, so a deep link can impersonate a known pack name.

**Provider sandbox**

- `extract_in_job` bounds a job with `tokio::time::timeout` (`extract.rs:630-633`). `AsyncRuntime::new()` (`:694`) sets no memory limit, no stack limit, and no interrupt handler, so a synchronous JS loop cannot be interrupted and a large allocation is unbounded.
- `native_fetch` builds a fresh `reqwest` client with redirects and a 25 s timeout (`extract.rs:517-520`), forwards every pack header (`:540-542`), and buffers the whole body (`:569-578`). `chrome_fetch` mirrors this (`chrome_fetch.rs:46-60`). No destination filter: a pack can reach loopback, LAN, the local proxy, or the LAN server.

**Loopback proxy**

- Binds `127.0.0.1` (`crates/proxy/src/lib.rs:80`). `query_proxy_handler` (`:241-253`) fetches any `?url=`; `build_upstream_request` (`:170-207`) applies pack-supplied `Cookie`, `Authorization`, `Referer`, `Origin`. `forward_response` sets `Access-Control-Allow-Origin: *` and `Allow-Headers: *` (`:208-217`). Any local process or page can use the proxy as an open fetcher.

**Stream URL**

- `classifyStremioStream` returns any non-torrent `url` as `StremioPlayable` (`stremio_stream_resolver.dart:152-161`). The probe (`engine_catalog_stream_probe.dart:37-47`), `ExoPlayerBridge.open` (`exo_player_bridge.dart:219`), and `AndroidPlayerLauncher` (`android_player_launcher.dart:23-33`) consume the URL as-is, so a pack can emit `file://`, `content://`, or `intent:` URLs.

**Logging**

- Full stream URLs with query tokens: `mobile_player_playback.dart:154`, `:180`, `:203`, `:262`, `:281`; `android_player_launcher.dart:33`; `casting_service.dart:83`. Full header values: `external_player_service.dart:446-450`. Full handoff URI including the session token: `pack_auth_session_handoff.dart:124`. All via `debugPrint`, which is live in release builds.

**Android backup**

- `<application>` (`AndroidManifest.xml:17`) declares neither `android:allowBackup="false"` nor `android:dataExtractionRules`, so `shared_prefs` are backed up by default.

**OTA update**

- `update_dialog.dart:1023-1027` passes `downloadUrl` to `OtaUpdate().execute` with no digest; `app_updater_manifest.dart:85-116` reads `version`, `assets`, `published_at` only.

### Verified safe (2026-10-21 review)

- Proxy and torrent HTTP stream server bind loopback (`crates/proxy/src/lib.rs:80`, `crates/torrent/src/lib.rs:363`); LAN server pairing uses a generated per-device token (`crates/lan/src/pairing.rs:111-124`).
- QuickJS exposes only `__native_*` fetch / tmdb / pipe / log / hop / timer / emit functions (`extract.rs:775-994`); no filesystem, env, or process access.
- Default TLS verification everywhere outside `crates/archive/`.
- Deep-link install shows a confirmation prompt before any download (`forja_plugin_deeplink.dart:54-79`).
- Pack directories are derived from `urlHash` (`plugin_script_disk_store.dart:138`); prelude paths use a digest (`:194`); pack-relative files pass `_assertSafeRelative` (`:208-214`).
- IPTV passwords stored in the platform keystore; external links open only `http(s)` (`cast_subtitle.dart:150`).

## Related

- [RFC-122](../rfc/122-[draft]-android-tv-remote-ux.md) — `R122-C12` (T12) security review of the branch diff, deep-link install, and stream URL paths
- [Issue 026](026-[open]-lan-stream-playback-bearer-token.md) — LAN stream ticket auth
- [Issue 111](111-[open]-macos-keychain-consent-local-file.md) — macOS keychain consent
