import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shared/downloads/hls_subtitle_sidecar.dart';

void main() {
  test('keeps the subtitle group named by the chosen variant', () {
    const master = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="sub-hi",NAME="Hindi",LANGUAGE="hi",URI="hi.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="sub-en",NAME="English",LANGUAGE="en",URI="en.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=1000,SUBTITLES="sub-en"
low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=8000,SUBTITLES="sub-hi"
high.m3u8
''';
    final picked = hlsSubtitleRenditions(
      playlist: master,
      playlistUri: Uri.parse('https://cdn.example/master.m3u8'),
      variantUri: Uri.parse('https://cdn.example/high.m3u8'),
    );
    expect(picked, hasLength(1));
    expect(picked.single.language, 'hi');
    expect(picked.single.uri.toString(), 'https://cdn.example/hi.m3u8');
  });

  test('shifts a reset cue clock and a timestamp map onto one file', () {
    const first = '''
WEBVTT

00:00:00.000 --> 00:00:01.000
Hello
''';
    const mapped = '''
WEBVTT
X-TIMESTAMP-MAP=MPEGTS:90000,LOCAL:00:00:00.000

00:00:00.000 --> 00:00:01.000
There
''';
    final merged = mergeWebVttParts([
      const HlsSubtitleSegmentPart(duration: 2, body: first),
      const HlsSubtitleSegmentPart(duration: 2, body: mapped),
    ]);
    expect(merged, contains('00:00:00.000 --> 00:00:01.000'));
    expect(merged, contains('Hello'));
    expect(merged, contains('00:00:01.000 --> 00:00:02.000'));
    expect(merged, contains('There'));
  });

  test('adds playlist duration when the next segment starts again at zero', () {
    const cue = '''
WEBVTT

00:00:00.000 --> 00:00:01.000
Again
''';
    final merged = mergeWebVttParts([
      const HlsSubtitleSegmentPart(duration: 4, body: cue),
      const HlsSubtitleSegmentPart(duration: 4, body: cue),
    ]);
    expect(merged, contains('00:00:00.000 --> 00:00:01.000'));
    expect(merged, contains('00:00:04.000 --> 00:00:05.000'));
  });

  test('saves stream subtitle rows next to the video and lists them', () async {
    final dir = await Directory.systemTemp.createTemp('forja_subs_');
    addTearDown(() => dir.delete(recursive: true));
    final video = '${dir.path}/ep.mp4';
    await File(video).writeAsString('x');
    // An in-stream track already saved by the HLS path stays in the index.
    await Directory('$video.subs').create();
    await File('$video.subs/en.vtt').writeAsString('WEBVTT\n\n');
    await File('$video.subs.json').writeAsString(
      jsonEncode({
        'tracks': [
          {'name': 'English', 'language': 'en', 'file': 'en.vtt'},
        ],
      }),
    );
    final fetched = <String>[];
    await saveStreamSubtitleRows(
      videoPath: video,
      rows: [
        {
          'url': 'https://cdn.example/en.vtt',
          'language': 'en',
          'name': 'English',
          'sourceName': 'Castle',
        },
        {
          'url': 'https://cdn.example/fr.srt',
          'language': 'fr',
          'name': 'French',
          'sourceName': 'Castle',
        },
        {'url': 'https://cdn.example/bad', 'language': 'de', 'name': 'German'},
      ],
      fetchText: (uri) async {
        fetched.add(uri.toString());
        if (uri.path.endsWith('bad')) return '<html>nope</html>';
        if (uri.path.endsWith('.srt')) {
          return '1\n00:00:01,000 --> 00:00:02,000\nSalut\n';
        }
        return 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n';
      },
    );
    expect(fetched, hasLength(3));
    expect(await File('$video.subs/en-2.vtt').exists(), isTrue);
    expect(await File('$video.subs/fr.srt').exists(), isTrue);
    final rows = await offlineSavedSubtitleRows(video);
    expect(rows.map((r) => r['name']), ['English', 'English', 'French']);
    expect(rows[0]['sourceName'], kInStreamSubtitleSourceName);
    expect(rows[1]['sourceName'], 'Castle');
    expect(rows[2]['url'], endsWith('/fr.srt'));
  });

  test('saves inline subtitle text without a fetch', () async {
    final dir = await Directory.systemTemp.createTemp('forja_subs_');
    addTearDown(() => dir.delete(recursive: true));
    final video = '${dir.path}/ep.mp4';
    await saveStreamSubtitleRows(
      videoPath: video,
      rows: [
        {
          'content': 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHi\n',
          'language': 'ar',
          'name': 'Arabic',
        },
      ],
      fetchText: (_) async => throw StateError('no fetch expected'),
    );
    final rows = await offlineSavedSubtitleRows(video);
    expect(rows, hasLength(1));
    expect(rows.single['language'], 'ar');
  });

  test('download task keeps its subtitle rows through json', () {
    final task = DownloadTask(
      id: 't',
      title: 'T',
      mediaId: 'm',
      type: 'movie',
      sourceName: 'Castle',
      targetFilePath: '/tmp/t.mp4',
      subtitles: const [
        {'url': 'https://cdn.example/en.vtt', 'language': 'en', 'name': 'En'},
      ],
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    final back = DownloadTask.fromJson(
      jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>,
    );
    expect(back.subtitles, task.subtitles);
    expect(back.copyWith(status: DownloadStatus.completed).subtitles,
        task.subtitles);
  });
}
