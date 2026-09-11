import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/host/kit/kit_list_source.dart';

/// Host adapters for [`KitTypes.list`] product branches (RFC-106 G11).
///
/// Kit stays generic: opaque [listSource] + hooks. Live schedule registers
/// from `shared/host/live_sports`.
typedef KitListStyleResolver = String? Function(
  WidgetRef ref, {
  required String listSource,
  required String layoutStyle,
});

/// Event-search query string for a list source (empty = no filter UI).
typedef KitListEventQueryReader = String Function(
  WidgetRef ref,
  String listSource,
);

/// Filter [entries] by host event query (live schedule search).
typedef KitListEntriesFilter = List<KitListEntry> Function(
  String listSource,
  List<KitListEntry> entries,
  String eventQuery,
);

/// Return true to omit [kind] from dynamic kind chips.
typedef KitListKindFilter = bool Function(String listSource, String kind);

/// Viewers count for a dense list row (live schedule).
typedef KitListEntryViewersReader = int Function(KitListEntry entry);

/// Grid metrics for cards style (host owns card aspect — e.g. KitEventCard).
typedef KitListCardsGridLayout = ({
  int columns,
  double cardW,
  double cardH,
  double gap,
  double leading,
  double topPad,
  double rightPad,
});

typedef KitListCardsGridLayoutBuilder = KitListCardsGridLayout Function(
  BuildContext context, {
  required double maxWidth,
  required double chromeTop,
});

/// One cards-style cell for [listSource] (MatchEvent card lives in host).
typedef KitListCardsEntryBuilder = Widget Function(
  BuildContext context, {
  required KitListEntry entry,
  required int index,
  required int columns,
  required double cardW,
  required double cardH,
  required bool selected,
  required String tabId,
  required String gridRowId,
  VoidCallback? onUpEdge,
  VoidCallback? onRightEdge,
  required VoidCallback onTap,
});

abstract final class KitListHostHooks {
  KitListHostHooks._();

  static KitListStyleResolver? resolveStyle;
  static KitListEventQueryReader? readEventQuery;
  static KitListEntriesFilter? filterEntries;
  static KitListKindFilter? omitKind;
  static KitListEntryViewersReader? entryViewers;
  static KitListCardsGridLayoutBuilder? cardsGridLayout;
  static KitListCardsEntryBuilder? buildCardsEntry;

  static void clear() {
    resolveStyle = null;
    readEventQuery = null;
    filterEntries = null;
    omitKind = null;
    entryViewers = null;
    cardsGridLayout = null;
    buildCardsEntry = null;
  }
}
