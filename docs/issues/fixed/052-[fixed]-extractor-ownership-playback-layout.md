# 052 — Host extractor ownership + playback package layout

**Status:** fixed
**Priority:** P2
**Severity:** Medium
**Area:** `apps/forja/lib/shared/extractors/`, `packages/rust/lib/src/playback/`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix tasks · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I52-T01 | Unify host extractors under `shared/extractors/core/` + `providers/<id>/` (profiles, StreamExtractor, Vidsrc, Videasy, Amri, KissKh, Arabic) | ✅ |
| 2 | I52-T02 | Remove host extractor impls from `packages/rust/lib/src/playback/`; keep thin barrel re-exports if needed | ✅ |
| 3 | I52-T03 | Organize remaining playback package into type folders (`domain/`, `providers/`, `ordering/`, …) | ✅ |
| 4 | I52-T04 | Update docs + HostProviderAdapter wiring; preserve public `package:rust/rust.dart` API | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I52-A01 | Every HostRequired template provider has a host profile under `extractors/providers/<id>/` | ✅ |
| 2 | I52-A02 | `packages/rust` analyze + playback/extractor tests pass after layout move | ✅ |

---

## Summary

Extractor ownership was scattered: Rust plugins, WebView engine, Vidsrc/Videasy in `packages/rust/playback`, KissKh under features, Amri/Arabic under shared extractors. This issue unified host/WebView extraction under one tree and type-organized the remaining playback package (clients/models/ordering only).

### Layout after ship

```
apps/forja/lib/shared/extractors/
  core/stream_extractor.dart
  core/embed_extract_profile.dart
  embed_extract_profiles.dart          # registry
  providers/<id>/profile.dart          # HostRequired sniff policy
  providers/vidsrc|videasy|amri|kisskh|arabic/…

packages/rust/lib/src/playback/
  domain/ · providers/ · ordering/ · selection/
  platform/ · resolver/ · torrent/ · stremio/ · proxy/
```

---

## Related

- [051](../051-[open]-embed-multiserver-sniff-proxy-cookies.md) — per-provider sniff policy
- [050](050-[fixed]-template-embed-one-file-per-plugin.md) — Rust one-file plugins
