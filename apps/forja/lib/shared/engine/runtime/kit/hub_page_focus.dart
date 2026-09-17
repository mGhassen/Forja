import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';

/// Pack page `focus` map — opaque row ids only. Host executes; no product ids.
///
/// ```json
/// "focus": {
///   "enter": "cats",
///   "restore": "cats",
///   "restoreMode": "remembered",
///   "pageBack": ["items", "cats"]
/// }
/// ```
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
void bindHubPageFocus(String tabId, HubPageFocus focus) {
  if (tabId.isEmpty) return;

  if (focus.isEmpty) {
    TvHeroActions.bind(tabId, preferCustomRestoreFromNav: false);
    ShellTvFocusCoordinator.setPageBackOnRowLeftEdge(tabId, false);
    return;
  }

  void land(String? rowId, {required bool remembered}) {
    final id = (rowId ?? '').trim();
    if (id.isEmpty) {
      ShellTvFocusCoordinator.focusFirstContentRow(tabId);
      return;
    }
    if (remembered) {
      if (ShellTvFocusCoordinator.focusRowItemRemembered(tabId, id)) return;
    }
    if (ShellTvFocusCoordinator.focusRowItem(tabId, id, 0)) return;
    ShellTvFocusCoordinator.focusFirstContentRow(tabId);
  }

  void enter() {
    land(focus.enter, remembered: false);
  }

  bool restore() {
    land(
      focus.restore ?? focus.enter,
      remembered: focus.restoreRemembered,
    );
    return true;
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

  TvHeroActions.bind(
    tabId,
    enterFromNavFocus: hasEnter ? enter : null,
    restoreFocus: hasRestore ? restore : null,
    preferCustomRestoreFromNav: hasRestore,
    pageBack: hasBack ? pageBack : null,
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
