import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:rust/rust.dart';

void main() {
  tearDown(() {
    PlatformChannel.debugOverrideProfile = null;
  });

  test('debugOverrideProfile takes precedence', () async {
    PlatformChannel.debugOverrideProfile = PlatformProfile.androidTv;
    expect(
      await PlatformChannel.detectProfile(),
      PlatformProfile.androidTv,
    );
  });
}
