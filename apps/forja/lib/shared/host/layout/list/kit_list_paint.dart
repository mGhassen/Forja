import 'package:forja/shared/host/layout/list/kit_list_entry.dart';

/// Pack-emitted kit.list paint fields for EventCard / dense tiles.
///
/// Product heuristics live in the pack (`liveSportsShapeRow`). Host only reads.
class KitListPaint {
  const KitListPaint({
    required this.title,
    required this.poster,
    required this.category,
    required this.dateMs,
    required this.viewers,
    required this.airing,
    required this.alwaysLive,
    required this.timeLabel,
    required this.scheduleLabel,
    this.homeTeam,
    this.homeBadge,
    this.awayTeam,
    this.awayBadge,
  });

  final String title;
  final String poster;
  final String category;
  final int dateMs;
  final int viewers;
  final bool airing;
  final bool alwaysLive;
  final String timeLabel;
  final String scheduleLabel;
  final String? homeTeam;
  final String? homeBadge;
  final String? awayTeam;
  final String? awayBadge;

  bool get isLive => airing || alwaysLive;

  String get categoryLabel =>
      category.isEmpty ? 'Other' : category.replaceAll('-', ' ');

  factory KitListPaint.fromEntry({
    required String metaName,
    required String? metaBadge,
    required List<String> metaGenres,
    required String metaPoster,
    required bool? metaAiring,
    required String? metaStartsAt,
    required int? metaViewers,
    required Map<String, dynamic> row,
  }) {
    String cell(String key) => (row[key] ?? '').toString().trim();
    final title = cell('title').isNotEmpty
        ? cell('title')
        : (cell('name').isNotEmpty ? cell('name') : metaName.trim());
    final category = cell('badge').isNotEmpty
        ? cell('badge')
        : (cell('category').isNotEmpty
            ? cell('category')
            : ((metaBadge ?? '').trim().isNotEmpty
                ? metaBadge!.trim()
                : (metaGenres.isNotEmpty ? metaGenres.first : '')));
    final poster = _abs(cell('poster')).isNotEmpty
        ? _abs(cell('poster'))
        : _abs(metaPoster);
    final alwaysLive = row['alwaysLive'] == true || row['always_live'] == true;
    final airing =
        metaAiring == true || row['airing'] == true || alwaysLive;
    final viewers = () {
      final fromRow = row['viewers'];
      if (fromRow is num) return fromRow.toInt();
      if (fromRow is String) {
        return int.tryParse(fromRow.trim().replaceAll(',', '')) ?? 0;
      }
      return metaViewers ?? 0;
    }();
    final dateMs = () {
      final raw = row['dateMs'] ?? metaStartsAt;
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '').toString().trim()) ?? 0;
    }();
    String? nz(String s) => s.isEmpty ? null : s;
    return KitListPaint(
      title: title,
      poster: poster,
      category: category,
      dateMs: dateMs,
      viewers: viewers,
      airing: airing,
      alwaysLive: alwaysLive,
      timeLabel: cell('timeLabel'),
      scheduleLabel: cell('scheduleLabel'),
      homeTeam: nz(cell('homeTeam')),
      homeBadge: nz(_abs(cell('homeBadge'))),
      awayTeam: nz(cell('awayTeam')),
      awayBadge: nz(_abs(cell('awayBadge'))),
    );
  }

  factory KitListPaint.fromKitEntry(KitListEntry entry) => KitListPaint.fromEntry(
        metaName: entry.meta.name,
        metaBadge: entry.meta.badge,
        metaGenres: entry.meta.genres,
        metaPoster: entry.meta.poster,
        metaAiring: entry.meta.airing,
        metaStartsAt: entry.meta.startsAt,
        metaViewers: entry.meta.viewers,
        row: entry.legacyRow,
      );

  static String _abs(String path) {
    final p = path.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return '';
  }
}
