/// VOD offline download task model (Phase 1 — HTTP / HLS only).
library;

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  canceled,
}

/// Phase 1 supports direct HTTP(S) only. Debrid / P2P land in later phases.
enum DownloadSourceType {
  http,
}

class DownloadTask {
  final String id;
  final String title;
  final String mediaId;
  final String type; // 'movie', 'series', 'anime'
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final String? posterUrl;
  final String? backdropUrl;
  final String? year;

  final DownloadSourceType sourceType;
  final String sourceName;
  final String? addonName;
  final String? rawUrl;
  final Map<String, String>? headers;

  final String targetFilePath;

  final DownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final double speedBytesPerSec;
  final int? etaSeconds;
  final String? error;

  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.id,
    required this.title,
    required this.mediaId,
    required this.type,
    this.season,
    this.episode,
    this.episodeTitle,
    this.posterUrl,
    this.backdropUrl,
    this.year,
    this.sourceType = DownloadSourceType.http,
    required this.sourceName,
    this.addonName,
    this.rawUrl,
    this.headers,
    required this.targetFilePath,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0.0,
    this.etaSeconds,
    this.error,
    required this.createdAt,
    this.completedAt,
  });

  double get progressPercent {
    if (totalBytes <= 0) return 0.0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isActive =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.paused;

  String get speedLabel {
    if (speedBytesPerSec <= 0) return '…';
    final mbps = speedBytesPerSec / 1024 / 1024;
    return mbps >= 1.0
        ? '${mbps.toStringAsFixed(2)} MB/s'
        : '${(speedBytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }

  String get etaLabel {
    if (etaSeconds == null || etaSeconds! <= 0) return '--';
    if (etaSeconds! < 60) return '${etaSeconds}s';
    final mins = (etaSeconds! / 60).floor();
    final secs = etaSeconds! % 60;
    if (mins < 60) return '${mins}m ${secs}s';
    final hours = (mins / 60).floor();
    final remMins = mins % 60;
    return '${hours}h ${remMins}m';
  }

  String get sizeLabel {
    return '${formatBytes(receivedBytes)} / ${formatBytes(totalBytes)}';
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(i == 0 ? 0 : 2)} ${suffixes[i]}';
  }

  DownloadTask copyWith({
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    double? speedBytesPerSec,
    int? etaSeconds,
    String? error,
    DateTime? completedAt,
    String? targetFilePath,
    String? rawUrl,
    Map<String, String>? headers,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      mediaId: mediaId,
      type: type,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      year: year,
      sourceType: sourceType,
      sourceName: sourceName,
      addonName: addonName,
      rawUrl: rawUrl ?? this.rawUrl,
      headers: headers ?? this.headers,
      targetFilePath: targetFilePath ?? this.targetFilePath,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      error: error ?? this.error,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'mediaId': mediaId,
      'type': type,
      'season': season,
      'episode': episode,
      'episodeTitle': episodeTitle,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'year': year,
      'sourceType': sourceType.name,
      'sourceName': sourceName,
      'addonName': addonName,
      'rawUrl': rawUrl,
      'headers': headers,
      'targetFilePath': targetFilePath,
      'status': status.name,
      'receivedBytes': receivedBytes,
      'totalBytes': totalBytes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'error': error,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      mediaId: json['mediaId'] as String? ?? '',
      type: json['type'] as String? ?? 'movie',
      season: json['season'] as int?,
      episode: json['episode'] as int?,
      episodeTitle: json['episodeTitle'] as String?,
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      year: json['year'] as String?,
      sourceType: DownloadSourceType.values.firstWhere(
        (e) => e.name == json['sourceType'],
        orElse: () => DownloadSourceType.http,
      ),
      sourceName: json['sourceName'] as String? ?? 'Stream',
      addonName: json['addonName'] as String?,
      rawUrl: json['rawUrl'] as String?,
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      targetFilePath: json['targetFilePath'] as String? ?? '',
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.queued,
      ),
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'] as int)
          : null,
      error: json['error'] as String?,
    );
  }
}
