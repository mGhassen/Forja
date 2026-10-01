import 'package:flutter/foundation.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';

/// Host-owned hero CTA row id ([HeroPillPlayButton] `tvRowId`) — item node
/// only, not a [TvKitRow]. Pack `focusUp: 'hero-details'` lands via
/// [ShellTvFocusCoordinator.focusHero] (reveal + defaultFocus).
const kHubHeroDetailsFocusId = 'hero-details';

/// Focus a pack row by id. Marks [ShellTvFocusCoordinator.markKitEdgeMiss] when
/// the row is missing so [shellTvHandleRowArrows] can fall through instead of
/// swallowing the key (Live schedule → sources-kind with panel closed).
///
/// [last] restores the remembered index on the row.
/// [lastItem] focuses the final index (`itemCount - 1`) — used for pack
/// `focusRight: portals` on ↑ from the right half → chrome Portals chip
/// (not the open portals panel list).
///
/// Pack top-bar `portals` + [lastItem] → trailing chrome chip.
/// Shelf chips (Live / Movies / Series) are focused via
/// [kitFocusChromeAt] from the layout painter (selected item index).
///
/// [down]: when true, prefer a registered `{rowId}-shuffle` chrome row if it
/// has items (e.g. pack `focusDown: 'because'` → `because-shuffle` when the
/// shuffle control is mounted). ↑ keeps landing on the named rail itself.
///
/// [kHubHeroDetailsFocusId] reveals the hero and focuses View details.
VoidCallback? kitFocusEdge(
  String tabId,
  String? rowId, {
  bool last = false,
  bool lastItem = false,
  bool down = false,
}) {
  if (rowId == null || rowId.isEmpty) return null;
  final id = rowId.trim();
  if (id.isEmpty) return null;
  return () {
    var target = id;
    var useLastItem = lastItem;
    if (down) {
      final chrome = '$id-shuffle';
      final shuffle = ShellTvFocusCoordinator.rowHandle(tabId, chrome);
      if (shuffle != null && shuffle.itemCount > 0) {
        target = chrome;
      }
    }
    // Portals chip lives on the chrome row; the open panel is also `portals`.
    if (target == 'portals' && useLastItem) {
      target = 'chrome';
      useLastItem = true;
    }
    // Hero View details is defaultFocus + item node — not a TvKitRow handle.
    if (target == kHubHeroDetailsFocusId) {
      if (ShellTvFocusCoordinator.focusHero(revealFull: true, tabId: tabId)) {
        return;
      }
      ShellTvFocusCoordinator.markKitEdgeMiss();
      return;
    }
    final bool ok;
    if (useLastItem) {
      final handle = ShellTvFocusCoordinator.rowHandle(tabId, target);
      if (handle == null || handle.itemCount <= 0) {
        ok = false;
      } else {
        final index = handle.itemCount - 1;
        ok = ShellTvFocusCoordinator.focusRowItemRemembered(
          tabId,
          target,
          index: index,
        );
      }
    } else if (last) {
      ok = ShellTvFocusCoordinator.focusRowItemRemembered(tabId, target);
    } else {
      // Remembered+retry: hero ↓ → Featured while posters remount after a
      // Films / Categories flip (itemCount can lead attached FocusNodes).
      final remembered = ShellTvFocusCoordinator.focusRowItemRemembered(
        tabId,
        target,
        index: 0,
      );
      if (remembered) {
        ok = true;
      } else {
        var landed = ShellTvFocusCoordinator.focusRowItem(tabId, target, 0);
        // Item-only registrations (no TvKitRow) — Exact falls back to itemNode.
        if (!landed) {
          landed = ShellTvFocusCoordinator.focusRowItemExact(tabId, target, 0);
        }
        ok = landed;
      }
    }
    if (!ok) ShellTvFocusCoordinator.markKitEdgeMiss();
  };
}

/// Focus chrome slot [index] (e.g. selected Live / Movies / Series chip).
VoidCallback kitFocusChromeAt(String tabId, int index) {
  return () {
    final ok = ShellTvFocusCoordinator.focusRowItem(tabId, 'chrome', index) ||
        ShellTvFocusCoordinator.focusRowItemExact(tabId, 'chrome', index);
    if (!ok) ShellTvFocusCoordinator.markKitEdgeMiss();
  };
}

/// Pack `focusLeft` / `focusRight` — restore last index on the named row.
VoidCallback? kitFocusSide(String tabId, Object? rowId) {
  return kitFocusEdge(tabId, rowId?.toString(), last: true);
}
