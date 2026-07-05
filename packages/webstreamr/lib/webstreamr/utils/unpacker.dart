/// Port of `unpacker` npm package — decodes the standard
/// `eval(function(p,a,c,k,e,d){...}(...))` packed-JS used by virtually every
/// streaming file host. Used by Dropload/Fastream/FileLions/FileMoon/Fsst/
/// LuluStream/Mixdrop/Streamtape/SuperVideo/Uqload extractors and others.
library;

/// Optional Rust backend — set from app bootstrap when [ForjaEngine] loads.
abstract final class JsUnpackBackend {
  static String? Function(String source)? unpack;
}

String _unpack(String source) {
  final backend = JsUnpackBackend.unpack;
  if (backend == null) {
    throw StateError(
      'JsUnpackBackend.unpack not wired — call ForjaEngine.init()',
    );
  }
  final out = backend(source);
  if (out != null && out.isNotEmpty) return out;
  throw FormatException('JS unpack failed');
}

/// Unpacks the first p,a,c,k,e,d string found in [source]. Returns the
/// decoded JavaScript text (still JS — caller usually regex-extracts the
/// real stream URL from it).
String unpack(String source) => _unpack(source);

/// Public re-export so callers can do `unpackEval`.
String unpackEval(String html) {
  final m = RegExp(r'eval\(function\(p,a,c,k,e,d\).*?\)\)', dotAll: true)
      .firstMatch(html);
  if (m == null) {
    throw FormatException('No p,a,c,k,e,d string found');
  }
  return _unpack(m.group(0)!);
}

/// Walk [linkRegExps] over the unpacked JS and return the first match group(1)
/// as an absolute https URL. Mirrors webstreamr/src/utils/embed.ts.
Uri extractUrlFromPacked(String html, List<RegExp> linkRegExps) {
  final unpacked = unpackEval(html);
  for (final rx in linkRegExps) {
    final m = rx.firstMatch(unpacked);
    if (m != null && m.groupCount >= 1 && m.group(1) != null) {
      final raw = m.group(1)!.replaceFirst(RegExp(r'^(https:)?\/\/'), '');
      return Uri.parse('https://$raw');
    }
  }
  throw StateError('Could not find a stream link in embed');
}
