import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart';

StreamSource _source(String title) => StreamSource(
      title: title,
      url: 'https://example.com/$title',
      type: 'mp4',
    );

void main() {
  group('PlayerStreamMenu panel provider order', () {
    test('follows settings rank and ignores playback state', () {
      final scoreRows = {
        'vixsrc': ProviderOrderRow(
          id: 'vixsrc',
          settingsRank: 0,
          domainScore: 10,
          effectiveRank: 0,
          maxDisplacement: 2,
          supported: true,
        ),
        'vidlink': ProviderOrderRow(
          id: 'vidlink',
          settingsRank: 1,
          domainScore: 10,
          effectiveRank: 1,
          maxDisplacement: 2,
          supported: true,
        ),
        'vidsrc': ProviderOrderRow(
          id: 'vidsrc',
          settingsRank: 2,
          domainScore: 10,
          effectiveRank: 2,
          maxDisplacement: 2,
          supported: true,
        ),
      };

      final providers = {
        'vixsrc': const {},
        'vidlink': const {},
        'vidsrc': const {},
      };

      final order = PlayerStreamMenu.orderedProviderEntriesForPanel(
        providers,
        scoreRows: scoreRows,
      );

      expect(order.map((e) => e.key).toList(), ['vixsrc', 'vidlink', 'vidsrc']);
    });

    test('does not reorder when probe list reflects a different try order', () {
      final scoreRows = {
        'vixsrc': ProviderOrderRow(
          id: 'vixsrc',
          settingsRank: 0,
          domainScore: 10,
          effectiveRank: 0,
          maxDisplacement: 2,
          supported: true,
        ),
        'vidlink': ProviderOrderRow(
          id: 'vidlink',
          settingsRank: 1,
          domainScore: 10,
          effectiveRank: 1,
          maxDisplacement: 2,
          supported: true,
        ),
      };

      final probes = [
        const StreamProviderProbe(
          id: 'vidlink',
          label: 'VidLink',
          status: StreamProviderProbeStatus.trying,
        ),
        const StreamProviderProbe(
          id: 'vixsrc',
          label: 'VixSrc',
          status: StreamProviderProbeStatus.success,
        ),
      ];

      final order = PlayerStreamMenu.orderedProviderEntriesForPanel(
        {'vixsrc': const {}, 'vidlink': const {}},
        scoreRows: scoreRows,
        probes: probes,
      );

      expect(order.map((e) => e.key).toList(), ['vixsrc', 'vidlink']);
    });

    test('ignores reliability effectiveRank so checking a server does not reshuffle', () {
      // After a check, SourceEngine bumps effectiveRank for the winner while
      // settingsRank stays fixed — panel must keep settings order.
      final scoreRows = {
        'vixsrc': ProviderOrderRow(
          id: 'vixsrc',
          settingsRank: 0,
          domainScore: 10,
          reliabilityScore: 0,
          effectiveRank: 2,
          maxDisplacement: 2,
          supported: true,
        ),
        'vidlink': ProviderOrderRow(
          id: 'vidlink',
          settingsRank: 1,
          domainScore: 10,
          reliabilityScore: 4,
          effectiveRank: 0,
          maxDisplacement: 2,
          supported: true,
        ),
        'vidsrc': ProviderOrderRow(
          id: 'vidsrc',
          settingsRank: 2,
          domainScore: 10,
          reliabilityScore: 2,
          effectiveRank: 1,
          maxDisplacement: 2,
          supported: true,
        ),
      };

      final order = PlayerStreamMenu.orderedProviderEntriesForPanel(
        {
          'vidsrc': const {},
          'vidlink': const {},
          'vixsrc': const {},
        },
        scoreRows: scoreRows,
      );

      expect(order.map((e) => e.key).toList(), ['vixsrc', 'vidlink', 'vidsrc']);
    });
  });

  group('PlayerStreamMenu panel stream order', () {
    test('preserves extraction order regardless of list position', () {
      final sources = [
        _source('stream-a'),
        _source('stream-b'),
        _source('stream-c'),
      ];

      final order = PlayerStreamMenu.orderedSourceEntriesForPanel(sources);

      expect(order.map((e) => e.key).toList(), [0, 1, 2]);
      expect(order.map((e) => e.value.title).toList(), [
        'stream-a',
        'stream-b',
        'stream-c',
      ]);
    });
  });
}
