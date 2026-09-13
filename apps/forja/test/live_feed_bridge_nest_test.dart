import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/hub_host_bridge_nest.dart';

void main() {
  test('withHubHostBridge nests and clears', () async {
    expect(isUnderHubHostBridge, isFalse);
    await withHubHostBridge(() async {
      expect(isUnderHubHostBridge, isTrue);
      await withHubHostBridge(() async {
        expect(isUnderHubHostBridge, isTrue);
      });
      expect(isUnderHubHostBridge, isTrue);
    });
    expect(isUnderHubHostBridge, isFalse);
  });

  test('withHubHostBridge clears after throw', () async {
    expect(isUnderHubHostBridge, isFalse);
    await expectLater(
      withHubHostBridge(() async {
        expect(isUnderHubHostBridge, isTrue);
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(isUnderHubHostBridge, isFalse);
  });
}
