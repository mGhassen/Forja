/// Snapshot for exclusive media_kit handoff into the desktop PiP float.
class PipHandoffSnapshot {
  const PipHandoffSnapshot({
    required this.url,
    required this.position,
    required this.playing,
    required this.aspectWidth,
    required this.aspectHeight,
    this.headers = const {},
    this.providerId,
    this.isLive = false,
  });

  final String url;
  final Map<String, String> headers;
  final String? providerId;
  final Duration position;
  final bool playing;
  final int aspectWidth;
  final int aspectHeight;
  final bool isLive;

  Map<String, dynamic> toMap() => {
        'url': url,
        'headers': headers,
        'providerId': providerId,
        'positionMs': position.inMilliseconds,
        'playing': playing,
        'aspectWidth': aspectWidth,
        'aspectHeight': aspectHeight,
        'isLive': isLive,
      };

  factory PipHandoffSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final rawHeaders = map['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      rawHeaders.forEach((k, v) {
        if (k != null && v != null) {
          headers[k.toString()] = v.toString();
        }
      });
    }
    return PipHandoffSnapshot(
      url: (map['url'] ?? '').toString(),
      headers: headers,
      providerId: map['providerId']?.toString(),
      position: Duration(
        milliseconds: (map['positionMs'] as num?)?.toInt() ?? 0,
      ),
      playing: map['playing'] == true,
      aspectWidth: (map['aspectWidth'] as num?)?.toInt() ?? 16,
      aspectHeight: (map['aspectHeight'] as num?)?.toInt() ?? 9,
      isLive: map['isLive'] == true,
    );
  }
}

/// Bound by the living desktop player while mounted.
abstract class PipHandoffSession {
  /// Capture URL / headers / position before disposing the main Player.
  Future<PipHandoffSnapshot?> captureForPip();

  /// Dispose main Player (and unmount Video). Shell unlock is owned by
  /// [PipService].
  Future<void> releasePlayerForPip();

  /// Recreate main Player after float teardown.
  Future<void> restoreFromPip(PipHandoffSnapshot snapshot);

  /// Close playback entirely (float Close).
  Future<void> closeFromPip();
}
