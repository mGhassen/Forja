# RFC-100: Admin plugin catalog + product bundles

**Status:** open  
**Depends on:** [RFC-067](fixed/067-[fixed]-forjahq-remote-plugin-pack.md) · [RFC-068](fixed/068-[fixed]-engine-plugin-registry.md) · [RFC-083](fixed/083-[fixed]-pack-manifest-bundle-list.md)  
**Area:** admin / web catalog / Flutter packs

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **9 / 9** acceptance (admin) · **6 / 6** acceptance (app) · **4 / 4** acceptance (web) · **3 / 3** acceptance (retire remote runtime) |
| **Current slice** | Admin register/validate proxies pack fetch + normalizes GitHub blob URLs |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R100-C01 | Supabase `plugin_packs` / `plugin_bundles` / `plugin_bundle_items` + RLS | ✅ |
| 2 | R100-C02 | Admin Plugins page (validate, publish, metadata, filters/bulk) | ✅ |
| 3 | R100-C03 | Admin product bundles CRUD | ✅ |
| 4 | R100-C04 | Flutter published catalog + bundle install (fallback baked list) | ✅ |
| 5 | R100-C05 | Web Community Packs prefer Supabase catalog | ✅ |

---

## Acceptance (admin)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R100-A01 | Providers nav/page removed; Plugins menu ships | ✅ |
| 2 | R100-A02 | Register pack by GitHub `manifestUrl`; draft unpublished | ✅ |
| 3 | R100-A03 | Validate fetches manifest + bundle files; writes cached version | ✅ |
| 4 | R100-A04 | Publish / unpublish pack flips catalog visibility | ✅ |
| 5 | R100-A05 | Packs table: filters, sort, column visibility, bulk actions (localStorage) | ✅ |
| 6 | R100-A06 | Product bundle CRUD with ordered pack items | ✅ |
| 7 | R100-A07 | Publish / unpublish bundle | ✅ |
| 8 | R100-A08 | Seed official packs from current ForjaHQ set | ✅ |
| 9 | R100-A22 | Register / validate fetch via admin proxy; normalize GitHub blob → raw `manifest.json` | ✅ |

---

## Acceptance (app)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R100-A09 | Official picker loads published packs from Supabase (`manifest_url`) | ✅ |
| 2 | R100-A10 | Offline / empty → fallback `kOfficialForjaHqPacks` | ✅ |
| 3 | R100-A11 | Published product bundles load from Supabase | ✅ |
| 4 | R100-A12 | Install recommended / best-experience uses published bundle order | ✅ |
| 5 | R100-A13 | Settings Forja Packs can install a published bundle | ✅ |
| 6 | R100-A14 | Existing paste-URL + per-pack update unchanged | ✅ |

---

## Acceptance (web)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R100-A15 | Community Packs prefer published Supabase packs | ✅ |
| 2 | R100-A16 | Static `catalog.json` remains fallback | ✅ |
| 3 | R100-A17 | Public UI still hides install URLs | ✅ |
| 4 | R100-A21 | Web Community Packs are admin-published only — no static `catalog.json` / generated source map | ✅ |

---

## Acceptance (retire RFC-039 remote)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R100-A18 | Admin Providers runtime-config UI deleted | ✅ |
| 2 | R100-A19 | Flutter stops remote `provider_runtime_config` fetch | ✅ |
| 3 | R100-A20 | Dart builtins + call sites kept; debt in [issue 255](../issues/255-[open]-provider-runtime-config-builtins-debt.md) | ✅ |

---

## Summary

Replace the obsolete admin Providers runtime overlay with a **Plugins** ops console. Pack files stay on **GitHub raw**. Supabase stores catalog metadata, publish flags, validation results, and **product bundles** (ordered groups of packs for onboarding). Flutter and web consume the **published** catalog only; install still downloads from GitHub URLs. Web has no static `catalog.json` fallback.

**Bundle** in this RFC = product set of packs. Not RFC-083 `manifest.bundle[]` file lists.

### Related

- [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md) (remote overlay — admin UI retired here)
- [issue 255](../issues/255-[open]-provider-runtime-config-builtins-debt.md)
- [forja-packs](../features/settings/forja-packs.md)
- Migration: `apps/web/supabase/migrations/20260909020003_plugin_catalog_bundles.sql`
