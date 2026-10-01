import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/vm/engine_polyfills.dart';

void main() {
  test('polyfill atob keeps goat body length when base64 is padded', () {
    // Streamed /fetch bodies are 263 bytes → one '='. A decoder that treats
    // '=' as data returns 264 and set_stream_jw rejects the ciphertext.
    final raw = List<int>.filled(263, 0x5a);
    final b64 = base64Encode(raw);
    expect(b64.endsWith('='), isTrue);

    final rt = getJavascriptRuntime(xhr: false);
    addTearDown(rt.dispose);
    rt.evaluate('try { delete globalThis.atob; } catch (e) {}');
    final installed = rt.evaluate(kEnginePolyfillsJs);
    expect(installed.isError, isFalse, reason: installed.stringResult);

    final len = rt.evaluate('String(atob(${jsonEncode(b64)}).length)');
    expect(len.isError, isFalse, reason: len.stringResult);
    expect(len.stringResult, '263');
    final src = rt.evaluate('String(atob)');
    expect(src.stringResult, contains('InvalidCharacterError'));
  });
}
