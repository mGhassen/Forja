import 'package:forja/shared/engine/live/schedule_sport_filter.dart';
import 'package:forja/shared/engine/hub/kit_list_source.dart';

/// Presentation fields for a kit.list event card / details hero.
///
/// Built from pack row + [sportMatchGame] + [MetaItem]. Not [MatchEvent].
class KitEventPaint {
  const KitEventPaint({
    required this.title,
    required this.category,
    required this.poster,
    required this.dateMs,
    required this.viewers,
    required this.airing,
    required this.alwaysOn,
    this.homeTeam,
    this.homeBadge,
    this.awayTeam,
    this.awayBadge,
  });

  final String title;
  final String category;
  final String poster;
  final int dateMs;
  final int viewers;
  final bool airing;
  final bool alwaysOn;
  final String? homeTeam;
  final String? homeBadge;
  final String? awayTeam;
  final String? awayBadge;

  bool get isLive => airing || alwaysOn;

  String get categoryLabel =>
      category.isEmpty ? 'Other' : category.replaceAll('-', ' ');

  factory KitEventPaint.fromEntry(KitListEntry entry) {
    final row = entry.legacyRow;
    final game = row['sportMatchGame'];
    final g = game is Map
        ? Map<String, dynamic>.from(game)
        : const <String, dynamic>{};
    final meta = entry.meta;

    String cell(String key) {
      final a = (row[key] ?? '').toString().trim();
      if (a.isNotEmpty) return a;
      return (g[key] ?? '').toString().trim();
    }

    final title = meta.name.trim().isNotEmpty ? meta.name.trim() : cell('title');
    final category = (meta.badge ?? '').trim().isNotEmpty
        ? meta.badge!.trim()
        : (meta.genres.isNotEmpty ? meta.genres.first : cell('category'));
    final poster =
        meta.poster.trim().isNotEmpty ? meta.poster.trim() : cell('poster');
    final catLower = category.toLowerCase();
    final alwaysOn = row['always_live'] == true ||
        row['alwaysLive'] == true ||
        catLower.contains('24/7') ||
        catLower.contains('24-7');
    final rowViewers = parseLiveViewerCount(row['viewers']);
    final metaViewers = meta.viewers ?? 0;
    return KitEventPaint(
      title: title.isEmpty ? cell('name') : title,
      category: category.isEmpty ? cell('sport') : category,
      poster: poster.isEmpty ? cell('posterPath') : poster,
      dateMs: _dateMs(row, g, meta.startsAt),
      viewers: rowViewers > metaViewers ? rowViewers : metaViewers,
      airing: meta.airing == true || row['airing'] == true,
      alwaysOn: alwaysOn,
      homeTeam: _nz(cell('homeTeam')),
      homeBadge: _nz(cell('homeBadge')),
      awayTeam: _nz(cell('awayTeam')),
      awayBadge: _nz(cell('awayBadge')),
    );
  }
}

String? _nz(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

int _dateMs(
  Map<String, dynamic> row,
  Map<String, dynamic> game,
  String? startsAt,
) {
  final raw = row['dateMs'] ?? game['dateMs'] ?? row['startsAt'] ?? startsAt;
  if (raw is num && raw > 0) return raw.toInt();
  final s = (raw ?? '').toString().trim();
  if (s.isEmpty) return 0;
  final n = num.tryParse(s);
  if (n != null && n > 100000) return n.toInt();
  return DateTime.tryParse(s)?.millisecondsSinceEpoch ?? 0;
}

/// Absolute image URLs only. Packs emit them; no host site base.
String kitEventImageUrl(String path) {
  final p = path.trim();
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  return '';
}

String kitEventTimeLabel(KitEventPaint e) {
  if (e.isLive) return 'live';
  if (e.dateMs <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(e.dateMs);
  if (dt.isAfter(DateTime.now())) return _clockHm(dt);
  return '';
}

String kitEventScheduleLabel(KitEventPaint e) {
  if (e.alwaysOn || e.dateMs <= 0) return '';
  return _clockHm(DateTime.fromMillisecondsSinceEpoch(e.dateMs));
}

String _clockHm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
