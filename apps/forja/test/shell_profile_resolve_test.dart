import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/platform/android_form_factor.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:rust/rust.dart';

/// Phone panel 2400×1080 at dpr 2.625 → 914×411 logical.
const _phonePhysicalLandscape = Size(2400, 1080);
const _phoneDpr = 2.625;

Size _logical(Size physical, double dpr) =>
    Size(physical.width / dpr, physical.height / dpr);

void main() {
  group('resolveShellProfileFor — Android mobile flavor', () {
    ShellProfile mobile(Size logical, {Size? physical, bool tv = false}) =>
        resolveShellProfileFor(
          os: ShellHostOs.android,
          logicalSize: logical,
          physicalSize: physical,
          androidMobileFormFactor: true,
          androidTvDevice: tv,
        );

    test('phone portrait 412×915 → mobile', () {
      expect(mobile(const Size(412, 915)), ShellProfile.mobile);
    });

    test('phone landscape 915×412 → mobile', () {
      expect(mobile(const Size(915, 412)), ShellProfile.mobile);
    });

    test('tablet landscape 1280×800 → mobile, never desktop or tv', () {
      expect(mobile(const Size(1280, 800)), ShellProfile.mobile);
    });

    test('2400×1080 physical landscape phone → mobile', () {
      expect(
        mobile(
          _logical(_phonePhysicalLandscape, _phoneDpr),
          physical: _phonePhysicalLandscape,
        ),
        ShellProfile.mobile,
      );
    });

    test('TV-sized panel still resolves mobile in the mobile flavor', () {
      expect(
        mobile(
          const Size(960, 540),
          physical: const Size(1920, 1080),
          tv: true,
        ),
        ShellProfile.mobile,
      );
    });
  });

  group('resolveShellProfileFor — Android tv flavor', () {
    ShellProfile tvFlavor(Size logical, {Size? physical, bool tv = false}) =>
        resolveShellProfileFor(
          os: ShellHostOs.android,
          logicalSize: logical,
          physicalSize: physical,
          androidTvDevice: tv,
        );

    test('1920×1080 landscape panel → tv', () {
      expect(
        tvFlavor(const Size(960, 540), physical: const Size(1920, 1080)),
        ShellProfile.tv,
      );
    });

    test('native leanback → tv at any size', () {
      expect(tvFlavor(const Size(412, 915), tv: true), ShellProfile.tv);
    });

    test('phone portrait stays mobile', () {
      expect(
        tvFlavor(const Size(412, 915), physical: const Size(1080, 2400)),
        ShellProfile.mobile,
      );
    });
  });

  group('resolveShellProfileFor — other hosts', () {
    test('desktop OS → desktop', () {
      expect(
        resolveShellProfileFor(
          os: ShellHostOs.desktop,
          logicalSize: const Size(412, 915),
        ),
        ShellProfile.desktop,
      );
    });

    test('non-Android touch host keeps the width split', () {
      expect(
        resolveShellProfileFor(
          os: ShellHostOs.other,
          logicalSize: const Size(412, 915),
        ),
        ShellProfile.mobile,
      );
      expect(
        resolveShellProfileFor(
          os: ShellHostOs.other,
          logicalSize: Size(ShellTokens.musicDesktopBreakpoint + 1, 800),
        ),
        ShellProfile.desktop,
      );
    });
  });

  group('ShellTokens TV size heuristics', () {
    test('16:9 720p+ landscape panel looks like a TV', () {
      expect(ShellTokens.looksLikeAndroidTvPanel(const Size(1920, 1080)), isTrue);
      expect(ShellTokens.looksLikeAndroidTvPanel(const Size(1280, 720)), isTrue);
    });

    test('16:10 tablet panel and portrait panels do not', () {
      expect(ShellTokens.looksLikeAndroidTvPanel(const Size(1280, 800)), isFalse);
      expect(ShellTokens.looksLikeAndroidTvPanel(const Size(1080, 2400)), isFalse);
    });
  });

  group('PlatformChannel.androidProfileFor', () {
    test('mobile flavor → phone even with TV signals', () {
      expect(
        PlatformChannel.androidProfileFor(
          formFactor: AndroidFormFactor.mobile,
          forceTv: true,
          nativeTv: true,
          physicalTvPanel: true,
        ),
        PlatformProfile.phone,
      );
    });

    test('tv flavor keeps native detection and the panel fallback', () {
      expect(
        PlatformChannel.androidProfileFor(
          formFactor: AndroidFormFactor.tv,
          forceTv: false,
          nativeTv: true,
          physicalTvPanel: false,
        ),
        PlatformProfile.androidTv,
      );
      expect(
        PlatformChannel.androidProfileFor(
          formFactor: AndroidFormFactor.tv,
          forceTv: false,
          nativeTv: false,
          physicalTvPanel: true,
        ),
        PlatformProfile.androidTv,
      );
      expect(
        PlatformChannel.androidProfileFor(
          formFactor: AndroidFormFactor.tv,
          forceTv: false,
          nativeTv: false,
          physicalTvPanel: false,
        ),
        PlatformProfile.phone,
      );
    });

    test('AndroidFormFactor.parse defaults to tv', () {
      expect(AndroidFormFactor.parse('mobile'), AndroidFormFactor.mobile);
      expect(AndroidFormFactor.parse('tv'), AndroidFormFactor.tv);
      expect(AndroidFormFactor.parse(null), AndroidFormFactor.tv);
    });
  });
}
