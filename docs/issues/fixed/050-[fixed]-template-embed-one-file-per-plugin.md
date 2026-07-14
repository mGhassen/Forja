# 050 — Template embed plugins must be one file each

**Status:** fixed
**Priority:** P2
**Severity:** Medium
**Area:** `crates/resolver-engine/src/plugins/`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** tasks · **2 / 2** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I50-T01 | Split all `stream-core` template embeds out of the macro bag into one standalone plugin file each | ✅ |
| 2 | I50-T02 | Keep shared `resolve_host_template` in crate-root `host_template.rs` + coverage test that every template ID still has a `HostRequired` plugin | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I50-A01 | `plugins/` contains one `.rs` file per template provider (`vidfast`, `vidsrcsbs`, `2embed`, …) registered from `built_in()` | ✅ |
| 2 | I50-A02 | `cargo test -p resolver-engine host_template` passes (coverage + vidfast embed payload) | ✅ |

---

## Summary

RFC-032 requires each built-in provider to be a **standalone plugin file**. Template embeds were registered via a single `template_provider!` macro bag in `template_embed.rs`, which violated that layout even though resolve behavior was correct.

### Root fix

- Shared URL → host handoff lives in crate-root `host_template.rs` (`resolve_host_template` + coverage tests) — not under `plugins/`
- Each template provider owns its file (`vidlink.rs`, `vidfast.rs`, `vidsrcsbs.rs`, `two_embed.rs`, …) and implements `Provider` by calling the helper
- `plugins/mod.rs` registers each provider module explicitly (helper is not listed there)

### Related

- [039](fixed/039-[fixed]-resolver-missing-template-embed-plugins.md) — original registration completeness (behavior unchanged)
- [RFC-032](../rfc/032-[open]-rust-resolver-engine.md) — R32-C02 / R32-A15
