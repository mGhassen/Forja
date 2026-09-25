import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/downloads/download_page_store.dart';
import 'package:forja/shared/downloads/download_source_match.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja_foundation/protocol/protocol.dart';

void main() {
  test('drama stays its own download type', () {
    final drama = MetaItem(
      id: 'kk:1',
      type: 'tv',
      name: 'Show',
      open: const MetaOpen(surface: 'drama', id: '1'),
    );
    expect(downloadTypeForMeta(drama), 'drama');
    expect(downloadHubKind('drama'), 'asian_drama');
  });

  test('first finished file is the lowest episode', () {
    final early = _task(season: 1, episode: 2, at: DateTime.utc(2026, 1, 2));
    final first = _task(season: 1, episode: 1, at: DateTime.utc(2026, 1, 3));
    final other = _task(
      mediaId: 'other',
      season: 1,
      episode: 1,
      at: DateTime.utc(2026, 1, 1),
    );
    expect(
      firstCompletedDownload([early, other, first], 'tt1')?.episode,
      1,
    );
  });

  test('details keep only downloaded episodes', () {
    final item = MetaItem(
      id: 'tt1',
      type: 'tv',
      name: 'Show',
      videos: const [
        MetaVideo(id: 'a', title: 'One', season: 1, episode: 1),
        MetaVideo(id: 'b', title: 'Two', season: 1, episode: 2),
      ],
    );
    final filtered = filterMetaToDownloadedEpisodes(
      item,
      [_task(season: 1, episode: 2, at: DateTime.utc(2026))],
      'tt1',
    );
    expect(filtered.videos.map((v) => v.episode).toList(), [2]);
  });

  test('downloaded tab labels files by episode', () {
    final rows = downloadedTitleStreams(
      tasks: [_task(season: 2, episode: 3, at: DateTime.utc(2026))],
      mediaId: 'tt1',
    );
    expect(rows.single['title'], 'S02E03 · Castle');
  });

  test('imdb row id is the download media id', () {
    final item = MetaItem(
      id: 'tt22526100',
      type: 'movie',
      name: 'The Love Hypothesis',
      open: const MetaOpen(surface: 'offline', id: 'tt22526100'),
    );
    expect(mediaIdForMetaItem(item), 'tt22526100');
  });

  test('saved file is listed when the bag has the imdb id', () {
    final rows = downloadedTitleStreams(
      tasks: [
        _task(
          mediaId: 'tt22526100',
          season: null,
          episode: null,
          at: DateTime.utc(2026),
        ),
      ],
      mediaId: '999001',
      ids: const ['tt22526100', '999001'],
    );
    expect(rows, hasLength(1));
  });
}

DownloadTask _task({
  String mediaId = 'tt1',
  int? season,
  int? episode,
  required DateTime at,
}) {
  return DownloadTask(
    id: 'd-$season-$episode',
    title: 'Show',
    mediaId: mediaId,
    type: 'series',
    season: season,
    episode: episode,
    sourceName: 'Castle',
    targetFilePath: '/tmp/show.mp4',
    status: DownloadStatus.completed,
    createdAt: at,
    completedAt: at,
  );
}
