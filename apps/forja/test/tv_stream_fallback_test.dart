import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/tv_stream_fallback.dart';
import 'package:rust/rust.dart';

void main() {
  group('TvStreamFallback.isSkippedOnTv', () {
    final catalog = StreamProviders.providers;

    tearDown(() {
      SettingsService.configurePlatformProfile(PlatformProfile.phone);
      SettingsService.allowAndroidTvHeadlessWebViewExtractors = true;
    });

    test('returns false when not Android TV profile', () {
      SettingsService.configurePlatformProfile(PlatformProfile.phone);
      SettingsService.allowAndroidTvHeadlessWebViewExtractors = false;
      expect(
        TvStreamFallback.isSkippedOnTv('vidlink', catalog),
        isFalse,
      );
    });

    test('marks WebView template providers skipped on TV', () {
      SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
      SettingsService.allowAndroidTvHeadlessWebViewExtractors = false;

      expect(TvStreamFallback.isSkippedOnTv('vidlink', catalog), isTrue);
      expect(TvStreamFallback.isSkippedOnTv('vixsrc', catalog), isTrue);
      expect(TvStreamFallback.isSkippedOnTv('vidnest', catalog), isTrue);
      expect(TvStreamFallback.isSkippedOnTv('vidrock', catalog), isTrue);
      expect(TvStreamFallback.isSkippedOnTv('vidzee', catalog), isTrue);
    });

    test('does not skip Videasy or VidSrc.sbs on TV (STREAMCRYPTO HTTP)', () {
      SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
      SettingsService.allowAndroidTvHeadlessWebViewExtractors = false;

      expect(TvStreamFallback.isSkippedOnTv('videasy', catalog), isFalse);
      expect(TvStreamFallback.isSkippedOnTv('vidsrcsbs', catalog), isFalse);
    });

    test('does not skip when allowAndroidTvHeadlessWebViewExtractors is true', () {
      SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
      SettingsService.allowAndroidTvHeadlessWebViewExtractors = true;

      expect(TvStreamFallback.isSkippedOnTv('vidlink', catalog), isFalse);
      expect(TvStreamFallback.isSkippedOnTv('videasy', catalog), isFalse);
    });

    test('keeps Rust HTTP providers active on TV', () {
      SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
      SettingsService.allowAndroidTvHeadlessWebViewExtractors = false;

      for (final key in TvStreamFallback.rustProviderKeys) {
        expect(
          TvStreamFallback.isSkippedOnTv(key, catalog),
          isFalse,
          reason: key,
        );
      }
    });
  });
}
