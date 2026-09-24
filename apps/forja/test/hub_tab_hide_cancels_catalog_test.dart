import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/vm/service.dart';

void main() {
  test('cancelCatalog bumps catalogGeneration', () {
    final before = EngineService.instance.catalogGeneration;
    EngineService.instance.cancelCatalog();
    expect(EngineService.instance.catalogGeneration, greaterThan(before));
  });
}
