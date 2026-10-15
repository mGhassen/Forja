// kit.list → CatalogCardsGrid kinds. Pack declares cardKind / style / paint.type;
// host only aliases — no open.surface product heuristics.

/// Pack / style / paint aliases → foundation grid kind.
const Map<String, String> kKitListCardKindAliases = {
  'poster': 'poster',
  'event': 'event',
  'eventcard': 'event',
  'cards': 'event',
  'dense': 'dense',
  'list': 'dense',
  'timeline': 'dense',
  'channel': 'channel',
  'livechannel': 'channel',
  'channellist': 'channelList',
  'guide': 'guide',
  'epg': 'guide',
};

/// Paint envelope `type` → grid kind (when list omits `cardKind`).
const Map<String, String> kKitListPaintTypeCardKinds = {
  'postercard': 'poster',
  'poster': 'poster',
  'eventcard': 'event',
  'event': 'event',
  'channelcard': 'channel',
  'channel': 'channel',
};

bool kitListCardKindIsChannel(String cardKind) {
  final k = cardKind.trim();
  return k == 'channel' || k == 'channelList';
}

bool kitListCardKindIsVertical(String cardKind) {
  final k = cardKind.trim();
  return k == 'dense' || k == 'list' || k == 'timeline' || k == 'channelList';
}

/// Resolve grid paint kind from pack contract, then style, then item paint.
String resolveKitListCardKind({
  required String packCardKind,
  required String style,
  List<Map<String, dynamic>> items = const [],
}) {
  final fromPack = kKitListCardKindAliases[packCardKind.trim().toLowerCase()];
  if (fromPack != null) return fromPack;

  final s = style.trim().toLowerCase();
  final fromPaint = _cardKindFromPaint(items);

  // List / timeline: channel paint → row list; else dense (event rows, etc.).
  if (s == 'list' || s == 'timeline') {
    if (fromPaint == 'channel') return 'channelList';
    return 'dense';
  }
  if (s == 'guide' || s == 'epg') return 'guide';
  if (fromPaint != null) return fromPaint;
  if (s == 'cards') return 'event';
  return 'poster';
}

String? _cardKindFromPaint(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return null;
  final counts = <String, int>{};
  for (final item in items.take(12)) {
    final paint = item['paint'];
    if (paint is! Map) continue;
    final type = (paint['type'] ?? '').toString().trim().toLowerCase();
    final kind = kKitListPaintTypeCardKinds[type];
    if (kind == null) continue;
    counts[kind] = (counts[kind] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  String? best;
  var bestN = 0;
  counts.forEach((kind, n) {
    if (n > bestN) {
      best = kind;
      bestN = n;
    }
  });
  return best;
}

/// Side-panel / openSetting lists — no My List pin / Open-in on the grid.
bool kitListManagedOpen(Map<String, dynamic> spec) {
  if ((spec['openSetting'] ?? '').toString().trim().isNotEmpty) return true;
  final tabs = spec['panelTabs'];
  return tabs is List && tabs.isNotEmpty;
}
