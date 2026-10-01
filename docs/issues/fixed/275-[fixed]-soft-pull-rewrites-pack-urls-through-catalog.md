# 275 — Soft-pull rewrites profile pack URLs through published catalog

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** sync (`importForja`) · packs

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** tasks · **1 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I275-T01 | Remove `rewriteLeanUrlsThroughCatalog` | ✅ |
| 2 | I275-T02 | `importForja` applies cloud `packs[]` URLs as-is (no catalog fetch/remap) | ✅ |
| 3 | I275-T03 | Drop rewrite unit test; changelog + feature doc | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I275-A01 | Soft-pull with local checkout paths in profile keeps those paths — never swaps to GitHub/catalog `manifest_url` | ✅ |

---

## Summary

Issue 267 added `rewriteLeanUrlsThroughCatalog` so retired remote hosts (old monorepo GitHub paths) remapped to published `plugin_packs.manifest_url`. Soft-pull ran that on **every** lean row, including absolute local checkouts. Local paths for catalog slots became `raw.githubusercontent.com/…`, silent-installed, then pushed back into the profile — destroying saved local membership.

**Root fix:** delete the rewrite. Cloud pack URLs are applied exactly as stored. Same-slot remote→remote migrate inside `applyLeanManifestUrls` (cloud URL already different) still works; catalog is not consulted on pull.

### Related

- [267](267-[fixed]-soft-pull-stale-pack-manifest-urls.md) — introduced the rewrite
- [RFC-074](../../rfc/074-[open]-remote-profile-plugin-install.md)
- [Forja Packs](../../features/settings/forja-packs.md)
