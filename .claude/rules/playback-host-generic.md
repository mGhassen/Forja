---
paths:
  - "apps/forja/lib/shared/playback/**"
  - "apps/forja/lib/shared/player/**"
  - "apps/forja/lib/shared/engine/**"
---

# Host playback / engine glue stays generic

Read `.cursor/rules/forja-playback-host-generic.mdc` and `.cursor/rules/forja-pack-product-host.mdc` (skill `forja-pack-product-host` for detail).

Sniff test before any edit here: with every pack uninstalled, does this Dart still make sense as a generic capability? No → it belongs in a pack (sibling repo `forja-packs`) or should be deleted. No `open.surface` branches, no hub ids (`anime`, `kisskh`, `anilist`…), no `title`/`poster` field mappers, no product verbs in the kit painter.

Live Sports paths: `.cursor/rules/no-embed-playback.mdc` + `live-catalog-schedule-only.mdc` — native play URL or nothing; catalog rows carry schedule only.
