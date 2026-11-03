# 529 — Linux AppImage fails: gtk plugin missing gdk-pixbuf loaders

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** release · Linux AppImage · CI  
**Reported:** 2026-11-03 (GitHub Actions `build_linux` — Package AppImage)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Release Linux job dies in `linuxdeploy --plugin gtk`:

```
cp: cannot stat 'gdk-pixbuf-2.0/2.10.0': No such file or directory
ERROR: Failed to run plugin: gtk
```

No AppImage artifact.

## Root cause

`ubuntu-latest` (24.04+) often lacks the on-disk `gdk-pixbuf-2.0/2.10.0` loaders tree that `linuxdeploy-plugin-gtk` copies. Apt install for the release job did not pull `librsvg2-common` / `libgdk-pixbuf2.0-bin`, so the cache/loaders dir was missing.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I529-T01 | Pin `build_linux` to `ubuntu-22.04` (loaders + older glibc for AppImage) | ✅ |
| 2 | I529-T02 | Install `librsvg2-common` + `libgdk-pixbuf2.0-bin`; refresh loaders cache | ✅ |
| 3 | I529-T03 | Preflight in `package_linux_appimage.sh` when loaders dir missing | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I529-A01 | Re-run Linux release job → AppImage artifact uploads | ⬜ |

## Links

- `scripts/package_linux_appimage.sh`
- `.github/workflows/release.yml` (`build_linux`)
