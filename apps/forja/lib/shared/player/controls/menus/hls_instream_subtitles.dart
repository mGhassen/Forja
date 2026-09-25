import 'package:http/http.dart' as http;

/// One HLS subtitle rendition the proxy kept off the demuxed playlist.
class HlsInStreamSubtitle {
  const HlsInStreamSubtitle({
    required this.language,
    required this.name,
    required this.uri,
  });

  final String language;
  final String name;
  final String uri;
}

/// `#FORJA-SUB:` lines the local HLS proxy appends after it drops
/// `TYPE=SUBTITLES` groups (lavf would otherwise open every rendition).
List<HlsInStreamSubtitle> parseForjaHlsSubtitles(
  String playlist, {
  required Uri playlistUri,
}) {
  final out = <HlsInStreamSubtitle>[];
  for (final raw in playlist.split('\n')) {
    final line = raw.trim();
    if (!line.startsWith('#FORJA-SUB:')) continue;
    final query = line.substring('#FORJA-SUB:'.length);
    final fields = Uri.splitQueryString(query);
    final rawUri = fields['uri']?.trim() ?? '';
    if (rawUri.isEmpty) continue;
    final resolved = playlistUri.resolve(rawUri);
    final name = (fields['name'] ?? '').trim();
    final lang = (fields['lang'] ?? '').trim();
    out.add(
      HlsInStreamSubtitle(
        language: lang.isNotEmpty ? lang : (name.isNotEmpty ? name : 'und'),
        name: name.isNotEmpty ? name : lang,
        uri: resolved.toString(),
      ),
    );
  }
  return out;
}

/// Rows the Exo subtitle menu can show beside online results.
List<Map<String, dynamic>> hlsInStreamSubtitleRows(
  List<HlsInStreamSubtitle> subs,
) {
  return [
    for (final s in subs)
      {
        'url': s.uri,
        'language': s.language,
        'lang': s.language,
        'display': s.name.isNotEmpty ? s.name : s.language,
        'sourceName': 'In-stream',
      },
  ];
}

bool isLocalHlsPlayUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  return _localPlaylist(uri);
}

bool _localPlaylist(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host != '127.0.0.1' && host != 'localhost' && host != '::1') {
    return false;
  }
  final path = uri.path;
  return path.contains('/hls-proxy') || path.contains('/ext/');
}

/// Fetch the play URL when it is our local HLS proxy and read kept renditions.
Future<List<HlsInStreamSubtitle>> loadHlsInStreamSubtitles(String? playUrl) async {
  final raw = playUrl?.trim() ?? '';
  if (raw.isEmpty) return const [];
  final uri = Uri.tryParse(raw);
  if (uri == null || !_localPlaylist(uri)) return const [];
  try {
    final res = await http.get(uri).timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) return const [];
    return parseForjaHlsSubtitles(res.body, playlistUri: uri);
  } catch (_) {
    return const [];
  }
}
