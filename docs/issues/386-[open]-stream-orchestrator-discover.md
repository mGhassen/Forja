# 386 — Sources freezes while Forja providers extract

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** Sources · green Play · EngineJS · `forja-packs/providers`

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** tasks · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I386-T01 | `ctx.emit` + per-job event drain on EngineJS extract | ✅ |
| 2 | I386-T02 | Cap concurrent extracts at 2 desktop / 1 TV (fresh runtime each) | ✅ |
| 3 | I386-T03 | Shared orchestrator so Sources and Play do not double-run one plugin | ✅ |
| 4 | I386-T04 | Discover-only: VidLink, Videasy, VidSrc.sbs, VixSrc, Xprime | ✅ |
| 5 | I386-T05 | Sources paints emitted rows before plugin `Done` (50ms coalesce) | ✅ |
| 6 | I386-T06 | Document remaining HTTP plugins as final-array-only | ✅ |
| 7 | I386-T07 | Start every selected provider together; Rust jobs stay parallel; Dart only joins a duplicate plugin | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I386-A01 | `cargo test -p engine emit_rows_before_done` passes | ✅ |
| 2 | I386-A02 | Manual macOS: opening Sources → Forja does not freeze the window | ⬜ |

---

## Symptom

Opening Sources → Forja (or green Play) runs many provider extracts at once. The app freezes. Rows appear only after a plugin finishes every mirror, including playlist downloads and proxy rewrites.

## Root

The host treats extract as one final JSON blob and fans out too many QuickJS runtimes. Packs do play-time work (m3u8 body, proxy URL) during the list.

**Root fix:** [RFC-119](../rfc/119-[open]-stream-orchestrator.md) — small worker budget, `ctx.emit`, discover-only hot packs, enrich on play/status. Not a reused JS runtime. Not a larger desktop pool.

## Final-array-only plugins

Any HTTP provider that does not call `ctx.emit` is final-array-only: rows arrive with job `Done`. They still use the worker budget. Hot packs that used to download playlists during list are migrated (see T04).

## Related

- [RFC-119](../rfc/119-[open]-stream-orchestrator.md)
- [RFC-064](../rfc/064-[open]-rust-quickjs-engine-runtime.md)
