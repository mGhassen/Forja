import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Thin crash / event facade (RFC-043). No-ops unless opted in + DSN present.
abstract final class Telemetry {
  /// Forja Flutter project DSN (public ingest). Override via `--dart-define=SENTRY_DSN=…`.
  static const String dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://c66602b941b166e5d5504774ab68c3fd@o4511773703143424.ingest.de.sentry.io/4511773713170512',
  );

  static bool _active = false;
  static bool _hooksInstalled = false;

  static bool get isConfigured => dsn.isNotEmpty;

  static bool get isActive => _active;

  /// Call after [Engine.init] so the opt-in preference is readable.
  static Future<void> ensureInitialized() async {
    final enabled = await SettingsService().isCrashReportingEnabled();
    if (enabled) {
      await _start();
    } else {
      await _stop();
    }
  }

  /// Toggle from Settings. Persists via [SettingsService] first.
  static Future<void> setEnabled(bool enabled) async {
    await SettingsService().setCrashReportingEnabled(enabled);
    if (enabled) {
      await _start();
    } else {
      await _stop();
    }
  }

  static Future<void> captureError(
    Object error, {
    StackTrace? stackTrace,
    String? hint,
  }) async {
    if (!_active) return;
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: hint == null ? null : Hint.withMap({'forja_hint': hint}),
    );
  }

  /// Debug / QA: throw a known exception so Sentry receives a test event.
  static Future<void> sendTestException() async {
    if (!_active) {
      throw StateError('Crash reporting is off — enable it in Settings first');
    }
    await captureError(
      StateError('Forja Sentry verify — test exception'),
      stackTrace: StackTrace.current,
      hint: 'settings_verify',
    );
  }

  static Future<void> captureEvent(
    String name, {
    Map<String, Object?>? data,
  }) async {
    if (!_active) return;
    if (!_allowedEvents.contains(name)) return;
    await Sentry.captureMessage(
      name,
      withScope: (scope) {
        if (data != null) {
          for (final e in data.entries) {
            if (e.value != null) {
              scope.setTag(e.key, e.value.toString());
            }
          }
        }
      },
    );
  }

  static Future<void> _start() async {
    if (!isConfigured) {
      debugPrint('[Telemetry] Crash reporting on but SENTRY_DSN empty — no-op');
      _active = false;
      return;
    }
    if (_active) return;

    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0;
      options.environment = kDebugMode ? 'debug' : 'release';
      options.beforeSend = scrubEvent;
      options.beforeBreadcrumb = scrubBreadcrumb;
    });

    _installHooks();
    _active = true;
    unawaited(captureEvent('app_start'));
  }

  static Future<void> _stop() async {
    if (!_active) return;
    await Sentry.close();
    _active = false;
  }

  static void _installHooks() {
    if (_hooksInstalled) return;
    _hooksInstalled = true;

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_active) {
        Sentry.captureException(
          details.exception,
          stackTrace: details.stack,
        );
      }
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (_active) {
        Sentry.captureException(error, stackTrace: stack);
      }
      return false;
    };
  }

  static const Set<String> _allowedEvents = {
    'app_start',
    'resolve_failed',
    'player_open_failed',
    'provider_timeout',
    'update_check',
  };
}

/// Visible for tests — redact stream URLs, magnets, tokens.
SentryEvent? scrubEvent(SentryEvent event, Hint hint) {
  final exceptions = event.exceptions;
  List<SentryException>? scrubbedExceptions;
  if (exceptions != null) {
    scrubbedExceptions = [
      for (final ex in exceptions)
        ex.value == null
            ? ex
            : ex.copyWith(value: scrubText(ex.value!)),
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
    headers.removeWhere((k, _) => _sensitiveHeader(k));
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
      if (_sensitiveHeader(key) || _sensitiveKey(key)) {
        data[key] = '[redacted]';
      }
    }
  }
  return breadcrumb.copyWith(
    message: breadcrumb.message == null
        ? null
        : scrubText(breadcrumb.message!),
    data: data,
  );
}

String scrubText(String input) {
  var out = input;
  out = out.replaceAllMapped(
    RegExp(r'''magnet:\?[^\s"']+''', caseSensitive: false),
    (_) => 'magnet:[redacted]',
  );
  out = out.replaceAllMapped(
    RegExp(r'''https?://[^\s"']+''', caseSensitive: false),
    (m) => scrubUrl(m.group(0)!),
  );
  out = out.replaceAllMapped(
    RegExp(
      r'(authorization|cookie|token|api[_-]?key|password|jwt)\s*[:=]\s*\S.*',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}:[redacted]',
  );
  out = out.replaceAllMapped(
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    (_) => '[jwt-redacted]',
  );
  return out;
}

String scrubUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return '[url-redacted]';
  // Keep scheme + host only — drop path/query (often tokens / stream keys).
  if (uri.hasScheme && uri.host.isNotEmpty) {
    return '${uri.scheme}://${uri.host}/[redacted]';
  }
  return '[url-redacted]';
}

bool _sensitiveHeader(String key) {
  final k = key.toLowerCase();
  return k == 'authorization' ||
      k == 'cookie' ||
      k == 'set-cookie' ||
      k == 'x-api-key' ||
      k.contains('token');
}

bool _sensitiveKey(String key) {
  final k = key.toLowerCase();
  return k.contains('token') ||
      k.contains('password') ||
      k.contains('secret') ||
      k.contains('cookie') ||
      k.contains('magnet') ||
      k.contains('url');
}
