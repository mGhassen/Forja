/// Dart reference JS unpacker — Rust-off fallback and parity tests.
abstract final class JsUnpackerDart {
  static String unpack(String source) {
    final m = RegExp(
            r"\}\s*\(\s*'([^']+)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([^']+)'\.split\('\|'\)\s*,\s*\d+\s*,\s*(?:\{\}|null)\s*\)\s*\)")
        .firstMatch(source);
    if (m == null) {
      throw FormatException('No p,a,c,k,e,d string found');
    }
    final payload = _unescape(m.group(1)!);
    final radix = int.parse(m.group(2)!);
    final count = int.parse(m.group(3)!);
    final symtab = m.group(4)!.split('|');
    if (symtab.length != count) {
      throw FormatException('Symtab length mismatch ($count vs ${symtab.length})');
    }
    String unbase(String word) {
      if (radix <= 10) return int.parse(word, radix: radix).toString();
      var n = 0;
      for (var i = 0; i < word.length; i++) {
        final c = word.codeUnitAt(i);
        int d;
        if (c >= 48 && c <= 57) {
          d = c - 48;
        } else if (c >= 97 && c <= 122) {
          d = c - 97 + 10;
        } else if (c >= 65 && c <= 90) {
          d = c - 65 + 36;
        } else {
          d = 0;
        }
        n = n * radix + d;
      }
      return n.toString();
    }

    return payload.replaceAllMapped(RegExp(r'\b\w+\b'), (mm) {
      final word = mm.group(0)!;
      final idx = int.tryParse(unbase(word));
      if (idx == null || idx < 0 || idx >= count) return word;
      final repl = symtab[idx];
      return repl.isEmpty ? word : repl;
    });
  }

  static String unpackEval(String html) {
    final m = RegExp(r'eval\(function\(p,a,c,k,e,d\).*?\)\)', dotAll: true)
        .firstMatch(html);
    if (m == null) {
      throw FormatException('No p,a,c,k,e,d string found');
    }
    return unpack(m.group(0)!);
  }

  static String _unescape(String s) {
    return s
        .replaceAll(r"\\", '\\')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"');
  }
}
