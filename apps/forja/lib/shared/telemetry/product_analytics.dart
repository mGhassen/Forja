import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:rust/rust.dart';

import 'telemetry_scrub.dart';

/// PostHog product analytics + session replay (RFC-043).
///
/// Opt-in via Settings. Replay on wherever the Flutter SDK supports it
/// (incl. macOS / Android / iOS; Linux/Windows may no-op inside the SDK).
abstract final class ProductAnalytics {
  static const String apiKey = String.fromEnvironment('POSTHOG_API_KEY');

  static const String _hostDefine = String.fromEnvironment('POSTHOG_HOST');

  /// US cloud by default; set `POSTHOG_HOST=https://eu.i.posthog.com` for EU.
  static String get host => _hostDefine.isEmpty
      ? 'https://us.i.posthog.com'
      : _hostDefine;

  static bool _active = false;

  static bool get isConfigured => apiKey.isNotEmpty;

  static bool get isActive => _active;

  static Future<void> ensureInitialized() async {
    final enabled = await SettingsService().isProductAnalyticsEnabled();
    if (enabled) {
      await _start();
    } else {
      await _stop();
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    await SettingsService().setProductAnalyticsEnabled(enabled);
    if (enabled) {
      await _start();
    } else {
      await _stop();
    }
  }

  static Future<void> track(
    String name, {
    Map<String, Object?>? properties,
  }) async {
    if (!_active) return;
    if (!_allowedEvents.contains(name)) return;
    final props = <String, Object>{};
    if (properties != null) {
      for (final e in properties.entries) {
        if (e.value == null) continue;
        if (_sensitivePropertyKey(e.key)) continue;
        final v = e.value!;
        props[e.key] = v is String ? scrubText(v) : v;
      }
    }
    await Posthog().capture(eventName: name, properties: props);
  }

  static Future<void> screen(String name) async {
    if (!_active) return;
    final cleaned = scrubText(name).trim();
    if (cleaned.isEmpty || cleaned == '/') return;
    await Posthog().screen(screenName: cleaned);
  }

  /// Shell tab id → `$screen` (e.g. `home`, `anime`).
  static Future<void> screenTab(String tabId) {
    final id = tabId.trim();
    if (id.isEmpty) return Future<void>.value();
    return screen(id);
  }

  /// Map [RouteSettings.name] for [PosthogObserver]. Skips `/` and unnamed.
  static String? routeScreenName(RouteSettings settings) {
    final name = settings.name?.trim();
    if (name == null || name.isEmpty || name == '/') return null;
    if (name == 'player' || name == 'forja/player') return 'player';
    return name;
  }

  static Future<void> sendTestEvent() async {
    if (!_active) {
      throw StateError(
        'Product analytics is off - enable it in Settings first',
      );
    }
    await track('analytics_verify');
  }

  static Future<void> _start() async {
    if (!isConfigured) {
      debugPrint(
        '[ProductAnalytics] On but POSTHOG_API_KEY empty - no-op',
      );
      _active = false;
      return;
    }
    if (_active) return;

    final config = PostHogConfig(apiKey)
      ..host = host
      ..debug = kDebugMode
      ..captureApplicationLifecycleEvents = true
      ..sessionReplay = true
      ..beforeSend = [_beforeSend];

    config.sessionReplayConfig.maskAllTexts = true;
    config.sessionReplayConfig.maskAllImages = true;

    await Posthog().setup(config);
    _active = true;
    unawaited(track('app_start'));
  }

  static Future<void> _stop() async {
    if (!_active) return;
    try {
      await Posthog().disable();
      await Posthog().close();
    } catch (_) {}
    _active = false;
  }

  static PostHogEvent? _beforeSend(PostHogEvent event) {
    final props = event.properties;
    if (props == null) return event;
    for (final key in props.keys.toList()) {
      if (_sensitivePropertyKey(key)) {
        props.remove(key);
        continue;
      }
      final v = props[key];
      if (v is String) {
        props[key] = scrubText(v);
      }
    }
    return event;
  }

  static const Set<String> _allowedEvents = {
    'app_start',
    'analytics_verify',
    'resolve_failed',
    'player_open_failed',
    'provider_timeout',
    'update_check',
    'tab_selected',
    'play_started',
  };

  static bool _sensitivePropertyKey(String key) {
    final k = key.toLowerCase();
    return k.contains('token') ||
        k.contains('password') ||
        k.contains('secret') ||
        k.contains('cookie') ||
        k.contains('magnet') ||
        k.contains('url') ||
        k.contains('email') ||
        k.contains('stream');
  }
}
