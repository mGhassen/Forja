# RFC-119: Stream orchestrator — discover, then enrich

**Status:** open  
**Depends on:** [RFC-064](064-[open]-rust-quickjs-engine-runtime.md)  
**Area:** `crates/engine`, `crates/ffi` EngineJobs, Sources / green Play, `forja-packs/providers`

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** components · **8 / 9** acceptance |
| **Current slice** | Shipped in code — manual freeze check still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R119-C01 | Per-job extract event queue (`ctx.emit` → FFI drain before `Done`) | ✅ |
| 2 | R119-C02 | `ctx.emit(row)` on EngineJS; flutter_js `emit` is a no-op so packs still return rows | ✅ |
| 3 | R119-C03 | Worker budget `W` = 2 desktop / 1 TV; each job still `AsyncRuntime::new()` | ✅ |
| 4 | R119-C04 | `StreamOrchestrator` — shared in-flight join per session+plugin, global slot gate | ✅ |
| 5 | R119-C05 | Discover-only on hot packs (no playlist fetch, no proxy rewrite during list) | ✅ |
| 6 | R119-C06 | Other HTTP plugins stay final-array-only (documented; not a silent playlist fetch) | ✅ |
| 7 | R119-C07 | Sources appends emitted rows, coalesced ~50ms, cap 30 rows per plugin | ✅ |
| 8 | R119-C08 | No small worker gate — every selected provider is submitted; each job still `AsyncRuntime::new()` | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R119-A01 | Unit: `ctx.emit` rows are readable before extract `Done` | ✅ |
| 2 | R119-A02 | `engineSourcesBatchLimit` is 2 desktop and 1 TV | ✅ |
| 3 | R119-A03 | Second caller for the same session plugin awaits the in-flight extract | ✅ |
| 4 | R119-A04 | VidLink extract does not GET the m3u8 body or rewrite a proxy URL | ✅ |
| 5 | R119-A05 | Videasy `ctx.emit`s each mirror before `Promise.all` settles | ✅ |
| 6 | R119-A06 | Sources applies mid-extract rows without waiting for plugin `Done` | ✅ |
| 7 | R119-A07 | Manual macOS: Forja All does not freeze the shell while chips fill | ⬜ |
| 8 | R119-A08 | Runtime reuse across extracts is not implemented | ✅ |
| 9 | R119-A09 | Selected providers start together on desktop and TV | ✅ |

---

## Summary

### Problem

Sources starts up to 10 fresh QuickJS extracts. Each plugin returns one JSON blob. Packs fetch playlists and rewrite proxy URLs during that list pass. The shell freezes. Adding more desktop slots makes it worse.

### Goals

1. Every selected provider starts at once, on desktop and on TV. Each still gets a fresh QuickJS runtime. Rust runs those jobs in parallel. Dart listens for `ctx.emit` and paints rows while a plugin is still running.
2. `ctx.emit` pushes a row to Dart while the plugin is still running.
3. Discover returns `{ url, headers, name, quality? }`. Probe, proxy, and playlist expand happen when a row is played or checked.
4. Sources and green Play share one in-flight extract for the same title and plugin.

### Non-goals

- Reusing a QuickJS `AsyncRuntime` across extracts.
- Raising a tiny desktop slot count as the speed fix. Parallelism is “start the selected providers,” not a pool of two.
- Porting providers to Dart.
- Nuvio, Stremio, torrent, live unlock.
- WebView `ctx.host` inside the worker budget.

### Contracts

- `ctx.emit(row)` is additive. Returning an array still works. The host dedupes by URL.
- Discover must not GET an m3u8 body, parse variants, or rewrite a proxy URL. `requiresProxy: true` is a flag for play-time enrich.
- Plugins that do not call `ctx.emit` are final-array-only. Their rows appear when the job `Done` fires. They start with the other selected providers.
- Event drain is a JSON array polled while the job is `Pending`. `Done` stays the completion signal.

### Related

- [Issue 386](../issues/386-[open]-stream-orchestrator-discover.md)
- [RFC-064](064-[open]-rust-quickjs-engine-runtime.md)
