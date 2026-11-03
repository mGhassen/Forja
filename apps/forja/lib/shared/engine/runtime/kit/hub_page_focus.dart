import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/runtime/kit/focus_edge.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';

/// Pack page `focus` map — opaque row ids only. Host executes; no product ids.
///
/// ```json
/// "focus": {
///   "enter": "hero-details",
///   "restore": "hero-details",
///   "restoreMode": "remembered",
///   "pageBack": ["items", "cats"]
/// }
/// ```
///
/// `hero-details` lands the spotlight View details CTA (not a [TvKitRow]).
class HubPageFocus {
  const HubPageFocus({
    this.enter,
    this.restore,
    this.restoreRemembered = true,
    this.pageBack = const [],
  });

  static const empty = HubPageFocus();

  /// OK / enter from nav rail.
  final String? enter;

  /// RIGHT from nav (preferCustom when set).
  final String? restore;

  /// When true, land on last index in [restore]/ else index 0.
  final bool restoreRemembered;

  /// Remote Back ladder: leaf → … → outer. Outermost miss → shell nav.
  final List<String> pageBack;

  bool get isEmpty =>
      (enter == null || enter!.isEmpty) &&
      (restore == null || restore!.isEmpty) &&
      pageBack.isEmpty;

  String get signature =>
      '${enter ?? ''}|${restore ?? ''}|$restoreRemembered|${pageBack.join(',')}';

  /// Parse from page map (`pages.<tab>.focus`) or root layout `focus`.
  static HubPageFocus parse(Map<String, dynamic>? pageOrRoot) {
    if (pageOrRoot == null) return empty;
    final raw = pageOrRoot['focus'];
    if (raw is! Map) return empty;
    final map = Map<String, dynamic>.from(raw);
    final enter = _id(map['enter']);
    final restore = _id(map['restore']);
    final mode = (map['restoreMode'] ?? map['mode'] ?? 'remembered')
        .toString()
        .trim()
        .toLowerCase();
    final remembered = mode != 'first' && mode != 'index0';
    final backRaw = map['pageBack'] ?? map['back'];
    final pageBack = <String>[];
    if (backRaw is List) {
      for (final e in backRaw) {
        final id = _id(e);
        if (id != null) pageBack.add(id);
      }
    }
    return HubPageFocus(
      enter: enter,
      restore: restore,
      restoreRemembered: remembered,
      pageBack: List.unmodifiable(pageBack),
    );
  }

  static String? _id(Object? raw) {
    final s = (raw ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}

/// Bind pack [HubPageFocus] into [TvHeroActions] for [tabId].
///
/// Empty [focus] clears custom restore preference only — leave enter/restore
/// unset so hero [defaultFocus] / tab memory remain the land path.
///
/// [landFallback] runs when the pack enter/restore row and content rows miss
/// (e.g. IPTV selected Live/Movies/Series shelf while the category rail is
/// covered by a portal load ticker).
void bindHubPageFocus(
  String tabId,
  HubPageFocus focus, {
  VoidCallback? landFallback,
}) {
  if (tabId.isEmpty) return;

  if (focus.isEmpty) {
    ShellTvFocusCoordinator.clearTabEnterRestore(tabId);
    ShellTvFocusCoordinator.setPageBackOnRowLeftEdge(tabId, false);
    return;
  }

  bool land(String? rowId, {required bool remembered}) {
    final id = (rowId ?? '').trim();
    if (id.isEmpty) {
      if (ShellTvFocusCoordinator.focusFirstContentRow(tabId)) return true;
      if (landFallback != null) {
        landFallback();
        return true;
      }
      return ShellTvFocusCoordinator.focusChromeRow(tabId);
    }
    // Pack `enter` / `restore`: `hero-details` — same as kit focusUp edge.
    // Miss returns false so enter retries wait (never treat sticky CW as land).
    if (id == kHubHeroDetailsFocusId) {
      return ShellTvFocusCoordinator.focusHero(revealFull: true, tabId: tabId);
    }
    if (remembered) {
      if (ShellTvFocusCoordinator.focusRowItemRemembered(tabId, id)) {
        return true;
      }
    }
    if (ShellTvFocusCoordinator.focusRowItem(tabId, id, 0)) return true;
    if (ShellTvFocusCoordinator.focusFirstContentRow(tabId)) return true;
    if (landFallback != null) {
      landFallback();
      return true;
    }
    return ShellTvFocusCoordinator.focusChromeRow(tabId);
  }

  bool enter() {
    // Same remembered land as restore — selected/last chip, not always index 0.
    return land(focus.enter, remembered: focus.restoreRemembered);
  }

  bool restore() {
    return land(
      focus.restore ?? focus.enter,
      remembered: focus.restoreRemembered,
    );
  }

  bool pageBack() {
    final ladder = focus.pageBack;
    if (ladder.isEmpty) return false;
    for (var i = 0; i < ladder.length; i++) {
      if (!_rowActive(tabId, ladder[i])) continue;
      if (i + 1 >= ladder.length) return false;
      land(ladder[i + 1], remembered: true);
      return true;
    }
    return false;
  }

  final hasRestore = (focus.restore ?? focus.enter)?.isNotEmpty == true;
  final hasEnter = focus.enter?.isNotEmpty == true;
  final hasBack = focus.pageBack.isNotEmpty;

  // Always replace enter/restore — registerTabDefaults merges and would keep
  // a stale Featured restore after Home dropped pack `restore`.
  ShellTvFocusCoordinator.clearTabEnterRestore(tabId);
  // Same for pageBack: null merge leaves a prior rail ladder (Back → Featured).
  if (!hasBack) ShellTvFocusCoordinator.clearTabPageBack(tabId);

  TvHeroActions.bind(
    tabId,
    enterFromNavFocus: hasEnter ? enter : null,
    restoreFocus: hasRestore ? restore : null,
    preferCustomRestoreFromNav: hasRestore,
    pageBack: hasBack ? pageBack : null,
  );
  ShellTvFocusCoordinator.setTabEnterAwaitsHero(
    tabId,
    focus.enter == kHubHeroDetailsFocusId,
  );
  ShellTvFocusCoordinator.setPageBackOnRowLeftEdge(tabId, hasBack);
}

bool _rowActive(String tabId, String rowId) {
  final handle = ShellTvFocusCoordinator.rowHandle(tabId, rowId);
  if (handle != null && handle.itemCount > 0) {
    for (var i = 0; i < handle.itemCount; i++) {
      try {
        if (handle.nodeAt(i)?.hasFocus ?? false) return true;
      } catch (_) {}
    }
  }
  final mem = ShellTvFocusCoordinator.memoryFor(tabId);
  return mem?.rowId == rowId;
}
