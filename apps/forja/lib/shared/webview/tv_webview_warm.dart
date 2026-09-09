import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';

/// One-shot Android TV Chromium warm-up — runs on first WebView use, not boot.
abstract final class TvWebViewWarm {
  static Future<void>? _inFlight;
  static bool _done = false;

  /// Idempotent. Safe to call from UI and headless unlock paths.
  static Future<void> ensure() {
    if (_done || !PlatformInfo.isAndroidTv) {
      return Future<void>.value();
    }
    return _inFlight ??= () async {
      try {
        await PlatformChannel.prepareWebViewForTv();
        debugPrint('[WebView] TV software warm-up OK (first use)');
      } catch (e) {
        debugPrint('[WebView] TV warm-up failed (non-fatal): $e');
      } finally {
        _done = true;
        _inFlight = null;
      }
    }();
  }

  @visibleForTesting
  static void debugReset() {
    _done = false;
    _inFlight = null;
  }
}
