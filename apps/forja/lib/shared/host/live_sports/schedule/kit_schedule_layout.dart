import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/host/live_sports/schedule/kit_schedule_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// List/cards style for Live Sports (`live_schedule`) kit lists. Default: list.
final kitScheduleLayoutProvider =
    NotifierProvider<KitScheduleLayoutNotifier, String>(
  KitScheduleLayoutNotifier.new,
);

class KitScheduleLayoutNotifier extends Notifier<String> {
  @override
  String build() {
    Future.microtask(_hydrate);
    return KitSchedulePrefs.styleList;
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (await KitSchedulePrefs.getString(
          prefs,
          KitSchedulePrefs.styleKey,
        ))
            ?.trim()
            .toLowerCase();
    final next = raw == KitSchedulePrefs.styleCards
        ? KitSchedulePrefs.styleCards
        : KitSchedulePrefs.styleList;
    if (next != state) state = next;
  }

  Future<void> setStyle(String style) async {
    final next = style.trim().toLowerCase() == KitSchedulePrefs.styleCards
        ? KitSchedulePrefs.styleCards
        : KitSchedulePrefs.styleList;
    if (next == state) return;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(KitSchedulePrefs.styleKey, next);
  }

  Future<void> toggleStyle() async {
    await setStyle(
      state == KitSchedulePrefs.styleCards
          ? KitSchedulePrefs.styleList
          : KitSchedulePrefs.styleCards,
    );
  }
}
