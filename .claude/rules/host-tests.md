---
paths:
  - "apps/forja/test/**"
---

# Host tests — generic contracts only

Read `.cursor/rules/forja-host-tests-no-pack-contracts.mdc`.

Never assert a shipped plugin id, hub slot, or pack type token. Synthetic fixtures (`test-provider-a`, type `foo`). If uninstalling or renaming a pack would break the assertion, the test does not belong here.

Suite facts: 200+ test files, full run 10+ min. Known-bad on a clean `main`: `catalog_protocol_test.dart`, `sources_panel_filters_nuvio_lazy_test.dart`, and a 10-minute timeout in `forja_logo_halo_pixels_test.dart`. Suite reads the sibling `../forja-packs` tree (or `FORJA_PACKS_ROOT`); without it, pack-dependent tests fail and that is not a regression. Run targeted files: `cd apps/forja && flutter test test/<name>_test.dart`.
