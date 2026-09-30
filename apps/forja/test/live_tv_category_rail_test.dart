import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/live/hooks/resolve_streams_adapter.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart';

void main() {
  LivePlaySource channel({
    required String name,
    required String category,
    required String portal,
  }) {
    return LivePlaySource(
      url: 'http://tstv8k.example/live/1.ts',
      label: name,
      detail: category,
      liveProviderBadge: portal,
    );
  }

  test('Live TV rail is the IPTV category, not the portal host', () {
    final rows = ResolveStreamsAdapter.rowsForTest('live_tv', [
      channel(name: 'CANAL+ FHD', category: 'FR | CANAL', portal: 'tstv8k.com'),
      channel(name: 'beIN 1', category: 'Sports', portal: 'tstv8k.com'),
    ]);
    expect(rows.map((r) => r.subtitle), ['FR · CANAL', 'Sports']);
    expect(rows.every((r) => r.subtitle != 'tstv8k.com'), isTrue);
  });

  test('Providers rail stays the provider name', () {
    final rows = ResolveStreamsAdapter.rowsForTest('providers', [
      channel(name: 'Stream', category: 'Sports', portal: 'PPV'),
    ]);
    expect(rows.single.subtitle, 'PPV');
  });
}
