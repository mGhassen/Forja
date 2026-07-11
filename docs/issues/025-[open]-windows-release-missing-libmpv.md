# 025 — Windows release missing libmpv-2.dll (white screen at launch)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/pubspec.yaml`, `scripts/verify_installer_payload.sh`, Windows/Linux release packaging

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I25-T01 | Add `media_kit_libs_windows_video`, `media_kit_libs_linux`, `media_kit_libs_ios_video` to app `dependencies` | ✅ |
| 2 | I25-T02 | CI: `verify_installer_payload.sh` requires libmpv DLL/SO in release output | ✅ |
| 3 | I25-T03 | Manual smoke: Windows installer launches past splash (not white screen) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I25-A01 | Installed Windows build contains `libmpv-2.dll` next to `forja.exe`; app reaches splash without `MediaKit.ensureInitialized` crash | ⬜ |

---

## Summary

Windows release showed a blank white window immediately after install. Running `forja.exe` from CMD showed:

```
media_kit: WARNING: package:media_kit_libs_* not found.
Exception: Cannot find libmpv-2.dll ...
#3 bootstrapForja → MediaKit.ensureInitialized()
```

**Root cause:** `media_kit_libs_windows_video` (and Linux/iOS equivalents) lived only under `dependency_overrides` in [`apps/forja/pubspec.yaml`](../../apps/forja/pubspec.yaml). Overrides pin versions but do not register Flutter plugins or copy native libraries. macOS/Android worked because their `media_kit_libs_*` packages were direct `dependencies`.

**Symptom:** Native window appears (transparent → white) then process dies on uncaught exception before `runApp()`.

**Fix shipped in repo:** platform lib packages added to `dependencies`; verify script fails release if libmpv is missing from the build output.

**Verify:** Rebuild Windows release, confirm `build/windows/x64/runner/Release/libmpv-2.dll` exists, install and launch.

## Related

- [Platforms feature doc](../features/getting-started/platforms.md)
- [Release workflow](../../.github/workflows/release.yml)
