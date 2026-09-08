import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optional host hooks for [`kit.topBar`] catalog / schedule actions.
///
/// Packs declare action ids (`catalog`, `horizon`, …). Product sheets and
/// dynamic catalog lists register here — foundation never imports them.
typedef KitTopBarCatalogOptionsLoader = Future<List<({String id, String label})>>
    Function();

typedef KitTopBarCatalogSheetOpener = Future<String?> Function(
  BuildContext context, {
  required String current,
  required List<({String id, String label, String? subtitle})> options,
});

typedef KitTopBarScheduleSheetOpener = Future<void> Function(
  BuildContext context, {
  required String currentPref,
  required void Function(String pref) onChanged,
});

typedef KitTopBarScheduleChipLabel = String Function(String? selectedPref);

typedef KitTopBarScheduleChipSelected = bool Function(String? selectedPref);

/// Optional live schedule pref from host state (overrides layout selection).
typedef KitTopBarSchedulePrefReader = String? Function(WidgetRef ref);

/// Optional trailing chrome after the top-bar [Spacer] (e.g. IPTV Portals).
typedef KitTopBarTrailingBuilder = Widget? Function(
  BuildContext context,
  WidgetRef ref, {
  required String tabId,
  required String rowId,
  required int itemIndex,
  VoidCallback? onLeftEdge,
  VoidCallback? onDownEdge,
});

/// Wrap kit page content *below* the top bar (e.g. Portals over category + list).
typedef KitListBodyWrapper = Widget Function(
  BuildContext context, {
  required Widget child,
  required String tabId,
  required String sourceId,
  required bool shellTabVisible,
});

/// Live schedule scrape progress for the Refresh slot (label + busy).
typedef KitTopBarFeedBusyReader = ({bool busy, String? label}) Function(
  WidgetRef ref,
);

abstract final class KitTopBarHostHooks {
  KitTopBarHostHooks._();

  static KitTopBarCatalogOptionsLoader? loadCatalogOptions;
  static KitTopBarCatalogSheetOpener? openCatalogSheet;
  static KitTopBarScheduleSheetOpener? openScheduleSheet;
  static KitTopBarScheduleChipLabel? scheduleChipLabel;
  static KitTopBarScheduleChipSelected? scheduleChipSelected;
  static KitTopBarSchedulePrefReader? readSchedulePref;
  static KitTopBarTrailingBuilder? buildTrailing;
  static KitListBodyWrapper? wrapListBody;
  static KitTopBarFeedBusyReader? readFeedBusy;

  static void clear() {
    loadCatalogOptions = null;
    openCatalogSheet = null;
    openScheduleSheet = null;
    scheduleChipLabel = null;
    scheduleChipSelected = null;
    readSchedulePref = null;
    buildTrailing = null;
    wrapListBody = null;
    readFeedBusy = null;
  }
}
