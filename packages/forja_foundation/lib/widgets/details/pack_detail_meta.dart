import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/details/facts_panel.dart';

class KitDetailRailSection {
  const KitDetailRailSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<MetaItem> items;
}

List<KitDetailRailSection> parseKitDetailRails(Map<String, dynamic>? data) {
  final rails = data?['rails'];
  if (rails is! Map) return const [];

  final out = <KitDetailRailSection>[];
  for (final entry in rails.entries) {
    final id = entry.key.toString();
    final v = entry.value;
    var title = _defaultRailTitle(id);
    List<MetaItem> items = const [];

    if (v is List) {
      items = _itemsFromJsonList(v);
    } else if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      final custom = (m['title'] ?? '').toString().trim();
      if (custom.isNotEmpty) title = custom;
      items = _itemsFromJsonList(m['items']);
    }

    if (items.isNotEmpty) {
      out.add(KitDetailRailSection(id: id, title: title, items: items));
    }
  }
  return out;
}

List<MetaItem> _itemsFromJsonList(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final it in raw)
      if (it is Map)
        MetaItem.fromJson(Map<String, dynamic>.from(it)),
  ];
}

String _defaultRailTitle(String id) {
  switch (id) {
    case 'related':
      return 'Related';
    case 'recommendations':
      return 'More Like This';
    case 'characters':
      return 'Characters';
    case 'staff':
      return 'Staff';
    default:
      if (id.isEmpty) return '';
      return id[0].toUpperCase() + id.substring(1).replaceAll('_', ' ');
  }
}

final _hubHeroBackdropCache = <String, List<String>>{};
String _hubHeroCacheKey(MetaItem meta) =>
    '${meta.id}|${meta.background}|${meta.bannerImage}|${meta.poster}|${meta.backdrops.join(',')}';

List<String> _packHeroBackdropUrls(MetaItem meta) {
  final cacheKey = _hubHeroCacheKey(meta);
  final cached = _hubHeroBackdropCache[cacheKey];
  if (cached != null) return cached;

  final urls = <String>[];
  void addUrl(String raw) {
    final u = resolveAbsoluteCoverUrl(raw.trim());
    if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
  }

  addUrl(meta.background);
  addUrl(meta.bannerImage);
  addUrl(meta.poster);
  for (final raw in meta.backdrops) {
    addUrl(raw);
  }

  final out = urls.take(12).toList();
  _hubHeroBackdropCache[cacheKey] = out;
  return out;
}

/// Pack / enrich URLs for hero backdrops.
List<String> hubHeroBackdropUrls(MetaItem meta) =>
    _packHeroBackdropUrls(meta);

String? hubMetaLogoUrl(MetaItem meta) {
  final u = resolveAbsoluteCoverUrl(meta.logo.trim());
  return u.isEmpty ? null : u;
}

/// Pack enrich fact bag → foundation fact rows for [DetailsHero].
List<MapEntry<String, String>> kitPackFactRows(
  MetaItem meta, {
  int? positionMs,
  int? durationMs,
}) {
  final facts = meta.facts;
  if (facts == null || facts.isEmpty) return const [];
  final rows = factsRowsFromFields(
    title: meta.name,
    mediaType: (facts['mediaType'] ?? meta.tmdbMediaType ?? '').toString(),
    runtimeMinutes: (facts['runtimeMinutes'] as num?)?.toInt() ?? 0,
    releaseDate: (facts['releaseDate'] ?? meta.premiereDate).toString(),
    seasonCount: (facts['seasonCount'] as num?)?.toInt() ?? 0,
    episodeCount: (facts['episodeCount'] as num?)?.toInt() ?? 0,
    status: facts['status']?.toString(),
    budget: (facts['budget'] as num?)?.toInt(),
    revenue: (facts['revenue'] as num?)?.toInt(),
    languageCode: facts['originalLanguage']?.toString(),
    spokenLanguages: _stringList(facts['spokenLanguages']),
    productionCompanies: _stringList(facts['productionCompanies']),
    originCountries: _stringList(facts['originCountries']),
    lastAirDate: facts['lastAirDate']?.toString(),
    networks: _stringList(facts['networks']),
    creators: _stringList(facts['creators']),
    positionMs: positionMs,
    durationMs: durationMs,
  );
  return [for (final r in rows) MapEntry(r.label, r.value)];
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e.toString().trim().isNotEmpty) e.toString().trim(),
  ];
}
