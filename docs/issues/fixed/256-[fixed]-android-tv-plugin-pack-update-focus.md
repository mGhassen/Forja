# 256 — Android TV plugin pack update dialog: D-pad stays on shell

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Plugin pack update confirm · Android TV D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I256-T01 | `PluginPackUpdatePromptHost` wraps shell in `ExcludeFocus` + `IgnorePointer` while confirm is open | ✅ |
| 2 | I256-T02 | Confirm overlay claims **Update all** with owned `FocusNode` + post-frame retries (same class as I173) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I256-A01 | Widget test: overlay over autofocus background — primary focus is `plugin-update-confirm` | ✅ |
| 2 | I256-A02 | Android TV: open pack update confirm — focus lands on **Update all**; OK does not activate the poster behind | ⬜ |

---

## Summary

Opening the plugin pack update confirm left D-pad focus on the Home poster (or other shell content) under the dimmed barrier. The dialog painted on top, but **Update all** stayed unfocused.

**Root cause:** The host stacked the overlay over the live shell without excluding background focus, and a single post-frame `requestFocus` lost to shell reclaim (e.g. after `openSettings`).

**Root fix:** Exclude / ignore the shell while the confirm is open; claim **Update all** with retries under `TvOverlayScope` (`autofocusFirst: false`).

## Related

- [173](../173-[open]-android-tv-update-dialog-focus-leak.md) — app update gate focus leak
- `apps/forja/lib/shared/engine/packs/plugin_pack_update_prompt_host.dart`
- `apps/forja/lib/shared/engine/packs/plugin_pack_update_dialog.dart`
- `apps/forja/test/plugin_pack_update_focus_test.dart`
