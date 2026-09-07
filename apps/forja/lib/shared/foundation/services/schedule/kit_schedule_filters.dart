import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/foundation/services/schedule/kit_schedule_prefs.dart';
import 'package:forja/shared/foundation/services/schedule/kit_schedule_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Catalog / sport / schedule-window filters for Live Sports kit browse.
@immutable
class KitScheduleFilters {
  const KitScheduleFilters({
    this.catalogFilter = 'all',
    this.sportFilter = 'all',
    this.scheduleStatus = KitScheduleStatus.both,
    this.scheduleHorizon = KitScheduleHorizon.h24,
  });

  final String catalogFilter;
  final String sportFilter;
  final KitScheduleStatus scheduleStatus;
  final KitScheduleHorizon scheduleHorizon;

  String get schedulePref => kitScheduleWindowPref(
        status: scheduleStatus,
        horizon: scheduleHorizon,
      );

  KitScheduleFilters copyWith({
    String? catalogFilter,
    String? sportFilter,
    KitScheduleStatus? scheduleStatus,
    KitScheduleHorizon? scheduleHorizon,
  }) =>
      KitScheduleFilters(
        catalogFilter: catalogFilter ?? this.catalogFilter,
        sportFilter: sportFilter ?? this.sportFilter,
        scheduleStatus: scheduleStatus ?? this.scheduleStatus,
        scheduleHorizon: scheduleHorizon ?? this.scheduleHorizon,
      );

  @override
  bool operator ==(Object other) =>
      other is KitScheduleFilters &&
      other.catalogFilter == catalogFilter &&
      other.sportFilter == sportFilter &&
      other.scheduleStatus == scheduleStatus &&
      other.scheduleHorizon == scheduleHorizon;

  @override
  int get hashCode => Object.hash(
        catalogFilter,
        sportFilter,
        scheduleStatus,
        scheduleHorizon,
      );
}

final kitScheduleFiltersProvider =
    NotifierProvider<KitScheduleFiltersNotifier, KitScheduleFilters>(
  KitScheduleFiltersNotifier.new,
);

class KitScheduleFiltersNotifier extends Notifier<KitScheduleFilters> {
  @override
  KitScheduleFilters build() {
    Future.microtask(_hydrate);
    return const KitScheduleFilters();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final catalog = (await KitSchedulePrefs.getString(
          prefs,
          KitSchedulePrefs.catalogFilterKey,
        ))
            ?.trim() ??
        'all';
    final scheduleRaw = (await KitSchedulePrefs.getString(
      prefs,
      KitSchedulePrefs.scheduleKey,
    ))
        ?.trim();
    final window = kitScheduleWindowFromPref(scheduleRaw) ??
        (
          status: KitScheduleStatus.both,
          horizon: KitScheduleHorizon.h24,
        );
    final next = KitScheduleFilters(
      catalogFilter: catalog.isEmpty ? 'all' : catalog,
      scheduleStatus: window.status,
      scheduleHorizon: window.horizon,
    );
    if (next != state) state = next;
  }

  Future<void> setCatalogFilter(String value) async {
    final v = value.trim().isEmpty ? 'all' : value.trim();
    state = state.copyWith(catalogFilter: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(KitSchedulePrefs.catalogFilterKey, v);
  }

  Future<void> setSportFilter(String value) async {
    final v = value.trim().isEmpty ? 'all' : value.trim();
    state = state.copyWith(sportFilter: v);
  }

  Future<void> setScheduleWindow({
    KitScheduleStatus? status,
    KitScheduleHorizon? horizon,
  }) async {
    final next = state.copyWith(
      scheduleStatus: status,
      scheduleHorizon: horizon,
    );
    if (next == state) return;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(KitSchedulePrefs.scheduleKey, next.schedulePref);
  }

  /// Kit layout / legacy single-token write (`both|24h`, `live`, `3h`, …).
  Future<void> setScheduleFromPrefToken(String value) async {
    final window = kitScheduleWindowFromPref(value);
    if (window == null) return;
    await setScheduleWindow(
      status: window.status,
      horizon: window.horizon,
    );
  }
}

/// Shared TV focus row ids for schedule browse chrome.
abstract final class ScheduleTvFocus {
  ScheduleTvFocus._();

  static const focusZone = 'live_sports';
  static const topBar = 'live-top-bar';
  static const sportChips = 'sport-chips';
  static const grid = 'schedule';
  static const streamsTabs = 'live-streams-tabs';
  static const streamsChrome = 'live-streams-chrome';
  static const streamsList = 'live-streams-list';
  static const streamsCats = 'live-streams-cats';
}
