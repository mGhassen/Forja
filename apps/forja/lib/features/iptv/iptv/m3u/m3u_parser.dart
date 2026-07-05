// Standard M3U / M3U8 extended playlist parser.
//
// Handles the common IPTV format:
//   #EXTM3U
//   #EXTINF:-1 tvg-id="..." tvg-name="..." tvg-logo="..." group-title="...",Display Name
//   http://stream.example/path

import 'm3u_models.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:forja_rust/src/reference/m3u_dart_parser.dart';

class M3uParser {
  /// Parse raw playlist text into a list of channels. Throws [FormatException]
  /// if the content does not look like an M3U playlist at all.
  static List<M3uChannel> parse(String content) {
    if (ForjaEngine.isReady) {
      final rows = ForjaEngine.parseM3uChannels(content);
      return rows
          .map(
            (j) => M3uChannel(
              name: j['name'] as String? ?? '',
              url: j['url'] as String? ?? '',
              logo: j['logo'] as String? ?? '',
              group: j['group'] as String? ?? '',
              tvgId: j['tvg_id'] as String? ?? '',
              tvgName: j['tvg_name'] as String? ?? '',
            ),
          )
          .toList();
    }
    return M3uDartParser.parse(content)
        .map(
          (j) => M3uChannel(
            name: j['name'] ?? '',
            url: j['url'] ?? '',
            logo: j['logo'] ?? '',
            group: j['group'] ?? '',
            tvgId: j['tvg_id'] ?? '',
            tvgName: j['tvg_name'] ?? '',
          ),
        )
        .toList();
  }
}
