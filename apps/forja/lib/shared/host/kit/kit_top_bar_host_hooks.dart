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

/// Optional catalog chip filter from host state (overrides layout selection).
typedef KitTopBarCatalogPrefReader = String? Function(WidgetRef ref);

typedef KitTopBarCatalogChipLabel = String Function(
  String? filter,
  List<({String id, String label})> options,
);

typedef KitTopBarCatalogChipSelected = bool Function(String? filter);

/// Persist catalog chip pick (mirrors schedule sheet → prefs).
typedef KitTopBarCatalogFilterWriter = Future<void> Function(
  BuildContext context,
  String filter,
);

/// Pack-declared top-bar action (`action` / `id`) → host widget.
///
/// Packs list actions in `kit.topBar`; the host never invents trailing chrome.
/// Features register opaque verbs here (e.g. `portals` → IPTV chip).
typedef KitTopBarPackActionBuilder = Widget? Function(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, dynamic> action,
  required String tabId,
  required String rowId,
  required int itemIndex,
  VoidCallback? onDownEdge,
  VoidCallback? onLeftEdge,
  VoidCallback? onRightEdge,
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

/// Session scrape age for the Refresh slot (e.g. `Updated 3m ago`).
typedef KitTopBarFeedUpdatedReader = String? Function(WidgetRef ref);

abstract final class KitTopBarHostHooks {
  KitTopBarHostHooks._();

  static KitTopBarCatalogOptionsLoader? loadCatalogOptions;
  static KitTopBarCatalogSheetOpener? openCatalogSheet;
  static KitTopBarScheduleSheetOpener? openScheduleSheet;
  static KitTopBarScheduleChipLabel? scheduleChipLabel;
  static KitTopBarScheduleChipSelected? scheduleChipSelected;
  static KitTopBarSchedulePrefReader? readSchedulePref;
  static KitTopBarCatalogPrefReader? readCatalogPref;
  static KitTopBarCatalogChipLabel? catalogChipLabel;
  static KitTopBarCatalogChipSelected? catalogChipSelected;
  static KitTopBarCatalogFilterWriter? writeCatalogFilter;

  /// Verb → builder. Keys are pack `action` (preferred) or `id`.
  static final Map<String, KitTopBarPackActionBuilder> packActionBuilders = {};

  static KitListBodyWrapper? wrapListBody;
  static KitTopBarFeedBusyReader? readFeedBusy;
  static KitTopBarFeedUpdatedReader? readFeedUpdatedLabel;

  static void clear() {
    loadCatalogOptions = null;
    openCatalogSheet = null;
    openScheduleSheet = null;
    scheduleChipLabel = null;
    scheduleChipSelected = null;
    readSchedulePref = null;
    readCatalogPref = null;
    catalogChipLabel = null;
    catalogChipSelected = null;
    writeCatalogFilter = null;
    packActionBuilders.clear();
    wrapListBody = null;
    readFeedBusy = null;
    readFeedUpdatedLabel = null;
  }
}
