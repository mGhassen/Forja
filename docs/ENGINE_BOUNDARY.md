# Forja — engine boundary

Canonical rules for what lives in **Rust engine (`crates/*`)**, **Flutter host (`apps/forja`)**, or **FFI bridge only** (`packages/rust`).

**Status:** Locked (2026-07-06). Grounded in [INVENTORY.md](INVENTORY.md).

**Migration execution:** [migration/README.md](migration/README.md) · [Wave 1 — playback](./migration/fixed/02-[fixed]-rust-engine-complete.md) · [Wave 2 — catalog](./migration/fixed/03-[fixed]-engine-catalog.md)

---

## 1. Two layers

| Layer | Location | What belongs |
|-------|----------|--------------|
| **Engine** | `crates/*` | All logic that does not require platform (C1, C2, C7, C8, C9, Rust-side C11 pipelines) |
| **Host** | `apps/forja` | UI + platform capabilities (C3–C6, C10, C12, host-side C11 UX) |
| **FFI bridge** | `packages/rust` | Loader + parity tests only — **not engine** |

`packages/api` is **legacy catalog engine** pending port to `crates/*`. Playback packages (`streaming`, `storage`, `core`) are deleted (wave 1).

Migration is sequenced in **two waves** (playback, then catalog) — scheduling only, not different architectural layers.

---

## 2. Locked decisions

| ID | Choice |
|----|--------|
| **D1** | **C** — All engine in `crates/*`; incremental vertical crates |
| **D2** | **C** — Hybrid orchestration: Rust pipelines; host provider race + loading UX |
| **D3** | **A** — Nuvio permanent host (C4) |
| **D4** | **B** — Jackett/Prowlarr optional host plugins; Knaben in Rust |
| **D5** | **A** — OAuth/secrets host-only; Rust receives tokens per call when needed |
| **D6** | **A** — Consolidate loopback servers into `crates/proxy` (P2-92) |
| **D7** | **A** — Move `app_theme` to `apps/forja` (P2-96) |
| **D8** | **A** — New FFI: fetch+parse in Rust; deprecate HTML-in shims |
| **D9** | Phased legacy package deletion — see §6 |
| **D10** | **Flutter permanent** — `apps/forja` is the only mobile/desktop UI host |

**Webstreamr:** Lives in `crates/webstreamr` because C2 scrape + C7 proxy + playback pipeline = **engine** — same rule as TMDB (C1). Long FFI via [EngineWorkerPool](../packages/rust/lib/src/engine_worker.dart) ([001](issues/001-[fixed]-webstreamr-blocks-ui.md), [015](issues/015-[fixed]-rust-blocking-http-engine-debt.md)).

**Compose / kotlin UI:** Cancelled. `packages/kotlin` deleted (P3-00 ✅).

---

## 3. Capability taxonomy

| ID | Class | Examples | Destination |
|----|-------|----------|-------------|
| **C1** | REST/JSON/GraphQL | TMDB, Trakt, Jellyfin | **Engine** — `crates/*` |
| **C2** | HTML/XML scrape + parse | webstreamr, manga, Knaben | **Engine** — `crates/*` |
| **C3** | WebView embed sniff | `stream_extractor`, kisskh | **Host** |
| **C4** | JS runtime (non-browser) | Nuvio `flutter_js` | **Host** |
| **C5** | WASM host | Videasy extractor | **Host** |
| **C6** | Video/audio decode | media_kit (default); ExoPlayer/Media3 (Android built-in option) | **Host** |
| **C7** | Local loopback HTTP | proxy, shelf, 111477 | **Engine** — `crates/*` |
| **C8** | Crypto/transform | openssl_crypt, AES | **Engine** — `crates/*` |
| **C9** | Persistence | prefs, history | **Engine** — `crates/storage`; secrets on host |
| **C10** | UI | theme, widgets, nav | **Host** |
| **C11** | Orchestration | provider races, subtitles | Split — see R6 |
| **C12** | OAuth / OS intents | Trakt OAuth, VLC | **Host** |

---

## 4. Rules

### RE — Engine (`crates/*`)

All non-platform logic:

- **Playback (wave 1):** `webstreamr`, `torrent`, `proxy` (incl. `seek111477`), `scrapers`, `stream-core`, `stremio-core` (P2-93), `storage`, `utils`, `iptv-core` (P2-94), consolidated local HTTP (P2-92)
- **Catalog (wave 2):** TMDB, Trakt, Jellyfin, anime, manga, music, Arabic verticals — port from `packages/api` to `crates/*` (Phase 3)

**No new engine logic in Dart** — port to `crates/*` when touching.

### RH — Host (`apps/forja`)

| Class | Examples |
|-------|----------|
| C3 | WebView extractors |
| C4 | Nuvio `flutter_js` |
| C5 | Videasy WASM host |
| C6 | media_kit, audio_service, PiP, external player |
| C10 | Theme, widgets, navigation |
| C12 | OAuth flows, secure storage, OS intents |

### R4 — Network is not the boundary

HTTP location is an implementation detail inside the engine. The split line is **engine vs host capabilities** (RE vs RH).

### R5 — FFI

- Default: **fetch+parse in Rust** (Pattern B)
- **Forbidden:** sync FFI on UI thread for calls > ~50ms
- **Long I/O:** [`EngineJobs`](../packages/rust/lib/src/engine_jobs.dart) — Rust tokio runtime ([016](issues/016-[fixed]-async-job-ffi-hard-cancel.md))
- **CPU / parse:** [`EngineWorkerPool`](../packages/rust/lib/src/engine_worker.dart) — worker isolates
- Typed entry points: [isolate_runner.dart](../packages/rust/lib/src/isolate_runner.dart)
- **Deprecated:** Pattern A (`*_html_json` HTML-in) for new engine work
- Exception: Pattern A OK when host already holds HTML from an active WebView session (C3)

### R6 — Orchestration (C11)

- **Rust:** cohesive pipelines with golden tests — webstreamr, vidsrc chain, torrent search
- **Host:** provider order, loading/cancel UX, subtitle aggregation
- Delete unused `StreamResolver`, dead storage repos, duplicate `stream_extractor` (P2-95)

### R7 — App feature folders

Engine logic in `apps/forja/features/**/data/` must move to `crates/*` (or host adapters only). IPTV HTTP is engine (P2-94).

### R8 — Host-side extractors (C3–C5) stay on the UI isolate

WebView, `flutter_js`, and WASM hosts **cannot** move off the main Dart isolate. They may still freeze the spinner during heavy work — mitigate with **timeout + cancel**, not sync Rust FFI patterns.

| Extractor | File | Typical block | Timeout | Cancel |
|-----------|------|---------------|---------|--------|
| Headless embed sniff | `packages/api/lib/api/stream_extractor.dart` | 5–60s (page load + JS hooks) | ✅ param (default 60s) | ✅ `cancel()` + `isCancelled` |
| Kisskh WebView | `packages/api/lib/api/kisskh_extractor.dart` | 10–25s (+ subtitle decrypt) | ✅ 25s | ✅ `cancel()` + `isCancelled` |
| Amri WebView | `packages/api/lib/api/amri_extractor.dart` | 15–30s | ✅ 30s | ✅ `cancel()` + `isCancelled` |
| Nuvio scrapers | `apps/forja/lib/shared/nuvio/nuvio_runtime.dart` | 10–30s (JS event loop) | ✅ 30s | ✅ `NuvioService.cancelPending()` |
| Videasy WASM | `packages/api/lib/playback/videasy_extractor.dart` | 5–45s (HTTP + WASM + AES FFI) | ✅ 45s | ✅ `isCancelled` |
| Arabic WebView fallback | `packages/api/lib/api/arabic_service.dart` | 5–15s | ✅ 15s | via `StreamExtractor.cancel()` |

Rust-side decrypt/resolve for vidsrc/videasy uses [`EngineJobs`](../packages/rust/lib/src/engine_jobs.dart) ([006](issues/006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md), [016](issues/016-[fixed]-async-job-ffi-hard-cancel.md)).

### R9 — 111477 index scrape stays in Dart (legacy `packages/api`)

**Decision (2026-07-06):** Permanent host/legacy-api responsibility until Phase 3 catalog port — [013](issues/013-[fixed]-site111477-captcha-still-dart.md).

| Component | Location | Engine? |
|-----------|----------|---------|
| Index fetch + CF/rate-limit retry (429, error 1015) | `packages/api/lib/api/site111477_service.dart` | Legacy API — **not** engine |
| Seekable localhost proxy | `crates/proxy/src/seek111477.rs` | **Engine** (C7) |
| Proxy FFI glue | `packages/api/lib/playback/site111477_proxy.dart` | Thin wrapper |

The Rust proxy receives a **resolved file URL** only. Cloudflare backoff is not duplicated in Rust by design. See [crates/proxy/README.md](../../crates/proxy/README.md).

---

## 5. What survives in `packages/`

| Package | Fate |
|---------|------|
| `packages/rust` | **Permanent** FFI bridge — no engine logic |
| `packages/api` | Legacy engine — delete wave 2 when verticals live in `crates/*` |
| `streaming`, `storage`, `core`, `webstreamr`, `scrapers` | Legacy engine — delete wave 1 |

**Normalized end state:** only `packages/rust` under `packages/`.

---

## 6. Legacy package deletion (D9)

| Package | Wave |
|---------|------|
| `streaming` | 1 — after P2-83, 91, 92 |
| `storage` | 1 — after P2-88 (+ P2-96 theme → app) |
| `core` | 1 — after P2-90 |
| `api` (playback slices) | 1 — P2-89 |
| `api` (catalog verticals) | 2 — Phase 3 (P3-01 → P3-03) |
| `kotlin` | 2 — ✅ deleted (P3-00) |

---

## 7. Evidence (from inventory)

| Fact | Implication |
|------|-------------|
| Rust ~8.5k LOC; Dart api ~23.7k LOC | Catalog port is wave 2 — large but same destination as playback |
| Four localhost server patterns | Consolidate in P2-92 |
| FFI Pattern A + B coexist | Standardize on B for engine |
| WebView ~1.9k, player ~1.8k, REST ~17k | Boundary by capability class, not package name |
| Engine in `apps/forja/features/iptv/` | R7 — package delete ≠ engine complete |

---

## Related

| Doc | Role |
|-----|------|
| [INVENTORY.md](INVENTORY.md) | As-built facts |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Target architecture |
| [migration/README.md](migration/README.md) | Phase plan |
| [RFC-009](rfc/fixed/009-[fixed]-rust-ffi.md) | FFI spec |
