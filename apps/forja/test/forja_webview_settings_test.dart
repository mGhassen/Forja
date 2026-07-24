import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/webview/atv_webview_guard.dart';
import 'package:forja/shared/webview/forja_webview_settings.dart';
import 'package:rust/rust.dart';

void main() {
  group('patchTvWebViewSettings', () {
    test('non-TV returns same instance', () {
      final settings = InAppWebViewSettings(javaScriptEnabled: true);
      final patched = patchTvWebViewSettings(settings, isAndroidTv: false);
      expect(identical(patched, settings), isTrue);
      expect(patched.hardwareAcceleration, isTrue);
    });

    test('TV disables hardware acceleration', () {
      final settings = InAppWebViewSettings(
        javaScriptEnabled: true,
        hardwareAcceleration: true,
      );
      final patched = patchTvWebViewSettings(settings, isAndroidTv: true);
      expect(patched.hardwareAcceleration, isFalse);
      expect(patched.javaScriptEnabled, isTrue);
      expect(identical(patched, settings), isTrue);
    });

    test('TV patch keeps contentBlockers (no copy/fromMap bang)', () {
      final blockers = [
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: r'.*doubleclick\.net.*',
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.BLOCK,
          ),
        ),
      ];
      final settings = InAppWebViewSettings(
        javaScriptEnabled: true,
        contentBlockers: blockers,
        hardwareAcceleration: true,
      );
      final patched = patchTvWebViewSettings(settings, isAndroidTv: true);
      expect(patched.hardwareAcceleration, isFalse);
      expect(patched.contentBlockers, same(blockers));
      // Must not throw — forjaWebViewSettings used to call settings.copy(),
      // which deserializes blockers and bangs on Android.
      expect(() => forjaWebViewSettings(patched), returnsNormally);
    });
  });

  group('isAndroidTvHeadlessWebViewBlocked', () {
    tearDown(() {
      SettingsService.configurePlatformProfile(PlatformProfile.phone);
      SettingsService.allowAndroidTvHeadlessWebViewExtractors = true;
    });

    test('false on phone profile', () {
      SettingsService.configurePlatformProfile(PlatformProfile.phone);
      expect(isAndroidTvHeadlessWebViewBlocked, isFalse);
    });

    test('true on androidTv profile when extractors disallowed', () {
      SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
      SettingsService.allowAndroidTvHeadlessWebViewExtractors = false;
      expect(isAndroidTvHeadlessWebViewBlocked, isTrue);
    });

    test('false on androidTv when allowAndroidTvHeadlessWebViewExtractors', () {
      SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
      SettingsService.allowAndroidTvHeadlessWebViewExtractors = true;
      expect(isAndroidTvHeadlessWebViewBlocked, isFalse);
    });
  });

  group('WebView call-site guard', () {
    test('no direct InAppWebView/HeadlessInAppWebView outside shared/webview/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final violations = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.contains('${Platform.pathSeparator}shared${Platform.pathSeparator}webview${Platform.pathSeparator}')) {
          continue;
        }
        final content = entity.readAsStringSync();
        for (final line in content.split('\n')) {
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('//')) continue;
          if (line.contains('InAppWebViewSettings') ||
              line.contains('InAppWebViewController') ||
              line.contains('InAppWebViewKeepAlive') ||
              line.contains('InAppWebViewInitialData') ||
              line.contains('ForjaInAppWebView')) {
            continue;
          }
          if (RegExp(r'\bInAppWebView\s*\(').hasMatch(line)) {
            violations.add('${entity.path}: $trimmed');
          }
          if (line.contains('ForjaHeadlessInAppWebView')) continue;
          if (RegExp(r'\bHeadlessInAppWebView\s*\(').hasMatch(line)) {
            violations.add('${entity.path}: $trimmed');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Use ForjaInAppWebView / ForjaHeadlessInAppWebView:\n${violations.join('\n')}',
      );
    });
  });
}
