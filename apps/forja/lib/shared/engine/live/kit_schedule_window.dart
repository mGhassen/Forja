/// Kit schedule sheet axes — Status × Horizon (live schedule product UX).
enum KitScheduleStatus { airing, upcoming, both }

enum KitScheduleHorizon { h1, h3, h6, h24 }

extension KitScheduleStatusX on KitScheduleStatus {
  String get prefToken => switch (this) {
        KitScheduleStatus.airing => 'airing',
        KitScheduleStatus.upcoming => 'upcoming',
        KitScheduleStatus.both => 'both',
      };

  String get label => switch (this) {
        KitScheduleStatus.airing => 'Airing',
        KitScheduleStatus.upcoming => 'Upcoming',
        KitScheduleStatus.both => 'Airing + upcoming',
      };

  String get subtitle => switch (this) {
        KitScheduleStatus.airing =>
          'In-play and 24/7 — including rows without streams yet',
        KitScheduleStatus.upcoming =>
          'Not started yet, within the horizon below',
        KitScheduleStatus.both =>
          'Airing + 24/7, plus upcoming within the horizon',
      };
}

extension KitScheduleHorizonX on KitScheduleHorizon {
  String get prefToken => switch (this) {
        KitScheduleHorizon.h1 => '1h',
        KitScheduleHorizon.h3 => '3h',
        KitScheduleHorizon.h6 => '6h',
        KitScheduleHorizon.h24 => '24h',
      };

  String get label => prefToken;

  String get subtitle {
    final h = switch (this) {
      KitScheduleHorizon.h1 => 1,
      KitScheduleHorizon.h3 => 3,
      KitScheduleHorizon.h6 => 6,
      KitScheduleHorizon.h24 => 24,
    };
    return 'Upcoming kickoffs in the next ${h}h';
  }
}

/// Fresh-install / missing-pref default — Airing only (horizon unused in UI).
const kKitScheduleDefaultPref = 'airing|1h';

const kKitScheduleDefaultWindow = (
  status: KitScheduleStatus.airing,
  horizon: KitScheduleHorizon.h1,
);

/// Pref / kit selection: `status|horizon` (e.g. `airing|1h`, `both|24h`).
String kitScheduleWindowPref({
  required KitScheduleStatus status,
  required KitScheduleHorizon horizon,
}) =>
    '${status.prefToken}|${horizon.prefToken}';

({KitScheduleStatus status, KitScheduleHorizon horizon})?
    kitScheduleWindowFromPref(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('|');
  if (parts.length == 2) {
    final status = _statusFromToken(parts[0]);
    final horizon = _horizonFromToken(parts[1]);
    if (status != null && horizon != null) {
      return (status: status, horizon: horizon);
    }
  }
  return switch (raw.trim().toLowerCase()) {
    'live' || 'airing' => (
        status: KitScheduleStatus.airing,
        horizon: KitScheduleHorizon.h1,
      ),
    'upcoming' => (
        status: KitScheduleStatus.upcoming,
        horizon: KitScheduleHorizon.h24,
      ),
    '1h' => (
        status: KitScheduleStatus.both,
        horizon: KitScheduleHorizon.h1,
      ),
    '3h' => (
        status: KitScheduleStatus.both,
        horizon: KitScheduleHorizon.h3,
      ),
    '6h' => (
        status: KitScheduleStatus.both,
        horizon: KitScheduleHorizon.h6,
      ),
    '12h' || '24h' || 'all' || 'day' || 'both' => (
        status: KitScheduleStatus.both,
        horizon: KitScheduleHorizon.h24,
      ),
    _ => null,
  };
}

KitScheduleStatus? _statusFromToken(String raw) => switch (raw
    .trim()
    .toLowerCase()) {
      'airing' || 'live' => KitScheduleStatus.airing,
      'upcoming' => KitScheduleStatus.upcoming,
      'both' => KitScheduleStatus.both,
      _ => null,
    };

KitScheduleHorizon? _horizonFromToken(String raw) => switch (raw
    .trim()
    .toLowerCase()) {
      '1h' || 'h1' => KitScheduleHorizon.h1,
      '3h' || 'h3' => KitScheduleHorizon.h3,
      '6h' || 'h6' => KitScheduleHorizon.h6,
      '12h' || '24h' || 'h24' || 'all' || 'day' => KitScheduleHorizon.h24,
      _ => null,
    };

/// Top-bar chip: Airing · Next · 3h · 24h (both).
String kitScheduleChipLabel({
  required KitScheduleStatus status,
  required KitScheduleHorizon horizon,
}) {
  final h = horizon.label;
  return switch (status) {
    KitScheduleStatus.airing => 'Airing',
    KitScheduleStatus.upcoming => 'Next · $h',
    KitScheduleStatus.both => h,
  };
}
