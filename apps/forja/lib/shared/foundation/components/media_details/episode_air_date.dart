import 'package:flutter/material.dart';

/// Parsed air-date metadata for an episode list row.
class EpisodeAirDateInfo {
  const EpisodeAirDateInfo({this.label, this.notShippedYet = false});

  final String? label;
  final bool notShippedYet;
}

const _monthLabels = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Reads [air_date] / [release_date] and optional [aired] from a season episode map.
EpisodeAirDateInfo episodeAirDateInfo(Map<String, dynamic> ep) {
  final raw =
      (ep['air_date'] ?? ep['release_date'] ?? '').toString().trim();
  final aired = ep['aired'];
  if (aired == false) {
    return EpisodeAirDateInfo(
      label: raw.isNotEmpty ? formatEpisodeDisplayDate(raw) : null,
      notShippedYet: true,
    );
  }
  if (raw.isEmpty) return const EpisodeAirDateInfo();
  return EpisodeAirDateInfo(
    label: formatEpisodeDisplayDate(raw),
    notShippedYet: isFutureIsoDate(raw),
  );
}

/// `true` when [iso] is a calendar date strictly after today (local).
bool isFutureIsoDate(String iso) {
  final parsed = _parseIsoDate(iso);
  if (parsed == null) return false;
  final today = DateTime.now();
  final airDay = DateTime(parsed.year, parsed.month, parsed.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  return airDay.isAfter(todayDay);
}

/// Formats `YYYY-MM-DD` (or longer ISO) as `Mon D, YYYY`.
String formatEpisodeDisplayDate(String iso) {
  final parsed = _parseIsoDate(iso);
  if (parsed == null) {
    return iso.length >= 10 ? iso.substring(0, 10) : iso;
  }
  return '${_monthLabels[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
}

DateTime? _parseIsoDate(String iso) {
  if (iso.length < 10) return null;
  final parts = iso.substring(0, 10).split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

Color episodeDateColor({
  required bool notShippedYet,
  required Color normal,
}) {
  return notShippedYet ? Colors.orange.shade300 : normal;
}
