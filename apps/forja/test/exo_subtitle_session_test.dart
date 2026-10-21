import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/exo/exo_subtitle_session.dart';

Map<String, dynamic> _row(String url, {String lang = 'en', String? source}) => {
  'url': url,
  'lang': lang,
  'language': lang,
  'display': '$lang - ${source ?? 'provider'}',
  'sourceName': ?source,
};

Map<String, String> _sideload(String sourceUrl, {String lang = 'en'}) => {
  'url': 'file:///tmp/${sourceUrl.hashCode}.srt',
  'lang': lang,
  'label': lang,
  'sourceUrl': sourceUrl,
};

void main() {
  group('online row tag', () {
    test('keeps the download headers a row carries', () {
      final tagged = tagOnlineSubtitleRows([
        {
          'url': 'https://online.test/a.srt',
          'origin': 'https://host.test',
          'referer': 'https://host.test/page',
        },
      ]).single;
      expect(isOnlineSubtitleRow(tagged), isTrue);
      expect(tagged['origin'], 'https://host.test');
      expect(tagged['referer'], 'https://host.test/page');
      expect(exoSubtitleOriginKey, isNot('origin'));
    });
  });

  group('externalSubtitleRowsForOpen', () {
    test('two opens with different provider rows do not accumulate', () {
      final ep1Provider = [_row('https://p.test/ep1/en.srt')];
      final online = tagOnlineSubtitleRows([
        _row('https://online.test/a.srt', source: 'levrx'),
        _row('https://online.test/b.srt', lang: 'fr', source: 'subtitlecat'),
      ]);
      final afterEp1 = externalSubtitleRowsForOpen(
        providerRows: ep1Provider,
        previousRows: [...ep1Provider, ...online],
      );
      expect(afterEp1.map((r) => r['url']), [
        'https://p.test/ep1/en.srt',
        'https://online.test/a.srt',
        'https://online.test/b.srt',
      ]);

      final ep2Provider = [_row('https://p.test/ep2/en.srt')];
      final afterEp2 = externalSubtitleRowsForOpen(
        providerRows: ep2Provider,
        previousRows: afterEp1,
      );
      expect(afterEp2.map((r) => r['url']), [
        'https://p.test/ep2/en.srt',
        'https://online.test/a.srt',
        'https://online.test/b.srt',
      ], reason: 'the previous provider row must not survive as an online row');

      final afterEp3 = externalSubtitleRowsForOpen(
        providerRows: [_row('https://p.test/ep3/en.srt')],
        previousRows: afterEp2,
      );
      expect(afterEp3.length, 3, reason: 'count must not grow per open');
    });

    test('a reopen of the same stream keeps rows stable', () {
      final provider = [_row('https://p.test/en.srt')];
      final online = tagOnlineSubtitleRows([
        _row('https://online.test/a.srt', source: 'wyzie'),
      ]);
      var rows = externalSubtitleRowsForOpen(
        providerRows: provider,
        previousRows: [...provider, ...online],
      );
      for (var i = 0; i < 3; i++) {
        rows = externalSubtitleRowsForOpen(
          providerRows: provider,
          previousRows: rows,
        );
      }
      expect(rows.length, 2);
    });

    test('an online row that is also a provider row is listed once', () {
      final provider = [_row('https://both.test/en.srt')];
      final online = tagOnlineSubtitleRows([
        _row('https://both.test/en.srt', source: 'levrx'),
      ]);
      final rows = externalSubtitleRowsForOpen(
        providerRows: provider,
        previousRows: online,
      );
      expect(rows.length, 1);
    });
  });

  group('sideloads', () {
    test(
      'mergeSideloads keeps one entry per source and replaces on repick',
      () {
        final a = _sideload('https://a');
        final b = _sideload('https://b', lang: 'fr');
        final a2 = {..._sideload('https://a'), 'url': 'file:///tmp/a2.srt'};
        final merged = mergeSideloads([a, b], [a2]);
        expect(merged.map((s) => s['sourceUrl']), ['https://b', 'https://a']);
        expect(merged.last['url'], 'file:///tmp/a2.srt');
      },
    );

    test('late flush and manual pick: the pick is in the final list in both '
        'interleavings', () {
      final provider = [_sideload('https://p/en.srt')];
      final late = [_sideload('https://p/fr.srt', lang: 'fr')];
      final pick = _sideload('https://online/fr-levrx.srt', lang: 'fr');

      // Flush first, then the pick lands on top of the flushed list.
      var state = mergeSideloads(provider, late);
      state = mergeSideloads(state, [pick]);
      expect(sideloadSourceUrls(state), contains(pick['sourceUrl']));
      expect(state.length, 3);

      // Pick first, then the late flush merges around it.
      state = mergeSideloads(provider, [pick]);
      state = mergeSideloads(state, late);
      expect(sideloadSourceUrls(state), contains(pick['sourceUrl']));
      expect(state.length, 3);
    });

    test('source switch keeps the picked online sideload, drops the rest', () {
      final previous = [
        _sideload('https://old-provider/en.srt'),
        _sideload('https://online/fr.srt', lang: 'fr'),
        _sideload('https://online/de.srt', lang: 'de'),
      ];
      final next = sideloadsForSourceSwitch(
        providerPrepared: [_sideload('https://new-provider/en.srt')],
        previous: previous,
        selectedUrl: 'https://online/fr.srt',
      );
      expect(next.map((s) => s['sourceUrl']), [
        'https://new-provider/en.srt',
        'https://online/fr.srt',
      ]);
      expect(
        sideloadsForSourceSwitch(
          providerPrepared: [_sideload('https://new-provider/en.srt')],
          previous: previous,
          selectedUrl: null,
        ).length,
        1,
      );
    });

    test('payloads carry the source URL as the sideload id', () {
      final payloads = exoSideloadPayloads([
        _sideload('https://online/fr.srt', lang: 'fr'),
        {..._sideload('http://127.0.0.1:1/hls-proxy?x'), 'mime': 'text/vtt'},
      ]);
      expect(payloads.first[exoSideloadIdKey], 'https://online/fr.srt');
      expect(payloads.first.containsKey('mime'), isFalse);
      expect(payloads.last['mime'], 'text/vtt');
      expect(payloads.last[exoSideloadIdKey], 'http://127.0.0.1:1/hls-proxy?x');
    });
  });

  group('track selection', () {
    const alreadyOnFr = ExoTrackInfo(
      id: '3:0:0',
      label: 'fr',
      language: 'fr',
      selected: true,
      mimeType: 'application/x-subrip',
      formatId: 'https://online/fr-subtitlecat.srt',
    );
    const pickedFr = ExoTrackInfo(
      id: '3:1:0',
      label: 'fr',
      language: 'fr',
      mimeType: 'application/x-subrip',
      formatId: 'https://online/fr-levrx.srt',
    );

    test(
      'the pick lands on its own track, not the first same-language one',
      () {
        final match = exoTextTrackForSideload([
          alreadyOnFr,
          pickedFr,
        ], 'https://online/fr-levrx.srt');
        expect(match?.id, '3:1:0');
        expect(match?.selected, isFalse, reason: 'so the caller selects it');
      },
    );

    test('matches the id behind the merged-period prefix Media3 adds', () {
      const merged = ExoTrackInfo(
        id: '3:1:0',
        label: 'fr',
        language: 'fr',
        formatId: '1:https://online/fr-levrx.srt',
      );
      expect(
        exoSideloadIdOf('1:https://online/fr-levrx.srt'),
        'https://online/fr-levrx.srt',
      );
      expect(exoSideloadIdOf('https://x/1:2.srt'), 'https://x/1:2.srt');
      expect(
        exoTextTrackForSideload([merged], 'https://online/fr-levrx.srt')?.id,
        '3:1:0',
      );
      expect(
        exoEmbeddedTextTracks([merged], {'https://online/fr-levrx.srt'}),
        isEmpty,
      );
      expect(
        selectedSideloadSourceUrl(
          ExoTracksSnapshot(
            textOff: false,
            text: [
              ExoTrackInfo(
                id: '3:1:0',
                label: 'fr',
                language: 'fr',
                selected: true,
                formatId: '1:https://online/fr-levrx.srt',
              ),
            ],
          ),
          {'https://online/fr-levrx.srt'},
        ),
        'https://online/fr-levrx.srt',
      );
    });

    test('a sideload Media3 has not reported yet is not matched', () {
      expect(
        exoTextTrackForSideload([alreadyOnFr], 'https://online/fr-levrx.srt'),
        isNull,
      );
    });

    test('ExoTrackInfo reads formatId from the native map', () {
      final t = ExoTrackInfo.fromMap({
        'id': '3:2:0',
        'label': 'English',
        'language': 'en',
        'formatId': 'https://online/en.srt',
      });
      expect(t.formatId, 'https://online/en.srt');
      expect(ExoTrackInfo.fromMap({'id': '3:0:0'}).formatId, '');
    });
  });

  group('subtitle menu', () {
    const inStream = ExoTrackInfo(
      id: '3:0:0',
      label: 'English',
      language: 'en',
      mimeType: 'text/vtt',
      formatId: 'sub:0',
    );
    const sideloadedEn = ExoTrackInfo(
      id: '3:1:0',
      label: 'en',
      language: 'en',
      selected: true,
      mimeType: 'application/x-subrip',
      formatId: 'https://p/en.srt',
    );

    test('a sideloaded row is listed once — its Media3 twin is hidden', () {
      final twins = {'https://p/en.srt'};
      final embedded = exoEmbeddedTextTracks([inStream, sideloadedEn], twins);
      expect(embedded.map((t) => t.id), ['3:0:0']);
    });

    test('the row of the rendered sideload reads as selected', () {
      const tracks = ExoTracksSnapshot(
        text: [inStream, sideloadedEn],
        textOff: false,
      );
      expect(
        selectedSideloadSourceUrl(tracks, {'https://p/en.srt'}),
        'https://p/en.srt',
      );
      const off = ExoTracksSnapshot(text: [inStream, sideloadedEn]);
      expect(selectedSideloadSourceUrl(off, {'https://p/en.srt'}), isNull);
    });

    test('tracks without format ids stay listed (older native build)', () {
      const noId = ExoTrackInfo(id: '3:0:0', label: 'en', language: 'en');
      expect(exoEmbeddedTextTracks([noId], {'https://p/en.srt'}), [noId]);
    });
  });
}
