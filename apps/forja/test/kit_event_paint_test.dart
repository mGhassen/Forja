import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/host/kit/kit_event_paint.dart';
import 'package:forja/shared/host/kit/kit_list_source.dart';
import 'package:forja_foundation/protocol/protocol.dart';

KitListEntry _entry({
  required String name,
  Map<String, dynamic>? row,
  String? poster,
  String? badge,
  bool? airing,
  int? viewers,
}) {
  return KitListEntry(
    meta: MetaItem(
      id: name,
      type: 'live_match',
      name: name,
      poster: poster ?? '',
      badge: badge,
      airing: airing,
      viewers: viewers,
    ),
    legacyRow: {
      'title': name,
      ...?row,
    },
    kind: 'football',
  );
}

void main() {
  test('fromEntry prefers meta + sportMatchGame over empty row fields', () {
    final e = _entry(
      name: 'Home vs Away',
      poster: 'https://cdn.example/poster.jpg',
      badge: 'football',
      airing: true,
      viewers: 12,
      row: {
        'sportMatchGame': {
          'homeTeam': 'Home',
          'awayTeam': 'Away',
          'homeBadge': 'https://cdn.example/h.png',
          'awayBadge': 'https://cdn.example/a.png',
        },
        'viewers': 40,
      },
    );
    final p = KitEventPaint.fromEntry(e);
    expect(p.title, 'Home vs Away');
    expect(p.category, 'football');
    expect(p.poster, 'https://cdn.example/poster.jpg');
    expect(p.homeTeam, 'Home');
    expect(p.awayTeam, 'Away');
    expect(p.homeBadge, 'https://cdn.example/h.png');
    expect(p.airing, isTrue);
    expect(p.viewers, 40);
    expect(p.isLive, isTrue);
  });

  test('kitEventImageUrl keeps absolute URLs and drops relative tokens', () {
    expect(
      kitEventImageUrl('https://streamed.pk/api/images/badge/x.webp'),
      'https://streamed.pk/api/images/badge/x.webp',
    );
    expect(kitEventImageUrl('/api/images/badge/x.webp'), '');
    expect(kitEventImageUrl('arsenal'), '');
    expect(kitEventImageUrl(''), '');
  });

  test('alwaysOn from 24/7 category', () {
    final p = KitEventPaint.fromEntry(
      _entry(name: 'Loop', badge: '24-7'),
    );
    expect(p.alwaysOn, isTrue);
    expect(p.isLive, isTrue);
    expect(kitEventScheduleLabel(p), '');
  });
}
