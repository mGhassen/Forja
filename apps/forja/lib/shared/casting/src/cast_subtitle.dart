import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/downloads/hls_subtitle_sidecar.dart';
import 'package:forja/shared/player/resolvers/track_auto_select.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';

enum CastSubtitleKind {
  /// Subtitles are off in Forja.
  off,

  /// A subtitle track inside the stream.
  embedded,

  /// A subtitle file Forja loaded next to the stream, as WebVTT.
  external,

  /// A subtitle file in a format the receiver cannot show.
  unsupported,
}

/// The subtitle Forja is showing, in a form a cast receiver can use.
class CastSubtitle {
  const CastSubtitle._(
    this.kind, {
    this.name,
    this.language,
    this.vtt,
    this.index,
  });

  const CastSubtitle.off() : this._(CastSubtitleKind.off);

  const CastSubtitle.embedded({String? name, String? language, int? index})
      : this._(
          CastSubtitleKind.embedded,
          name: name,
          language: language,
          index: index,
        );

  const CastSubtitle.external({
    required String vtt,
    String? name,
    String? language,
  }) : this._(
          CastSubtitleKind.external,
          name: name,
          language: language,
          vtt: vtt,
        );

  const CastSubtitle.unsupported() : this._(CastSubtitleKind.unsupported);

  final CastSubtitleKind kind;
  final String? name;
  final String? language;
  final String? vtt;

  /// Position among the stream's own subtitle tracks, for receivers whose
  /// track names and languages differ from mpv's.
  final int? index;

  Map<String, Object?> toChannel() => {
        'kind': kind.name,
        'name': name,
        'language': language,
        'vtt': vtt,
        'index': index,
      };
}

/// The subtitle [player] shows now, for a cast. Resolves mpv's own pick when
/// Forja left the choice on auto.
Future<CastSubtitle> castSubtitleForPlayer(
  Player player, {
  double delaySeconds = 0,
}) async {
  final active =
      await resolveActiveSubtitleTrack(player) ?? SubtitleTrack.no();
  final embedded = embeddedSubtitleTracks(player.state.tracks.subtitle)
      .where((t) => t.id != 'no' && t.id != 'auto')
      .toList();
  final index = embedded.indexWhere((t) => t.id == active.id);
  return castSubtitleFor(
    active,
    delaySeconds: delaySeconds,
    index: index < 0 ? null : index,
  );
}

/// What [track] means for a cast.
Future<CastSubtitle> castSubtitleFor(
  SubtitleTrack track, {
  double delaySeconds = 0,
  int? index,
}) async {
  if (track.id == 'no' || track.id == 'auto') return const CastSubtitle.off();
  if (track.uri || track.data || isSideloadedExternalSubtitleTrack(track)) {
    final raw = track.data ? track.id : await _readSubtitle(track.id);
    // SRT and WebVTT carry `-->` cue timings; ASS and image subtitles do not.
    if (raw == null || !raw.contains('-->')) {
      return const CastSubtitle.unsupported();
    }
    final vtt = mergeWebVttParts(
      [HlsSubtitleSegmentPart(duration: 0, body: raw)],
      delaySeconds: delaySeconds,
    );
    return CastSubtitle.external(
      vtt: vtt,
      name: _label(track),
      language: track.language,
    );
  }
  return CastSubtitle.embedded(
    name: track.title,
    language: track.language,
    index: index,
  );
}

/// mpv's `start-time`: the stream's first timestamp. Forja's subtitle cues
/// count from there, so a receiver needs it to line them up.
Future<Duration> mpvStreamStartTime(Player player) async {
  final platform = player.platform;
  if (platform is! NativePlayer || platform.disposed) return Duration.zero;
  try {
    final seconds = double.tryParse(await platform.getProperty('start-time'));
    if (seconds == null || seconds.isNaN || seconds <= 0) return Duration.zero;
    return Duration(microseconds: (seconds * 1e6).round());
  } catch (_) {
    return Duration.zero;
  }
}

String? _label(SubtitleTrack track) {
  final title = track.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final language = track.language?.trim();
  if (language != null && language.isNotEmpty) return language;
  return null;
}

Future<String?> _readSubtitle(String source) async {
  try {
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      return utf8.decode(res.bodyBytes, allowMalformed: true);
    }
    final path = uri != null && uri.scheme == 'file' ? uri.toFilePath() : source;
    final bytes = await File(path).readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  } catch (e) {
    debugPrint('[Casting] subtitle read failed: $e');
    return null;
  }
}
