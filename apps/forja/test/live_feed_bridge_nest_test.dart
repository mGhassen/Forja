import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/live/live_feed_bridge_nest.dart';

void main() {
  test('withHubLiveFeedBridge nests and clears', () async {
    expect(isUnderHubLiveFeedBridge, isFalse);
    await withHubLiveFeedBridge(() async {
      expect(isUnderHubLiveFeedBridge, isTrue);
      await withHubLiveFeedBridge(() async {
        expect(isUnderHubLiveFeedBridge, isTrue);
      });
      expect(isUnderHubLiveFeedBridge, isTrue);
    });
    expect(isUnderHubLiveFeedBridge, isFalse);
  });

  test('withHubLiveFeedBridge clears after throw', () async {
    expect(isUnderHubLiveFeedBridge, isFalse);
    await expectLater(
      withHubLiveFeedBridge(() async {
        expect(isUnderHubLiveFeedBridge, isTrue);
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(isUnderHubLiveFeedBridge, isFalse);
  });
}
