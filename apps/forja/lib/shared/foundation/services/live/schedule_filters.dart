import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/foundation/services/live/live_prefs.dart';
import 'package:forja/shared/foundation/services/live/live_schedule_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Catalog / sport / schedule-window filters for Live Sports kit browse.
@immutable
class LiveScheduleFilters {
  const LiveScheduleFilters({
    this.catalogFilter = 'all',
    this.sportFilter = 'all',
    this.scheduleStatus = LiveScheduleStatus.both,
    this.scheduleHorizon = LiveScheduleHorizon.h24,
  });

  final String catalogFilter;
  final String sportFilter;
  final LiveScheduleStatus scheduleStatus;
  final LiveScheduleHorizon scheduleHorizon;

  String get schedulePref => liveScheduleWindowPref(
        status: scheduleStatus,
        horizon: scheduleHorizon,
      );

  LiveScheduleFilters copyWith({
    String? catalogFilter,
    String? sportFilter,
    LiveScheduleStatus? scheduleStatus,
    LiveScheduleHorizon? scheduleHorizon,
  }) =>
      LiveScheduleFilters(
        catalogFilter: catalogFilter ?? this.catalogFilter,
        sportFilter: sportFilter ?? this.sportFilter,
        scheduleStatus: scheduleStatus ?? this.scheduleStatus,
        scheduleHorizon: scheduleHorizon ?? this.scheduleHorizon,
      );

  @override
  bool operator ==(Object other) =>
      other is LiveScheduleFilters &&
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

final liveScheduleFiltersProvider =
    NotifierProvider<LiveScheduleFiltersNotifier, LiveScheduleFilters>(
  LiveScheduleFiltersNotifier.new,
);

class LiveScheduleFiltersNotifier extends Notifier<LiveScheduleFilters> {
  @override
  LiveScheduleFilters build() {
    Future.microtask(_hydrate);
    return const LiveScheduleFilters();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final catalog = (await LivePrefs.getStringMigrated(
          prefs,
          LivePrefs.catalogFilterKey,
          LivePrefs.legacyCatalogFilterKey,
        ))
            ?.trim() ??
        'all';
    final scheduleRaw = (await LivePrefs.getStringMigrated(
      prefs,
      LivePrefs.scheduleKey,
      LivePrefs.legacyScheduleKey,
    ))
        ?.trim();
    final window = liveScheduleWindowFromPref(scheduleRaw) ??
        (
          status: LiveScheduleStatus.both,
          horizon: LiveScheduleHorizon.h24,
        );
    final next = LiveScheduleFilters(
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
    await prefs.setString(LivePrefs.catalogFilterKey, v);
  }

  Future<void> setSportFilter(String value) async {
    final v = value.trim().isEmpty ? 'all' : value.trim();
    state = state.copyWith(sportFilter: v);
  }

  Future<void> setScheduleWindow({
    LiveScheduleStatus? status,
    LiveScheduleHorizon? horizon,
  }) async {
    final next = state.copyWith(
      scheduleStatus: status,
      scheduleHorizon: horizon,
    );
    if (next == state) return;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LivePrefs.scheduleKey, next.schedulePref);
  }

  /// Kit layout / legacy single-token write (`both|24h`, `live`, `3h`, …).
  Future<void> setScheduleFromPrefToken(String value) async {
    final window = liveScheduleWindowFromPref(value);
    if (window == null) return;
    await setScheduleWindow(
      status: window.status,
      horizon: window.horizon,
    );
  }
}

/// Shared TV focus row ids for Live Sports browse chrome (RFC-073 A07).
/// Zone ids only — not pack nav tab ids.
abstract final class LiveSportsTvRows {
  LiveSportsTvRows._();

  static const focusZone = 'live_sports';
  static const topBar = 'live-top-bar';
  static const sportChips = 'sport-chips';
  static const grid = 'schedule';
  static const streamsTabs = 'live-streams-tabs';
  static const streamsChrome = 'live-streams-chrome';
  static const streamsList = 'live-streams-list';
  static const streamsCats = 'live-streams-cats';
}
