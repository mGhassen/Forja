# 089 — Windows install fails: MSVCP140.dll not found

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `scripts/bundle_windows_msvc_crt.sh`, Windows release packaging, Inno installer payload

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **0 / 1** acceptance (manual smoke) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I89-T01 | `bundle_windows_msvc_crt.sh` copies x64 `Microsoft.VC*.CRT` DLLs into Release | ✅ |
| 2 | I89-T02 | Release + build CI run bundle before verify; verify requires `msvcp140.dll` + `vcruntime140.dll` | ✅ |
| 3 | I89-T03 | Document app-local CRT (per-user Inno cannot install system VC++ redist) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I89-A01 | Clean Windows (no VC++ redist) install launches past missing-`MSVCP140` error | ⬜ |

---

## Summary

Clean Windows machines without the Visual C++ Redistributable failed at launch with **MSVCP140.dll was not found**. Forja’s native stack (Flutter / Rust / media_kit) is MSVC-linked; the installer only copied the Release folder and did not ship the CRT.

**Why not run `vc_redist.x64.exe` from Inno:** setup uses `PrivilegesRequired=lowest` (per-user). The system redistributable needs elevation; a quiet mid-install UAC is unreliable. Supported fix is **app-local CRT** next to `forja.exe`.

**Fix:** CI copies `msvcp140*.dll` / `vcruntime140*.dll` (and siblings) from the build host’s Visual Studio `x64\Microsoft.VC*.CRT` into `build/windows/x64/runner/Release` before Inno packs `Release\*`. Verify fails the release if `msvcp140.dll` / `vcruntime140.dll` are missing.

**Verify:** Rebuild Windows release with `bundle_windows_msvc_crt.sh`, confirm DLLs beside `forja.exe`, install on a machine without VC++ redist, launch.

## Related

- [Platforms](../features/getting-started/platforms.md)
- [Issue 034](034-[open]-windows-release-missing-libmpv.md) (libmpv packaging)
- [Release workflow](../../.github/workflows/release.yml)
