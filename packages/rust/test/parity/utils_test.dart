import 'dart:convert';

import '../helpers/parity_backends.dart';
import 'package:api/api/kisskh_subtitle_decryptor.dart';
import 'package:rust/rust.dart';
import 'package:webstreamr/webstreamr/utils/unpacker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustAndWireDartParityBackends();
  });

  const packed =
      "eval(function(p,a,c,k,e,d){}('0 1',10,2,'hello|world'.split('|'),0,{}))";

  test('js unpack via FFI matches Dart', () {
    final rust = ForjaRust.instance.unpackJs(packed);
    expect(rust, unpack(packed));
    expect(rust, 'hello world');
  });

  test('kisskh decryptBody passthrough via FFI', () {
    const body = 'WEBVTT\n\n1\n00:00:00.000 --> 00:00:01.000\nHello\n';
    final rust = ForjaRust.instance.decryptKisskhBody(body);
    final dart = KissKhSubtitleDecryptor.decryptBody(body);
    expect(rust, dart);
    expect(rust, contains('Hello'));
  });

  test('unpackEval uses same backend path', () {
    const html =
        "<script>eval(function(p,a,c,k,e,d){}('0 1',10,2,'hello|world'.split('|'),0,{}))</script>";
    JsUnpackBackend.unpack = (source) {
      final out = ForjaRust.instance.unpackJs(source);
      return out.isEmpty ? null : out;
    };
    expect(unpackEval(html), 'hello world');
  });
}
