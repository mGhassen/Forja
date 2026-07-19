# 087 — Update dialog shows empty notes while portal has changelogs

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/services/app_updater_service.dart` · R2 release upload · update dialog  
**Reported:** 2026-07-19

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I87-T01 | Release R2 upload mirrors `docs/changelog/done` → `changelog/{version}.md` + `index.json`; never prune `changelog/` | ✅ |
| 2 | I87-T02 | `AppUpdaterService` loads dialog notes from R2 changelog archive (GitHub fallback) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I87-A01 | Next release CI uploads `changelog/*.md` + `index.json` on CDN; installer prune leaves them | ⬜ |
| 2 | I87-A02 | Update dialog on an older build lists every CDN note since installed (left rail) — not “No release notes” | ⬜ |

---

## Summary

The update dialog claimed **No release notes were published** for `v1.2.280 → v1.2.337` while [forjahq.xyz/changelog](https://www.forjahq.xyz/changelog) showed full notes. Installers discover via R2, but notes were fetched only from GitHub Releases (often rate-limited / empty auto bodies). The web portal uses bundled `docs/changelog/done`.

**Root fix:** keep frozen markdown on R2 under `changelog/` (permanent; not pruned with installer retention) and read that from the updater. GitHub remains a fallback only.
