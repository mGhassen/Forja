import 'package:forja_core/utils/hls_master_parser.dart';

/// Dart reference HLS master parser — Rust-off fallback and parity tests.
abstract final class HlsDartParse {
  static List<HlsQuality>? parseMaster(String masterUrl, String body) {
    if (!body.contains('#EXT-X-STREAM-INF')) return null;

    final base = Uri.tryParse(masterUrl);
    if (base == null) return null;

    final normalized = body
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('#EXT-X-STREAM-INF', '\n#EXT-X-STREAM-INF');

    final lines = normalized.split('\n');
    final variants = <HlsQuality>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;

      String? uriLine;
      for (var j = i + 1; j < lines.length; j++) {
        final candidate = lines[j].trim();
        if (candidate.isEmpty) continue;
        if (candidate.startsWith('#')) continue;
        uriLine = candidate;
        break;
      }
      if (uriLine == null) continue;

      final attrs = _parseAttrs(line.substring(line.indexOf(':') + 1));
      final bw = int.tryParse(attrs['BANDWIDTH'] ?? attrs['AVERAGE-BANDWIDTH'] ?? '');
      int? height;
      final res = attrs['RESOLUTION'];
      if (res != null) {
        final m = RegExp(r'(\d+)x(\d+)').firstMatch(res);
        if (m != null) height = int.tryParse(m.group(2)!);
      }

      final resolved = base.resolve(uriLine).toString();
      variants.add(HlsQuality(
        label: _formatLabel(height: height, bandwidth: bw),
        url: resolved,
        bandwidth: bw,
        height: height,
      ));
    }

    if (variants.length < 2) return null;

    variants.sort((a, b) {
      final ah = a.height ?? 0;
      final bh = b.height ?? 0;
      if (ah != bh) return bh.compareTo(ah);
      return (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0);
    });

    return [
      HlsQuality(label: 'Auto', url: masterUrl, isAuto: true),
      ...variants,
    ];
  }

  static Map<String, String> _parseAttrs(String s) {
    final out = <String, String>{};
    final buf = StringBuffer();
    String? key;
    var inQuotes = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (c == '=' && key == null && !inQuotes) {
        key = buf.toString().trim();
        buf.clear();
        continue;
      }
      if (c == ',' && !inQuotes) {
        if (key != null) out[key] = buf.toString().trim();
        key = null;
        buf.clear();
        continue;
      }
      buf.write(c);
    }
    if (key != null) out[key] = buf.toString().trim();
    return out;
  }

  static String _formatLabel({int? height, int? bandwidth}) {
    if (height != null) return '${height}p';
    if (bandwidth != null) {
      final kbps = (bandwidth / 1000).round();
      return '$kbps kbps';
    }
    return 'Variant';
  }
}
