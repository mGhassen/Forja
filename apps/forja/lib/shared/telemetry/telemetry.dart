import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'product_analytics.dart';
import 'telemetry_scrub.dart';

/// Crash (Sentry) + product analytics (PostHog) facade (RFC-043).
abstract final class Telemetry {
  /// Forja Flutter project DSN (public ingest). Override via `--dart-define=SENTRY_DSN=…`.
  static const String dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://c66602b941b166e5d5504774ab68c3fd@o4511773703143424.ingest.de.sentry.io/4511773713170512',
  );

  static bool _crashActive = false;
  static bool _hooksInstalled = false;

  static bool get isConfigured => dsn.isNotEmpty;

  static bool get isActive => _crashActive;

  static bool get isAnalyticsConfigured => ProductAnalytics.isConfigured;

  static bool get isAnalyticsActive => ProductAnalytics.isActive;

  /// Call after [Engine.init] so opt-in prefs are readable.
  static Future<void> ensureInitialized() async {
    await Future.wait([
      _ensureCrash(),
      ProductAnalytics.ensureInitialized(),
    ]);
  }

  static Future<void> setEnabled(bool enabled) async {
    await SettingsService().setCrashReportingEnabled(enabled);
    if (enabled) {
      await _startCrash();
    } else {
      await _stopCrash();
    }
  }

  static Future<void> setAnalyticsEnabled(bool enabled) =>
      ProductAnalytics.setEnabled(enabled);

  static Future<void> captureError(
    Object error, {
    StackTrace? stackTrace,
    String? hint,
  }) async {
    if (!_crashActive) return;
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: hint == null ? null : Hint.withMap({'forja_hint': hint}),
    );
  }

  /// Debug / QA: throw a known exception so Sentry receives a test event.
  static Future<void> sendTestException() async {
    if (!_crashActive) {
      throw StateError('Crash reporting is off - enable it in Settings first');
    }
    await captureError(
      StateError('Forja Sentry verify - test exception'),
      stackTrace: StackTrace.current,
      hint: 'settings_verify',
    );
  }

  /// Refresh PostHog person props / member identify (no-op when analytics off).
  static Future<void> syncAnalyticsIdentity() =>
      ProductAnalytics.syncMemberIdentity();

  /// Allowlisted product event → PostHog (not Sentry).
  static Future<void> track(
    String name, {
    Map<String, Object?>? properties,
  }) =>
      ProductAnalytics.track(name, properties: properties);

  static Future<void> captureEvent(
    String name, {
    Map<String, Object?>? data,
  }) =>
      track(name, properties: data);

  static Future<void> _ensureCrash() async {
    final enabled = await SettingsService().isCrashReportingEnabled();
    if (enabled) {
      await _startCrash();
    } else {
      await _stopCrash();
    }
  }

  static Future<void> _startCrash() async {
    if (!isConfigured) {
      debugPrint('[Telemetry] Crash reporting on but SENTRY_DSN empty - no-op');
      _crashActive = false;
      return;
    }
    if (_crashActive) return;

    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0;
      options.environment = kDebugMode ? 'debug' : 'release';
      options.beforeSend = scrubEvent;
      options.beforeBreadcrumb = scrubBreadcrumb;
    });

    _installHooks();
    _crashActive = true;
  }

  static Future<void> _stopCrash() async {
    if (!_crashActive) return;
    await Sentry.close();
    _crashActive = false;
  }

  static void _installHooks() {
    if (_hooksInstalled) return;
    _hooksInstalled = true;

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_crashActive) {
        Sentry.captureException(
          details.exception,
          stackTrace: details.stack,
        );
      }
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (_crashActive) {
        Sentry.captureException(error, stackTrace: stack);
      }
      return false;
    };
  }
}

/// Visible for tests - redact stream URLs, magnets, tokens.
SentryEvent? scrubEvent(SentryEvent event, Hint hint) {
  final exceptions = event.exceptions;
  List<SentryException>? scrubbedExceptions;
  if (exceptions != null) {
    scrubbedExceptions = [
      for (final ex in exceptions)
        ex.value == null ? ex : ex.copyWith(value: scrubText(ex.value!)),
    ];
  }

  SentryMessage? scrubbedMessage = event.message;
  final formatted = event.message?.formatted;
  if (formatted != null) {
    scrubbedMessage = SentryMessage(
      scrubText(formatted),
      template: event.message?.template,
      params: event.message?.params,
    );
  }

  SentryRequest? scrubbedRequest = event.request;
  if (event.request != null) {
    final req = event.request!;
    final headers = Map<String, String>.from(req.headers);
    headers.removeWhere((k, _) => sensitiveHeader(k));
    scrubbedRequest = req.copyWith(
      url: req.url == null ? null : scrubUrl(req.url!),
      headers: headers,
    );
  }

  return event.copyWith(
    exceptions: scrubbedExceptions,
    message: scrubbedMessage,
    request: scrubbedRequest,
  );
}

Breadcrumb? scrubBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) return null;
  final data = breadcrumb.data == null
      ? null
      : Map<String, dynamic>.from(breadcrumb.data!);
  if (data != null) {
    for (final key in data.keys.toList()) {
      final v = data[key];
      if (v is String) {
        data[key] = scrubText(v);
      }
      if (sensitiveHeader(key) || sensitiveKey(key)) {
        data[key] = '[redacted]';
      }
    }
  }
  return breadcrumb.copyWith(
    message:
        breadcrumb.message == null ? null : scrubText(breadcrumb.message!),
    data: data,
  );
}
