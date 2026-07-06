// Standard M3U / M3U8 extended playlist parser.
//
// Handles the common IPTV format:
//   #EXTM3U
//   #EXTINF:-1 tvg-id="..." tvg-name="..." tvg-logo="..." group-title="...",Display Name
//   http://stream.example/path

import 'm3u_models.dart';
import 'package:rust/rust.dart';

class M3uParser {
  /// Parse raw playlist text into a list of channels. Throws [FormatException]
  /// if the content does not look like an M3U playlist at all.
  static List<M3uChannel> parse(String content) {
    final rows = Engine.parseM3uChannels(content);
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
}
