/// Port of `unpacker` npm package — decodes the standard
/// `eval(function(p,a,c,k,e,d){...}(...))` packed-JS used by virtually every
/// streaming file host. Used by Dropload/Fastream/FileLions/FileMoon/Fsst/
/// LuluStream/Mixdrop/Streamtape/SuperVideo/Uqload extractors and others.
library;

import 'package:rust/rust.dart';

String _unpack(String source) {
  if (!ForjaRust.isInitialized) {
    throw StateError('ForjaEngine not initialized');
  }
  final out = ForjaRust.instance.unpackJs(source);
  if (out.isNotEmpty) return out;
  throw FormatException('JS unpack failed');
}

String unpack(String source) => _unpack(source);

String unpackEval(String html) {
  final m = RegExp(r'eval\(function\(p,a,c,k,e,d\).*?\)\)', dotAll: true)
      .firstMatch(html);
  if (m == null) {
    throw FormatException('No p,a,c,k,e,d string found');
  }
  return _unpack(m.group(0)!);
}

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
