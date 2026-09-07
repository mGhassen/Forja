import 'package:flutter/widgets.dart';

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

abstract final class KitTopBarHostHooks {
  KitTopBarHostHooks._();

  static KitTopBarCatalogOptionsLoader? loadCatalogOptions;
  static KitTopBarCatalogSheetOpener? openCatalogSheet;
  static KitTopBarScheduleSheetOpener? openScheduleSheet;
  static KitTopBarScheduleChipLabel? scheduleChipLabel;
  static KitTopBarScheduleChipSelected? scheduleChipSelected;

  static void clear() {
    loadCatalogOptions = null;
    openCatalogSheet = null;
    openScheduleSheet = null;
    scheduleChipLabel = null;
    scheduleChipSelected = null;
  }
}
