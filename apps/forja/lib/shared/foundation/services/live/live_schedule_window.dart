/// Live Sports schedule sheet axes — Status × Horizon (pre-kit product UX).
enum LiveScheduleStatus { airing, upcoming, both }

enum LiveScheduleHorizon { h1, h3, h6, h24 }

extension LiveScheduleStatusX on LiveScheduleStatus {
  String get prefToken => switch (this) {
        LiveScheduleStatus.airing => 'airing',
        LiveScheduleStatus.upcoming => 'upcoming',
        LiveScheduleStatus.both => 'both',
      };

  String get label => switch (this) {
        LiveScheduleStatus.airing => 'Airing',
        LiveScheduleStatus.upcoming => 'Upcoming',
        LiveScheduleStatus.both => 'Airing + upcoming',
      };

  String get subtitle => switch (this) {
        LiveScheduleStatus.airing =>
          'In-play and 24/7 — including rows without streams yet',
        LiveScheduleStatus.upcoming =>
          'Not started yet, within the horizon below',
        LiveScheduleStatus.both =>
          'Airing + 24/7, plus upcoming within the horizon',
      };
}

extension LiveScheduleHorizonX on LiveScheduleHorizon {
  String get prefToken => switch (this) {
        LiveScheduleHorizon.h1 => '1h',
        LiveScheduleHorizon.h3 => '3h',
        LiveScheduleHorizon.h6 => '6h',
        LiveScheduleHorizon.h24 => '24h',
      };

  String get label => prefToken;

  String get subtitle {
    final h = range.future.inHours;
    return 'Upcoming kickoffs in the next ${h}h';
  }

  ({Duration past, Duration future}) get range => switch (this) {
        LiveScheduleHorizon.h1 => (
            past: const Duration(hours: 1),
            future: const Duration(hours: 1),
          ),
        LiveScheduleHorizon.h3 => (
            past: const Duration(hours: 3),
            future: const Duration(hours: 3),
          ),
        LiveScheduleHorizon.h6 => (
            past: const Duration(hours: 3),
            future: const Duration(hours: 6),
          ),
        LiveScheduleHorizon.h24 => (
            past: const Duration(hours: 3),
            future: const Duration(hours: 24),
          ),
      };
}

/// Pref / kit selection: `status|horizon` (e.g. `both|24h`).
String liveScheduleWindowPref({
  required LiveScheduleStatus status,
  required LiveScheduleHorizon horizon,
}) =>
    '${status.prefToken}|${horizon.prefToken}';

({LiveScheduleStatus status, LiveScheduleHorizon horizon})?
    liveScheduleWindowFromPref(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('|');
  if (parts.length == 2) {
    final status = _statusFromToken(parts[0]);
    final horizon = _horizonFromToken(parts[1]);
    if (status != null && horizon != null) {
      return (status: status, horizon: horizon);
    }
  }
  // Flattened kit / v1 tokens → map onto Status × Horizon.
  return switch (raw.trim().toLowerCase()) {
    'live' || 'airing' => (
        status: LiveScheduleStatus.airing,
        horizon: LiveScheduleHorizon.h1,
      ),
    'upcoming' => (
        status: LiveScheduleStatus.upcoming,
        horizon: LiveScheduleHorizon.h24,
      ),
    '1h' => (
        status: LiveScheduleStatus.both,
        horizon: LiveScheduleHorizon.h1,
      ),
    '3h' => (
        status: LiveScheduleStatus.both,
        horizon: LiveScheduleHorizon.h3,
      ),
    '6h' => (
        status: LiveScheduleStatus.both,
        horizon: LiveScheduleHorizon.h6,
      ),
    '12h' || '24h' || 'all' || 'day' || 'both' => (
        status: LiveScheduleStatus.both,
        horizon: LiveScheduleHorizon.h24,
      ),
    _ => null,
  };
}

LiveScheduleStatus? _statusFromToken(String raw) => switch (raw
    .trim()
    .toLowerCase()) {
      'airing' || 'live' => LiveScheduleStatus.airing,
      'upcoming' => LiveScheduleStatus.upcoming,
      'both' => LiveScheduleStatus.both,
      _ => null,
    };

LiveScheduleHorizon? _horizonFromToken(String raw) => switch (raw
    .trim()
    .toLowerCase()) {
      '1h' => LiveScheduleHorizon.h1,
      '3h' => LiveScheduleHorizon.h3,
      '6h' => LiveScheduleHorizon.h6,
      '12h' || '24h' || 'all' || 'day' => LiveScheduleHorizon.h24,
      _ => null,
    };

/// Top-bar chip: Airing · Next · 3h · 24h (both).
String liveScheduleChipLabel({
  required LiveScheduleStatus status,
  required LiveScheduleHorizon horizon,
}) {
  final h = horizon.label;
  return switch (status) {
    LiveScheduleStatus.airing => 'Airing',
    LiveScheduleStatus.upcoming => 'Next · $h',
    LiveScheduleStatus.both => h,
  };
}

bool liveScheduleKickoffMatches({
  required DateTime? start,
  required LiveScheduleStatus status,
  required LiveScheduleHorizon horizon,
  required bool alwaysOn,
  required bool liveOrAiring,
}) {
  final isLiveNow = alwaysOn || liveOrAiring;
  switch (status) {
    case LiveScheduleStatus.airing:
      return isLiveNow;
    case LiveScheduleStatus.upcoming:
      if (isLiveNow) return false;
    case LiveScheduleStatus.both:
      if (isLiveNow) return true;
  }
  if (start == null) return false;
  final now = DateTime.now();
  final range = horizon.range;
  return !start.isBefore(now.subtract(range.past)) &&
      !start.isAfter(now.add(range.future));
}
