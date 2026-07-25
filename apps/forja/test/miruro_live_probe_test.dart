// Live Miruro pipe probe - run with:
//   flutter test test/miruro_live_probe_test.dart --dart-define=LIVE_MIRURO=1
//
// Needs network + macOS WebView (CF). Skipped unless LIVE_MIRURO=1.

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/anime/catalog/miruro_pipe_session.dart';
import 'package:rust/rust.dart';

const _live = bool.fromEnvironment('LIVE_MIRURO', defaultValue: false);

/// Dan Da Dan - known Miruro/Anikoto coverage (AniList 171018 / 132029).
const _anilistId = 132029;
const _episode = 1;
const _category = 'sub';

String _hostOf(String url) {
  final u = Uri.tryParse(url);
  return u?.host ?? url;
}

String _classifyCdn(String url) {
  final u = url.toLowerCase();
  if (u.contains('owocdn') || u.contains('kwik')) return 'owocdn/kwik';
  if (u.contains('nekostream') ||
      u.contains('kotocdn') ||
      u.contains('mewstream') ||
      u.contains('megaplay') ||
      u.contains('ibyteimg') ||
      u.contains('byteimg') ||
      u.contains('lostproject') ||
      u.contains('vivibebe')) {
    return 'megaplay-family';
  }
  if (u.contains('.mp4') || u.contains('allmanga') || u.contains('fast4speed')) {
    return 'mp4/direct';
  }
  if (u.contains('.m3u8')) return 'hls-other';
  return 'other';
}

String _recommendedProbe(Set<String> classes) {
  if (classes.contains('megaplay-family')) return 'segmentPoisonSample';
  if (classes.contains('mp4/direct') && !classes.contains('hls-other')) {
    return 'headOrRange';
  }
  if (classes.contains('owocdn/kwik') || classes.contains('hls-other')) {
    return 'masterOnly';
  }
  return 'masterOnly';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'live Miruro providers: CDN class + recommended probe',
    () async {
      final rows = <String>[];
      for (final prov in miruroKnownProviders) {
        MiruroPipeSession.instance.cancelPending();
        try {
          final resolved = await miruroResolveWithCfFallback(
            anilistId: _anilistId,
            episodeNumber: _episode,
            category: _category,
            provider: prov,
            fetchPipeViaWebView: MiruroPipeSession.instance.get,
          );
          final streams = resolved.streams;
          if (streams.isEmpty) {
            rows.add(
              '$prov\tEMPTY\tcf=${resolved.cfBlocked}\t→ keep masterOnly (no data)',
            );
            continue;
          }
          final classes = <String>{};
          final hosts = <String>{};
          for (final s in streams.take(6)) {
            classes.add(_classifyCdn(s.url));
            hosts.add(_hostOf(s.url));
          }
          final probe = _recommendedProbe(classes);
          rows.add(
            '$prov\tn=${streams.length}\t$classes\t'
            'hosts=${hosts.take(3).join(",")}\t→ $probe',
          );
        } catch (e) {
          rows.add('$prov\tERROR\t$e\t→ keep masterOnly');
        }
      }
      MiruroPipeSession.instance.dispose();

      // Print for operator - assertion is "we got at least one live hit".
      // ignore: avoid_print
      print('\n=== MIRURO LIVE PROBE anilist=$_anilistId ep$_episode ===');
      for (final r in rows) {
        // ignore: avoid_print
        print(r);
      }
      expect(
        rows.any((r) => r.contains('n=') && !r.contains('EMPTY')),
        isTrue,
        reason: 'expected at least one Miruro provider to return streams',
      );
    },
    skip: _live ? false : 'Set --dart-define=LIVE_MIRURO=1',
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
