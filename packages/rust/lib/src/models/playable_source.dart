import 'dart:convert';

import 'package:rust/src/engine.dart';
import 'package:rust/src/models/stream_source.dart';

export 'package:rust/src/models/stream_source.dart' show StreamSource;

/// Canonical playable stream — provider metadata stripped before player open.
class PlayableSource {
  final String url;
  final String title;
  final String container;
  final VideoTrack? video;
  final PlayableAudioTrack? audio;
  final Map<String, String> headers;
  final List<PlayableSubtitleTrack> subtitles;
  final String providerId;
  final int providerRank;
  final int? latencyMs;
  final bool requiresProxy;
  final String? embedKind;
  final String? audioUrl;
  final double? score;
  final int? baselineRank;
  final int? effectiveRank;
  final double? qualityScore;
  final double? providerBonus;

  const PlayableSource({
    required this.url,
    required this.title,
    this.container = 'unknown',
    this.video,
    this.audio,
    this.headers = const {},
    this.subtitles = const [],
    this.providerId = '',
    this.providerRank = 0,
    this.latencyMs,
    this.requiresProxy = false,
    this.embedKind,
    this.audioUrl,
    this.score,
    this.baselineRank,
    this.effectiveRank,
    this.qualityScore,
    this.providerBonus,
  });

  bool get isArabicEmbed => embedKind == 'arabic_embed';

  factory PlayableSource.fromJson(Map<String, dynamic> json) {
    VideoTrack? video;
    final rawVideo = json['video'];
    if (rawVideo is Map) {
      video = VideoTrack.fromJson(Map<String, dynamic>.from(rawVideo));
    }
    PlayableAudioTrack? audio;
    final rawAudio = json['audio'];
    if (rawAudio is Map) {
      audio = PlayableAudioTrack.fromJson(Map<String, dynamic>.from(rawAudio));
    }
    final rawSubs = json['subtitles'];
    final subtitles = <PlayableSubtitleTrack>[];
    if (rawSubs is List) {
      for (final item in rawSubs) {
        if (item is Map) {
          subtitles.add(
            PlayableSubtitleTrack.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    Map<String, String> headers = {};
    final rawHeaders = json['headers'];
    if (rawHeaders is Map) {
      headers = rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return PlayableSource(
      url: json['url']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown',
      container: json['container']?.toString() ?? 'unknown',
      video: video,
      audio: audio,
      headers: headers,
      subtitles: subtitles,
      providerId:
          json['provider_id']?.toString() ??
          json['providerId']?.toString() ??
          '',
      providerRank:
          (json['provider_rank'] as num?)?.toInt() ??
          (json['providerRank'] as num?)?.toInt() ??
          0,
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
      requiresProxy: json['requires_proxy'] == true,
      embedKind: json['embed_kind']?.toString(),
      audioUrl: json['audio_url']?.toString(),
      score: (json['score'] as num?)?.toDouble(),
      baselineRank: (json['baseline_rank'] as num?)?.toInt(),
      effectiveRank: (json['effective_rank'] as num?)?.toInt(),
      qualityScore: (json['quality_score'] as num?)?.toDouble(),
      providerBonus: (json['provider_bonus'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'container': container,
    if (video != null) 'video': video!.toJson(),
    if (audio != null) 'audio': audio!.toJson(),
    if (headers.isNotEmpty) 'headers': headers,
    if (subtitles.isNotEmpty)
      'subtitles': subtitles.map((s) => s.toJson()).toList(),
    if (providerId.isNotEmpty) 'provider_id': providerId,
    'provider_rank': providerRank,
    if (latencyMs != null) 'latency_ms': latencyMs,
    if (requiresProxy) 'requires_proxy': requiresProxy,
    if (embedKind != null) 'embed_kind': embedKind,
    if (audioUrl != null) 'audio_url': audioUrl,
    if (score != null) 'score': score,
    if (baselineRank != null) 'baseline_rank': baselineRank,
    if (effectiveRank != null) 'effective_rank': effectiveRank,
    if (qualityScore != null) 'quality_score': qualityScore,
    if (providerBonus != null) 'provider_bonus': providerBonus,
  };

  StreamSource toStreamSource() => StreamSource(
    url: url,
    title: title,
    type: _containerToLegacyType(container),
    headers: headers.isEmpty ? null : headers,
    providerId: providerId.isEmpty ? null : providerId,
  );

  static String _containerToLegacyType(String container) {
    return switch (container) {
      'hls' => 'hls',
      'dash' => 'dash',
      'mkv' => 'mkv',
      'mp4' => 'mp4',
      _ => 'video',
    };
  }
}

class VideoTrack {
  final String codec;
  final int width;
  final int height;
  final int? bitrateKbps;
  final String hdr;

  const VideoTrack({
    this.codec = 'unknown',
    this.width = 0,
    this.height = 0,
    this.bitrateKbps,
    this.hdr = 'none',
  });

  factory VideoTrack.fromJson(Map<String, dynamic> json) => VideoTrack(
    codec: json['codec']?.toString() ?? 'unknown',
    width: (json['width'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toInt() ?? 0,
    bitrateKbps: (json['bitrate_kbps'] as num?)?.toInt(),
    hdr: json['hdr']?.toString() ?? 'none',
  );

  Map<String, dynamic> toJson() => {
    'codec': codec,
    'width': width,
    'height': height,
    if (bitrateKbps != null) 'bitrate_kbps': bitrateKbps,
    'hdr': hdr,
  };
}

class PlayableAudioTrack {
  final String codec;
  final int channels;
  final String? language;

  const PlayableAudioTrack({
    this.codec = 'unknown',
    this.channels = 2,
    this.language,
  });

  factory PlayableAudioTrack.fromJson(Map<String, dynamic> json) =>
      PlayableAudioTrack(
        codec: json['codec']?.toString() ?? 'unknown',
        channels: (json['channels'] as num?)?.toInt() ?? 2,
        language: json['language']?.toString(),
      );

  Map<String, dynamic> toJson() => {
    'codec': codec,
    'channels': channels,
    if (language != null) 'language': language,
  };
}

class PlayableSubtitleTrack {
  final String url;
  final String language;
  final String format;

  const PlayableSubtitleTrack({
    required this.url,
    required this.language,
    this.format = '',
  });

  factory PlayableSubtitleTrack.fromJson(Map<String, dynamic> json) =>
      PlayableSubtitleTrack(
        url: json['url']?.toString() ?? '',
        language: json['language']?.toString() ?? 'Unknown',
        format: json['format']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'url': url,
    'language': language,
    if (format.isNotEmpty) 'format': format,
  };
}

/// Device codec/resolution profile passed to Rust scorer.
class DevicePlaybackCapabilities {
  final int maxHeight;
  final bool hevc;
  final bool av1;
  final bool vp9;
  final bool hdr10;
  final bool dolbyVision;
  final bool isLowPower;
  final bool softwareDecodeAllowed;
  final int userMaxHeight;

  const DevicePlaybackCapabilities({
    this.maxHeight = 2160,
    this.hevc = true,
    this.av1 = true,
    this.vp9 = true,
    this.hdr10 = true,
    this.dolbyVision = true,
    this.isLowPower = false,
    this.softwareDecodeAllowed = true,
    this.userMaxHeight = 0,
  });

  static const desktop = DevicePlaybackCapabilities();

  static const constrained = DevicePlaybackCapabilities(
    maxHeight: 1080,
    hevc: false,
    av1: false,
    vp9: true,
    hdr10: false,
    dolbyVision: false,
    isLowPower: true,
    softwareDecodeAllowed: false,
  );

  Map<String, dynamic> toJson() => {
    'max_height': maxHeight,
    'hevc': hevc,
    'av1': av1,
    'vp9': vp9,
    'hdr10': hdr10,
    'dolby_vision': dolbyVision,
    'is_low_power': isLowPower,
    'software_decode_allowed': softwareDecodeAllowed,
    'user_max_height': userMaxHeight,
  };

  factory DevicePlaybackCapabilities.fromJson(Map<String, dynamic> json) =>
      DevicePlaybackCapabilities(
        maxHeight: (json['max_height'] as num?)?.toInt() ?? 2160,
        hevc: json['hevc'] == true,
        av1: json['av1'] == true,
        vp9: json['vp9'] != false,
        hdr10: json['hdr10'] == true,
        dolbyVision: json['dolby_vision'] == true,
        isLowPower: json['is_low_power'] == true,
        softwareDecodeAllowed: json['software_decode_allowed'] != false,
        userMaxHeight: (json['user_max_height'] as num?)?.toInt() ?? 0,
      );
}

List<PlayableSource> parsePlayableSourcesJson(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map>()
      .map((m) => PlayableSource.fromJson(Map<String, dynamic>.from(m)))
      .toList();
}

List<PlayableSource> rankPlayableSources({
  required List<PlayableSource> sources,
  required DevicePlaybackCapabilities device,
  List<String> blocklist = const [],
}) {
  if (sources.isEmpty) return [];
  final payload = jsonEncode({
    'sources': sources.map((s) => s.toJson()).toList(),
    'device': device.toJson(),
    'blocklist': blocklist,
  });
  final raw = RustLib.instance.playbackRankSourcesJson(payload);
  final decoded = jsonDecode(raw);
  if (decoded is Map && decoded['error'] != null) return sources;
  if (decoded is! Map) return sources;
  final list = decoded['sources'];
  if (list is! List) return sources;
  return list
      .whereType<Map>()
      .map((m) => PlayableSource.fromJson(Map<String, dynamic>.from(m)))
      .toList();
}

List<PlayableSource> normalizeLegacyStreamSources({
  required List<StreamSource> sources,
  required String providerId,
  int providerRank = 0,
}) {
  if (sources.isEmpty) return [];
  final payload = jsonEncode({
    'sources': sources
        .map(
          (s) => {
            'url': s.url,
            'title': s.title,
            'type': s.type,
            if (s.headers != null) 'headers': s.headers,
            'provider_id': (s.providerId != null && s.providerId!.isNotEmpty)
                ? s.providerId
                : providerId,
            'provider_rank': providerRank,
          },
        )
        .toList(),
  });
  final raw = RustLib.instance.playbackNormalizeLegacyJson(payload);
  final decoded = jsonDecode(raw);
  if (decoded is Map && decoded['error'] != null) {
    return sources
        .map(
          (s) => PlayableSource(
            url: s.url,
            title: s.title,
            container: s.type,
            headers: s.headers ?? {},
            providerId: providerId,
            providerRank: providerRank,
          ),
        )
        .toList();
  }
  return parsePlayableSourcesJson(raw);
}

List<StreamSource> playableSourcesToStreamSources(
  List<PlayableSource> sources,
) => sources.map((s) => s.toStreamSource()).toList();

List<PlayableSource> rankStreamSources({
  required List<StreamSource> sources,
  required String providerId,
  int providerRank = 0,
  DevicePlaybackCapabilities? device,
  List<String> blocklist = const [],
}) {
  final normalized = normalizeLegacyStreamSources(
    sources: sources,
    providerId: providerId,
    providerRank: providerRank,
  );
  return rankPlayableSources(
    sources: normalized,
    device: device ?? DevicePlaybackCapabilities.desktop,
    blocklist: blocklist,
  );
}
