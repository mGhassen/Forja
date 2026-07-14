# 039 — Resolver Engine missing most template embed plugins

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/resolver-engine/src/plugins/`, host WebView sniff (`HostProviderAdapter`)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** tasks · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I39-T01 | Register all `stream-core` template IDs as `HostRequired` plugins (`vidfast` … `primewire`) | ✅ |
| 2 | I39-T02 | Unit test: every template in `list_providers()` has a matching host plugin + embed payload | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I39-A01 | Pinning VidFast / 2Embed / SuperEmbed / … emits `awaiting_host` with `embedUrl` (not `unknown provider`) | ✅ |
| 2 | I39-A02 | Desktop/mobile `HostProviderAdapter` sniffs that embed via headless WebView (ATV still skipped per issue 031) | ✅ |

---

## Summary

`stream-core` and Flutter settings listed 13 template embed hosts, but Resolver Engine `built_in()` only registered five (`vidlink`, `vixsrc`, `vidnest`, `vidzee`, `vidrock`). The other IDs were treated as host-required (`is_host_required` defaults true) yet `try_provider` returned `unknown provider` — so they never produced `HostRequired` with an embed URL, and WebView sniff never ran.

### Root fix

Register the remaining plugins via the existing `template_provider!` macro and wire them in `plugins/mod.rs`. Desktop/mobile sniff path was already implemented in `HostProviderAdapter` / `StreamExtractor`.

### Related

- [031](../031-[workaround]-android-tv-webview-gles-crash.md) — ATV still skips headless sniff
- [037](../037-[open]-webstreaming-all-providers-open-validate.md) — open/probe validation
- [Stream providers](../../features/sources/stream-providers.md)
- [RFC-032](../../rfc/032-[open]-rust-resolver-engine.md)
