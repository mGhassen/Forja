import 'package:forja/shared/player/controls/menus/hls_instream_subtitles.dart';
import 'package:media_kit/media_kit.dart';

/// One `TYPE=AUDIO` rendition on an HLS master, in playlist order.
///
/// The demuxer stores the rendition `NAME` in a tag mpv does not surface, so a
/// master whose renditions carry no `LANGUAGE` reaches the player as unnamed
/// tracks. The playlist is the only place that name still exists.
class HlsInStreamAudio {
  const HlsInStreamAudio({
    required this.language,
    required this.name,
    required this.uri,
    this.isDefault = false,
  });

  final String language;
  final String name;
  final String uri;
  final bool isDefault;
}

/// `TYPE=AUDIO` renditions with a `URI`, one per playlist line and in line
/// order. Renditions without a `URI` are muxed into a variant and own no
/// track of their own, so they are skipped.
List<HlsInStreamAudio> parseHlsInStreamAudio(
  String playlist, {
  required Uri playlistUri,
}) {
  final out = <HlsInStreamAudio>[];
  for (final raw in playlist.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (!line.toUpperCase().startsWith('#EXT-X-MEDIA:')) continue;
    final type = hlsMediaAttr(line, 'TYPE');
    if (type == null || type.toUpperCase() != 'AUDIO') continue;
    final rawUri = hlsMediaAttr(line, 'URI')?.trim() ?? '';
    if (rawUri.isEmpty) continue;
    final name = (hlsMediaAttr(line, 'NAME') ?? '').trim();
    final lang = (hlsMediaAttr(line, 'LANGUAGE') ?? '').trim();
    final def = (hlsMediaAttr(line, 'DEFAULT') ?? '').trim().toUpperCase();
    out.add(
      HlsInStreamAudio(
        language: lang,
        name: name,
        uri: playlistUri.resolve(rawUri).toString(),
        isDefault: def == 'YES',
      ),
    );
  }
  return out;
}

bool _blank(String? s) => s == null || s.trim().isEmpty;

bool _concrete(AudioTrack t) => t.id != 'no' && t.id != 'auto';

/// True when at least one demuxed track has neither language nor title.
bool audioTracksNeedHlsLabels(Iterable<AudioTrack> tracks) {
  return tracks.any(
    (t) => _concrete(t) && _blank(t.language) && _blank(t.title),
  );
}

/// Copy of [tracks] with missing title / language filled from [renditions].
///
/// Tracks pair with renditions by demux order (ascending mpv id ↔ playlist
/// line). The pairing is only trusted when the counts match; otherwise the
/// variants carry their own audio and [tracks] is returned unchanged.
List<AudioTrack> labelAudioTracksFromHlsRenditions(
  List<AudioTrack> tracks,
  List<HlsInStreamAudio> renditions,
) {
  final concrete = tracks.where(_concrete).toList(growable: false);
  if (concrete.isEmpty || renditions.isEmpty) return tracks;
  if (concrete.length != renditions.length) return tracks;

  final ordered = List<AudioTrack>.from(concrete)
    ..sort((a, b) => _orderKey(a).compareTo(_orderKey(b)));
  final byId = <String, AudioTrack>{};
  for (var i = 0; i < ordered.length; i++) {
    final t = ordered[i];
    final r = renditions[i];
    final title = _blank(t.title) && !_blank(r.name) ? r.name : t.title;
    final language = _blank(t.language) && !_blank(r.language)
        ? r.language
        : t.language;
    if (title == t.title && language == t.language) continue;
    byId[t.id] = AudioTrack(
      t.id,
      title,
      language,
      image: t.image,
      albumart: t.albumart,
      isDefault: t.isDefault,
      codec: t.codec,
      decoder: t.decoder,
      w: t.w,
      h: t.h,
      channelscount: t.channelscount,
      channels: t.channels,
      samplerate: t.samplerate,
      fps: t.fps,
      bitrate: t.bitrate,
      rotate: t.rotate,
      par: t.par,
      audiochannels: t.audiochannels,
    );
  }
  if (byId.isEmpty) return tracks;
  return [for (final t in tracks) byId[t.id] ?? t];
}

int _orderKey(AudioTrack t) => int.tryParse(t.id) ?? 1 << 30;

/// [tracks] with names recovered from the HLS master behind [playUrl].
///
/// No network call when every track already has a language or title, or when
/// [playUrl] is not a playlist we can read.
Future<List<AudioTrack>> hlsLabeledAudioTracks(
  List<AudioTrack> tracks, {
  String? playUrl,
  Map<String, String>? headers,
}) async {
  if (!audioTracksNeedHlsLabels(tracks)) return tracks;
  final raw = playUrl?.trim() ?? '';
  if (raw.isEmpty) return tracks;
  final text = await loadHlsPlaylistText(raw, headers: headers);
  if (text == null) return tracks;
  final renditions = parseHlsInStreamAudio(text.body, playlistUri: text.uri);
  return labelAudioTracksFromHlsRenditions(tracks, renditions);
}
