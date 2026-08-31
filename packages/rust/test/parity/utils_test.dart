import '../helpers/parity_backends.dart';
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

  test('unpackEval extracts packed script', () {
    const html =
        "<script>eval(function(p,a,c,k,e,d){}('0 1',10,2,'hello|world'.split('|'),0,{}))</script>";
    final m = RegExp(r'eval\(function\(p,a,c,k,e,d\).*?\)\)', dotAll: true)
        .firstMatch(html);
    expect(m, isNotNull);
    expect(RustLib.instance.unpackJs(m!.group(0)!), 'hello world');
  });
}
