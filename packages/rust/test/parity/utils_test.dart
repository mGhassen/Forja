import '../helpers/parity_backends.dart';
import 'package:api/api/kisskh_subtitle_decryptor.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustAndWireRustBackends();
  });

  const packed =
      "eval(function(p,a,c,k,e,d){}('0 1',10,2,'hello|world'.split('|'),0,{}))";

  test('js unpack via FFI', () {
    final rust = RustLib.instance.unpackJs(packed);
    expect(rust, 'hello world');
  });

  test('kisskh decryptBody passthrough via FFI', () async {
    const body = 'WEBVTT\n\n1\n00:00:00.000 --> 00:00:01.000\nHello\n';
    final rust = RustLib.instance.decryptKisskhBody(body);
    final viaBackend = await KissKhSubtitleDecryptor.decryptBody(body);
    expect(rust, viaBackend);
    expect(rust, contains('Hello'));
  });

  test('unpackEval extracts packed script', () {
    const html =
        "<script>eval(function(p,a,c,k,e,d){}('0 1',10,2,'hello|world'.split('|'),0,{}))</script>";
    final m = RegExp(r'eval\(function\(p,a,c,k,e,d\).*?\)\)', dotAll: true)
        .firstMatch(html);
    expect(m, isNotNull);
    expect(RustLib.instance.unpackJs(m!.group(0)!), 'hello world');
  });
}
