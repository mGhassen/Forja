import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

const kKitListOpenModeDefault = 'panel';

/// Read kit.list `openSetting` (e.g. Live Sports `matchOpen`) from pack prefs.
Future<String> resolveListOpenMode({
  required String pluginId,
  required String? openSettingId,
  required String layoutOpen,
}) async {
  final field = (openSettingId ?? '').trim();
  final fallback = layoutOpen.trim().isEmpty
      ? kKitListOpenModeDefault
      : layoutOpen.trim().toLowerCase();
  if (field.isEmpty || pluginId.trim().isEmpty) return fallback;
  final raw = await PackSettingsStore.getString(
    pluginId,
    field,
    defaultValue: fallback,
  );
  final v = raw.trim().toLowerCase();
  return v.isEmpty ? fallback : v;
}

/// Listenable that bumps when pack settings change (open mode, etc.).
ValueListenable<int> get packSettingsRevisionListenable =>
    PackSettingsStore.revision;

/// How a schedule/list tap should open after resolving [openMode].
///
/// Live Sports declares `openSetting` / `panelTabs`. Those must never fall
/// through to `open.surface:live` (hub tab re-request is a no-op). Panel needs
/// chrome + room to dock (or Android TV); otherwise open the detail page.
enum KitListTapOpen { panel, details, openTap }

/// Whether a kit list may paint / open the docked streams side panel.
///
/// Matches [SidePanelOverlay.defaultUseSideRail]: wide layouts dock; Android TV
/// always docks even when Portals (or nav) leaves the list strip under
/// [ShellTokens.sidePanelWideBreakpoint].
bool kitListCanShowSidePanel({
  required bool hasChrome,
  required double layoutWidth,
  bool androidTv = false,
}) {
  if (!hasChrome) return false;
  if (androidTv) return true;
  return layoutWidth >= ShellTokens.sidePanelWideBreakpoint;
}

KitListTapOpen resolveKitListTapOpen({
  required String openMode,
  required bool hasMatchOpenSurface,
  required bool canShowSidePanel,
}) {
  var mode = openMode.trim().toLowerCase();
  if (mode.isEmpty && hasMatchOpenSurface) mode = 'panel';
  // Settings select can store the option label if id lookup misses.
  if (mode == 'side panel' || mode == 'sidepanel' || mode == 'side-panel') {
    mode = 'panel';
  }
  if (mode == 'detail' || mode == 'detail page' || mode == 'detailpage') {
    mode = 'details';
  }
  if (mode == 'panel') {
    return canShowSidePanel ? KitListTapOpen.panel : KitListTapOpen.details;
  }
  if (mode == 'details' || hasMatchOpenSurface) {
    return KitListTapOpen.details;
  }
  return KitListTapOpen.openTap;
}
