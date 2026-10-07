import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/menus/hls_instream_audio.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  const master = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Hindi",DEFAULT=YES,URI="audio/hi.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Tamil",LANGUAGE="ta",URI="audio/ta.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",URI="subs/en.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Commentary",URI="https://cdn.example/comm.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="muxed",NAME="Muxed"
#EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO="aud",SUBTITLES="subs"
video.m3u8
''';
  final playlist = Uri.parse('https://cdn.example/master.m3u8');

  test('parseHlsInStreamAudio keeps audio renditions with a URI in order', () {
    final auds = parseHlsInStreamAudio(master, playlistUri: playlist);
    expect(auds.map((a) => a.name), ['Hindi', 'Tamil', 'Commentary']);
    expect(auds[0].language, '');
    expect(auds[0].isDefault, isTrue);
    expect(auds[0].uri, 'https://cdn.example/audio/hi.m3u8');
    expect(auds[1].language, 'ta');
    expect(auds[2].uri, 'https://cdn.example/comm.m3u8');
  });

  test(
    'labelAudioTracksFromHlsRenditions fills blank names by demux order',
    () {
      final tracks = [
        AudioTrack.auto(),
        AudioTrack.no(),
        const AudioTrack('3', null, null, codec: 'aac'),
        const AudioTrack('1', null, null, codec: 'aac'),
        const AudioTrack('2', null, 'ta', codec: 'aac'),
      ];
      final auds = parseHlsInStreamAudio(master, playlistUri: playlist);
      final out = labelAudioTracksFromHlsRenditions(tracks, auds);

      expect(out.map((t) => t.id), ['auto', 'no', '3', '1', '2']);
      final byId = {for (final t in out) t.id: t};
      expect(byId['1']!.title, 'Hindi');
      expect(byId['1']!.language, isNull);
      expect(byId['1']!.codec, 'aac');
      expect(byId['2']!.title, 'Tamil');
      expect(byId['2']!.language, 'ta');
      expect(byId['3']!.title, 'Commentary');
      expect(audioTracksNeedHlsLabels(out), isFalse);
    },
  );

  test(
    'labelAudioTracksFromHlsRenditions leaves tracks alone on a count mismatch',
    () {
      final tracks = [
        const AudioTrack('1', null, null),
        const AudioTrack('2', null, null),
      ];
      final auds = parseHlsInStreamAudio(master, playlistUri: playlist);
      final out = labelAudioTracksFromHlsRenditions(tracks, auds);
      expect(identical(out, tracks), isTrue);
      expect(audioTracksNeedHlsLabels(out), isTrue);
    },
  );

  test('audioTracksNeedHlsLabels is false when every track is named', () {
    expect(
      audioTracksNeedHlsLabels([
        AudioTrack.auto(),
        const AudioTrack('1', 'English', 'en'),
        const AudioTrack('2', null, 'fr'),
      ]),
      isFalse,
    );
  });
}
