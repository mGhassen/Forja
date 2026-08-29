import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/src/account_features.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:rust/rust.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_runtime_props.dart';
import 'telemetry_scrub.dart';

/// PostHog product analytics (RFC-043).
///
/// Opt-in via Settings. Allowlisted events only — session replay off.
/// When signed in, [identify] uses `accounts.id` (= auth user id) and sets
/// person props: member_number (opaque ops id), app_version, platform,
/// os_version, arch, last_seen_at. Never email.
abstract final class ProductAnalytics {
  static const String apiKey = String.fromEnvironment('POSTHOG_API_KEY');

  static const String _hostDefine = String.fromEnvironment('POSTHOG_HOST');

  /// US cloud by default; set `POSTHOG_HOST=https://eu.i.posthog.com` for EU.
  static String get host => _hostDefine.isEmpty
      ? 'https://us.i.posthog.com'
      : _hostDefine;

  static bool _active = false;
  static StreamSubscription<AuthState>? _authSub;
  static String? _identifiedUserId;

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

  /// Refresh person props (and re-identify if signed in). Safe no-op when off.
  static Future<void> syncMemberIdentity() async {
    if (!_active) return;
    await _syncIdentity();
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
        // Person email is never sent (use member_number on identify).
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
    await _syncIdentity();
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
    if (_active) {
      await _syncIdentity();
      return;
    }

    final config = PostHogConfig(apiKey)
      ..host = host
      ..debug = kDebugMode
      ..captureApplicationLifecycleEvents = true
      ..sessionReplay = false
      ..beforeSend = [_beforeSend];

    await Posthog().setup(config);
    _active = true;
    _ensureAuthListener();
    unawaited(track('app_start'));
    unawaited(_syncIdentity());
  }

  static Future<void> _stop() async {
    await _authSub?.cancel();
    _authSub = null;
    _identifiedUserId = null;
    if (!_active) return;
    try {
      await Posthog().reset();
      await Posthog().disable();
      await Posthog().close();
    } catch (_) {}
    _active = false;
  }

  static void _ensureAuthListener() {
    if (_authSub != null) return;
    _authSub = SyncService.instance.authChanges.listen((_) {
      unawaited(_syncIdentity());
    });
  }

  static Future<void> _syncIdentity() async {
    if (!_active) return;
    try {
      final props = await ClientRuntimeProps.collect();
      final session = SyncService.instance.session;
      final userId = session?.user.id.trim();
      if (userId != null && userId.isNotEmpty) {
        final memberNumber = await _resolveMemberNumber(userId);
        if (memberNumber != null) {
          props['member_number'] = memberNumber;
        }
        await Posthog().identify(
          userId: userId,
          userProperties: props,
        );
        _identifiedUserId = userId;
        return;
      }
      if (_identifiedUserId != null) {
        await Posthog().reset();
        _identifiedUserId = null;
        // Re-apply runtime props on the fresh anonymous distinct id.
        await Posthog().setPersonProperties(userPropertiesToSet: props);
        return;
      }
      await Posthog().setPersonProperties(userPropertiesToSet: props);
    } catch (e) {
      debugPrint('[ProductAnalytics] sync identity failed: $e');
    }
  }

  static Future<int?> _resolveMemberNumber(String userId) async {
    final cached = AccountFeatures.instance.memberNumber;
    if (cached != null) return cached;
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return null;
    try {
      final row = await client
          .from('accounts')
          .select('member_number')
          .eq('id', userId)
          .maybeSingle();
      final n = switch (row?['member_number']) {
        int v => v,
        num v => v.toInt(),
        String s => int.tryParse(s),
        _ => null,
      };
      if (n != null) {
        AccountFeatures.instance.setMemberNumber(n);
      }
      return n;
    } catch (_) {
      return null;
    }
  }

  static PostHogEvent? _beforeSend(PostHogEvent event) {
    final props = event.properties;
    if (props == null) return event;
    _scrubPropertyMap(props);
    return event;
  }

  /// Scrub event props + nested `$set` / `$set_once` (identify person bags).
  static void _scrubPropertyMap(Map<String, Object> props) {
    for (final key in props.keys.toList()) {
      if (_sensitivePropertyKey(key)) {
        props.remove(key);
        continue;
      }
      final v = props[key];
      if (v is Map) {
        final nested = Map<String, Object>.from(
          v.map((k, val) => MapEntry(k.toString(), val as Object)),
        );
        _scrubPropertyMap(nested);
        props[key] = nested;
        continue;
      }
      if (v is String && !_isPersonEmailKey(key)) {
        props[key] = scrubText(v);
      }
    }
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

  /// Person email keys stay blocked everywhere (GDPR — use member_number).
  static bool _isPersonEmailKey(String key) {
    final k = key.toLowerCase();
    return k == 'email' || k == r'$email';
  }

  static bool _sensitivePropertyKey(String key) {
    if (_isPersonEmailKey(key)) return true;
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
