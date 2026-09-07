import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/live_matches/live_schedule/data/live_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Catalog / sport / schedule-horizon filters for Live Sports kit browse.
@immutable
class LiveScheduleFilters {
  const LiveScheduleFilters({
    this.catalogFilter = 'all',
    this.sportFilter = 'all',
    this.scheduleHorizon = '24h',
  });

  final String catalogFilter;
  final String sportFilter;
  final String scheduleHorizon;

  LiveScheduleFilters copyWith({
    String? catalogFilter,
    String? sportFilter,
    String? scheduleHorizon,
  }) =>
      LiveScheduleFilters(
        catalogFilter: catalogFilter ?? this.catalogFilter,
        sportFilter: sportFilter ?? this.sportFilter,
        scheduleHorizon: scheduleHorizon ?? this.scheduleHorizon,
      );

  @override
  bool operator ==(Object other) =>
      other is LiveScheduleFilters &&
      other.catalogFilter == catalogFilter &&
      other.sportFilter == sportFilter &&
      other.scheduleHorizon == scheduleHorizon;

  @override
  int get hashCode =>
      Object.hash(catalogFilter, sportFilter, scheduleHorizon);
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
    final catalog =
        prefs.getString(LivePrefs.catalogFilterKey)?.trim() ?? 'all';
    final schedule = prefs.getString(LivePrefs.scheduleKey)?.trim() ?? '24h';
    final next = LiveScheduleFilters(
      catalogFilter: catalog.isEmpty ? 'all' : catalog,
      scheduleHorizon: schedule.isEmpty ? '24h' : schedule,
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

  Future<void> setScheduleHorizon(String value) async {
    final v = value.trim().isEmpty ? '24h' : value.trim();
    state = state.copyWith(scheduleHorizon: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LivePrefs.scheduleKey, v);
  }
}

/// Shared TV focus row ids for Live Sports browse chrome (RFC-073 A07).
abstract final class LiveSportsTvRows {
  LiveSportsTvRows._();

  static const tabId = 'live_matches';
  static const topBar = 'live-top-bar';
  static const sportChips = 'sport-chips';
  static const grid = 'schedule';
  static const streamsTabs = 'live-streams-tabs';
  static const streamsChrome = 'live-streams-chrome';
  static const streamsList = 'live-streams-list';
  static const streamsCats = 'live-streams-cats';
}
