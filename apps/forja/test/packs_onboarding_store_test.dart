import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/sync/bridge/packs_onboarding_store.dart';

void main() {
  group('PacksOnboardingStore.forjaOnboardedFromPayload', () {
    test('true when connectedServices.forja.onboarded is true', () {
      expect(
        PacksOnboardingStore.forjaOnboardedFromPayload({
          'connectedServices': {
            'forja': {'onboarded': true, 'packs': <Object>[]},
          },
        }),
        isTrue,
      );
    });

    test('false when forja omitted or onboarded missing/false', () {
      expect(PacksOnboardingStore.forjaOnboardedFromPayload(null), isFalse);
      expect(PacksOnboardingStore.forjaOnboardedFromPayload({}), isFalse);
      expect(
        PacksOnboardingStore.forjaOnboardedFromPayload({
          'connectedServices': {
            'forja': {'packs': <Object>[]},
          },
        }),
        isFalse,
      );
      expect(
        PacksOnboardingStore.forjaOnboardedFromPayload({
          'connectedServices': {
            'forja': {'onboarded': false},
          },
        }),
        isFalse,
      );
    });
  });
}
