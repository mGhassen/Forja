import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_task.dart';

DownloadTask _task({
  required String id,
  required String url,
  required String path,
  DownloadStatus status = DownloadStatus.completed,
  String sourceName = 'MegaPlay',
}) {
  return DownloadTask(
    id: id,
    title: 'Made in Abyss - S01E01',
    mediaId: 'tt1',
    type: 'anime',
    season: 1,
    episode: 1,
    sourceName: sourceName,
    rawUrl: url,
    targetFilePath: path,
    status: status,
    createdAt: DateTime.utc(2026, 9, 30),
  );
}

void main() {
  test('a second source for the same episode is a new stream', () {
    final saved = _task(
      id: 'a',
      url: 'https://cdn.example/a.m3u8',
      path: '/tmp/Show_S01E01_MegaPlay.mp4',
    );
    expect(
      downloadTaskForRawUrl([saved], 'https://cdn.example/b.m3u8'),
      isNull,
    );
    expect(
      downloadTaskForRawUrl([saved], 'https://cdn.example/a.m3u8')?.id,
      'a',
    );
  });

  test('two sources get different file names', () {
    final taken = <String>{};
    final first = uniqueDownloadTargetPath(
      directory: '/tmp/Forja',
      baseFilename: 'Show_S01E01',
      extension: '.mp4',
      sourceName: 'HiAnime · MegaPlay',
      taken: taken.contains,
    );
    taken.add(first);
    final second = uniqueDownloadTargetPath(
      directory: '/tmp/Forja',
      baseFilename: 'Show_S01E01',
      extension: '.mp4',
      sourceName: 'Anikoto · HD-1',
      taken: taken.contains,
    );
    expect(first, isNot(second));
    expect(first, contains('MegaPlay'));
    expect(second, contains('HD-1'));
  });

  test('a repeated source name gets a numeric suffix', () {
    const path = '/tmp/Forja/Show_S01E01_MegaPlay.mp4';
    final next = uniqueDownloadTargetPath(
      directory: '/tmp/Forja',
      baseFilename: 'Show_S01E01',
      extension: '.mp4',
      sourceName: 'MegaPlay',
      taken: (candidate) => candidate == path,
    );
    expect(next, '/tmp/Forja/Show_S01E01_MegaPlay_2.mp4');
  });
}
