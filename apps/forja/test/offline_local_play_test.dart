import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/downloads/download_guards.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_source_match.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shared/playback/probe/playback_stream_guards.dart';

void main() {
  test('completed download plays the on-disk file', () async {
    final dir = await Directory.systemTemp.createTemp('forja-offline-');
    final file = File('${dir.path}/title.mp4');
    await file.writeAsBytes(const [
      0,
      0,
      0,
      0x18,
      0x66,
      0x74,
      0x79,
      0x70,
      0x69,
      0x73,
      0x6f,
      0x6d,
    ]);
    final task = DownloadTask(
      id: 'dl-1',
      title: 'Title',
      mediaId: '1',
      type: 'movie',
      sourceName: 'Example',
      rawUrl: 'https://cdn.example/master.m3u8',
      targetFilePath: file.path,
      status: DownloadStatus.completed,
      createdAt: DateTime.utc(2026, 9, 25),
    );
    final local = await offlineLocalPlayForTask(
      stream: {
        'url': 'https://cdn.example/master.m3u8',
        'headers': {'Referer': 'https://cdn.example'},
        'behaviorHints': {
          'proxyHeaders': {
            'request': {'Origin': 'https://cdn.example'},
          },
        },
      },
      task: task,
    );
    expect(local?.ok, isTrue);
    expect(local!.stream!['url'], Uri.file(file.path).toString());
    expect(
      local.stream![kOfflinePlayCatalogUrlKey],
      'https://cdn.example/master.m3u8',
    );
    expect(
      local.stream![kOfflinePlayRowKeyKey],
      catalogStreamRowProgressKey({
        'url': 'https://cdn.example/master.m3u8',
      }),
    );
    expect(local.stream!.containsKey('headers'), isFalse);
    final hints = local.stream!['behaviorHints'] as Map;
    expect(hints.containsKey('proxyHeaders'), isFalse);
    await dir.delete(recursive: true);
  });

  test('missing completed file does not fall back to the web url', () async {
    final task = DownloadTask(
      id: 'dl-2',
      title: 'Title',
      mediaId: '1',
      type: 'movie',
      sourceName: 'Example',
      rawUrl: 'https://cdn.example/master.m3u8',
      targetFilePath: '/tmp/forja-missing-offline-file.mp4',
      status: DownloadStatus.completed,
      createdAt: DateTime.utc(2026, 9, 25),
    );
    final local = await offlineLocalPlayForTask(
      stream: {'url': 'https://cdn.example/master.m3u8'},
      task: task,
    );
    expect(local?.ok, isFalse);
    expect(local?.error, kOfflineDownloadMissingMessage);
    expect(local?.stream, isNull);
  });

  test('an active download stays on the remote stream', () async {
    final task = DownloadTask(
      id: 'dl-3',
      title: 'Title',
      mediaId: '1',
      type: 'movie',
      sourceName: 'Example',
      targetFilePath: '/tmp/part.mp4',
      status: DownloadStatus.downloading,
      createdAt: DateTime.utc(2026, 9, 25),
    );
    final local = await offlineLocalPlayForTask(
      stream: {'url': 'https://cdn.example/a.mp4'},
      task: task,
    );
    expect(local, isNull);
  });

  test('offline rows show before provider search and drop once covered', () {
    final saved = DownloadTask(
      id: 'dl-saved',
      title: 'Title',
      mediaId: 'tt1',
      type: 'movie',
      sourceName: 'Example',
      rawUrl: 'https://cdn.example/a.mp4',
      targetFilePath: '/tmp/title.mp4',
      totalBytes: 1200 * 1024 * 1024,
      status: DownloadStatus.completed,
      createdAt: DateTime.utc(2026, 9, 25),
    );
    final other = DownloadTask(
      id: 'dl-other',
      title: 'Other',
      mediaId: 'tt9',
      type: 'movie',
      sourceName: 'Other',
      rawUrl: 'https://cdn.example/b.mp4',
      targetFilePath: '/tmp/other.mp4',
      status: DownloadStatus.completed,
      createdAt: DateTime.utc(2026, 9, 25),
    );

    final ahead = offlineStreamsAheadOfProviderSearch(
      tasks: [saved, other],
      mediaId: 'tt1',
      season: null,
      episode: null,
      visibleProviderStreams: const [],
    );
    expect(ahead, hasLength(1));
    expect(ahead.single['url'], 'https://cdn.example/a.mp4');
    expect(ahead.single['_addonName'], 'Example');
    expect(ahead.single[kOfflinePinnedStreamKey], isTrue);

    final covered = offlineStreamsAheadOfProviderSearch(
      tasks: [saved],
      mediaId: 'tt1',
      season: null,
      episode: null,
      visibleProviderStreams: [
        {'url': 'https://cdn.example/a.mp4', 'name': 'Example 1080p'},
      ],
    );
    expect(covered, isEmpty);

    final wrongEpisode = offlineStreamsAheadOfProviderSearch(
      tasks: [saved],
      mediaId: 'tt1',
      season: 1,
      episode: 2,
      visibleProviderStreams: const [],
    );
    expect(wrongEpisode, isEmpty);
  });

  test('player chip binds the provider row even when the URL changed', () {
    final saved = DownloadTask(
      id: 'dl-castle',
      title: 'Title',
      mediaId: 'tt1',
      type: 'movie',
      sourceName: 'engine:castle',
      rawUrl: 'https://cdn.example/old-token.mkv',
      targetFilePath: '/tmp/title.mkv',
      status: DownloadStatus.completed,
      createdAt: DateTime.utc(2026, 9, 25),
    );
    final live = {
      'url': 'https://cdn.example/fresh-token.mkv',
      'name': 'Castle · Shared',
      '_addonName': 'Castle · Shared',
      '_enginePluginId': 'castle',
      '_addonBaseUrl': 'engine:castle',
    };
    expect(providerStreamCoversDownloadTask(live, saved), isTrue);
    expect(
      offlineStreamsAheadOfProviderSearch(
        tasks: [saved],
        mediaId: 'tt1',
        season: null,
        episode: null,
        visibleProviderStreams: [live],
      ),
      isEmpty,
    );
  });

  test('a named download does not claim sibling rows', () {
    final saved = DownloadTask(
      id: 'dl-shared',
      title: 'Title',
      mediaId: 'tt1',
      type: 'movie',
      sourceName: 'Castle · Shared',
      addonName: 'engine:castle',
      rawUrl: 'https://cdn.example/old.mkv',
      targetFilePath: '/tmp/title.mkv',
      status: DownloadStatus.completed,
      createdAt: DateTime.utc(2026, 9, 25),
    );
    expect(
      providerStreamCoversDownloadTask({
        'url': 'https://cdn.example/en.mkv',
        'name': 'Castle · English',
        '_addonName': 'Castle · English',
        '_enginePluginId': 'castle',
      }, saved),
      isFalse,
    );
    expect(
      providerStreamCoversDownloadTask({
        'url': 'https://cdn.example/fresh.mkv',
        'name': 'Castle · Shared',
        '_addonName': 'Castle · Shared',
        '_enginePluginId': 'castle',
      }, saved),
      isTrue,
    );
  });

  test('player source chrome matches a completed file URL', () {
    final task = DownloadTask(
      id: 'dl-file',
      title: 'Title',
      mediaId: '1',
      type: 'movie',
      sourceName: 'Castle',
      rawUrl: 'https://cdn.example/video.mp4',
      targetFilePath: '/tmp/forja/title.mp4',
      status: DownloadStatus.completed,
      createdAt: DateTime.utc(2026, 9, 25),
    );
    final fileUrl = Uri.file('/tmp/forja/title.mp4').toString();
    expect(
      isOfflineDownloadPlayUrl(fileUrl, tasks: [task]),
      isTrue,
    );
    expect(
      isOfflineDownloadPlayUrl(
        'https://cdn.example/video.mp4',
        tasks: [task],
      ),
      isFalse,
    );
    final active = DownloadTask(
      id: 'dl-active',
      title: 'Title',
      mediaId: '1',
      type: 'movie',
      sourceName: 'Castle',
      rawUrl: 'https://cdn.example/video.mp4',
      targetFilePath: '/tmp/forja/other.mp4',
      status: DownloadStatus.downloading,
      createdAt: DateTime.utc(2026, 9, 25),
    );
    expect(
      isOfflineDownloadPlayUrl(
        Uri.file('/tmp/forja/other.mp4').toString(),
        tasks: [active],
      ),
      isFalse,
    );
  });

  test('a saved file selects the stream that was downloaded', () {
    final task = DownloadTask(
      id: 'dl-file',
      title: 'Title',
      mediaId: '1',
      type: 'movie',
      sourceName: 'Castle',
      rawUrl: 'https://cdn.example/video.mp4',
      targetFilePath: '/tmp/forja/title.mp4',
      status: DownloadStatus.completed,
      createdAt: DateTime.utc(2026, 9, 25),
    );
    final fileUrl = Uri.file('/tmp/forja/title.mp4').toString();
    expect(
      streamMatchesPlayingOfflineDownload(
        {'url': 'https://cdn.example/video.mp4', 'name': 'Castle'},
        playUrl: fileUrl,
        tasks: [task],
      ),
      isTrue,
    );
    expect(
      streamMatchesPlayingOfflineDownload(
        {
          'url': fileUrl,
          'name': 'Castle',
          '_downloadTaskId': 'dl-file',
        },
        playUrl: fileUrl,
        tasks: [task],
      ),
      isTrue,
    );
    expect(
      streamMatchesPlayingOfflineDownload(
        {'url': 'https://cdn.example/other.mp4', 'name': 'Other'},
        playUrl: fileUrl,
        tasks: [task],
      ),
      isFalse,
    );
  });
}
