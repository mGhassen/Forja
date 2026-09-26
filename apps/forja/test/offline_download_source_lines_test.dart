import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/downloads/download_enqueue.dart';
import 'package:forja/shared/downloads/download_task.dart';

DownloadTask _task({
  required String sourceName,
  String? addonName,
}) {
  return DownloadTask(
    id: 't1',
    title: 'Saved film',
    mediaId: '42',
    type: 'movie',
    sourceName: sourceName,
    addonName: addonName,
    targetFilePath: '/tmp/saved.mp4',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  test('stored source name splits into provider and stream', () {
    final task = _task(sourceName: 'North · Mesa', addonName: 'north');
    final lines = offlineDownloadButtonLines(task);
    expect(lines.label, 'North');
    expect(lines.server, 'Mesa');
    expect(offlineDownloadRowLabel(task), 'North · Mesa');
  });

  test('placeholder stream name uses the provider chip', () {
    final lines = offlineDownloadButtonLines(
      _task(sourceName: 'Stream', addonName: 'north-beam'),
    );
    expect(lines.label, 'North Beam');
    expect(lines.server, isNull);
  });
}
