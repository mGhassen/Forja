import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  test('dedupeStreamSources collapses duplicate urls', () {
    final sources = [
      StreamSource(url: 'https://cdn/a.mp4', title: 'A', type: 'video'),
      StreamSource(url: 'https://cdn/a.mp4', title: 'A copy', type: 'video'),
      StreamSource(url: 'https://cdn/b.m3u8', title: 'B', type: 'video'),
    ];
    final deduped = dedupeStreamSources(sources);
    expect(deduped, hasLength(2));
    expect(deduped.first.url, 'https://cdn/b.m3u8');
    expect(deduped.last.url, 'https://cdn/a.mp4');
  });

  test('dedupeStreamSources deprioritizes h265', () {
    final sources = [
      StreamSource(
        url: 'https://cdn/resource/h265/x.mp4',
        title: 'HEVC',
        type: 'video',
      ),
      StreamSource(
        url: 'https://cdn/resource/h264/x.mp4',
        title: 'H264',
        type: 'video',
      ),
    ];
    final deduped = dedupeStreamSources(sources);
    expect(deduped.first.url, contains('h264'));
  });

  test('StreamSource toJson/fromJson round-trips headers', () {
    final source = StreamSource(
      url: 'https://cdn/a.m3u8',
      title: '1080p',
      type: 'hls',
      headers: {'Referer': 'https://example.com', 'User-Agent': 'Forja'},
    );
    final restored = StreamSource.fromJson(source.toJson());
    expect(restored.url, source.url);
    expect(restored.title, source.title);
    expect(restored.type, source.type);
    expect(restored.headers, source.headers);
  });

  test('collapse merges Yoru height ladder, leaves Breach alone', () {
    final collapsed = collapseStreamQualityVariants([
      StreamSource(
        url: 'https://cdn/yoru-2160.m3u8',
        title: 'Yoru · 2160p',
        type: 'hls',
      ),
      StreamSource(
        url: 'https://cdn/yoru-1080.m3u8',
        title: 'Yoru · 1080p',
        type: 'hls',
      ),
      StreamSource(
        url: 'https://cdn/yoru-720.m3u8',
        title: 'Yoru · 720p',
        type: 'hls',
      ),
      StreamSource(
        url: 'https://cdn/yoru-480.m3u8',
        title: 'Yoru · 480p',
        type: 'hls',
      ),
      StreamSource(
        url: 'https://cdn/breach.m3u8',
        title: 'Breach · playhq',
        type: 'hls',
      ),
      StreamSource(
        url: 'https://cdn/cypher-1080.mp4',
        title: 'Cypher · 1080p',
        type: 'mp4',
      ),
      StreamSource(
        url: 'https://cdn/cypher-480.mp4',
        title: 'Cypher · 480p',
        type: 'mp4',
      ),
      StreamSource(
        url: 'https://cdn/cypher-360.mp4',
        title: 'Cypher · 360p',
        type: 'mp4',
      ),
    ]);

    expect(collapsed, hasLength(3)); // Yoru, Breach, Cypher

    final yoru = collapsed.firstWhere((s) => s.title == 'Yoru');
    expect(yoru.url, 'https://cdn/yoru-2160.m3u8');
    expect(yoru.qualities, isNotNull);
    expect(
      yoru.qualities!.map((q) => q.label).toList(),
      containsAll(['Auto', '2160p', '1080p', '720p', '480p']),
    );

    final breach = collapsed.firstWhere((s) => s.title.contains('Breach'));
    expect(breach.qualities, isNull);
    expect(breach.title, 'Breach · playhq');

    final cypher = collapsed.firstWhere((s) => s.title == 'Cypher');
    expect(cypher.url, 'https://cdn/cypher-1080.mp4');
    expect(
      cypher.qualities!.map((q) => q.label).toList(),
      containsAll(['Auto', '1080p', '480p', '360p']),
    );
  });

  test('dedupeStreamSources also collapses height ladders', () {
    final out = dedupeStreamSources([
      StreamSource(
        url: 'https://cdn/a-1080.mp4',
        title: 'Vyse · 1080',
        type: 'mp4',
      ),
      StreamSource(
        url: 'https://cdn/a-720.mp4',
        title: 'Vyse · 720',
        type: 'mp4',
      ),
    ]);
    expect(out, hasLength(1));
    expect(out.first.qualities, hasLength(3));
  });

  test('StreamSource round-trips qualities', () {
    final source = StreamSource(
      url: 'https://cdn/a.mp4',
      title: 'Yoru',
      type: 'mp4',
      qualities: const [
        StreamQualityOption(
          label: 'Auto',
          url: 'https://cdn/a.mp4',
          isAuto: true,
        ),
        StreamQualityOption(
          label: '720p',
          url: 'https://cdn/a-720.mp4',
          height: 720,
        ),
      ],
    );
    final restored = StreamSource.fromJson(source.toJson());
    expect(restored.qualities, hasLength(2));
    expect(restored.qualities!.last.url, 'https://cdn/a-720.mp4');
  });
}
