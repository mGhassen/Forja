import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/src/desktop_browser_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of starting an Android TV device-link session.
class TvDeviceLinkSession {
  const TvDeviceLinkSession({
    required this.userCode,
    required this.deviceCode,
    required this.interval,
    required this.expiresIn,
    required this.verificationUri,
    required this.verificationUriComplete,
  });

  final String userCode;
  final String deviceCode;
  final int interval;
  final int expiresIn;
  final String verificationUri;
  final String verificationUriComplete;
}

enum TvDeviceLinkPollStatus { pending, approved, expired, denied, error }

class TvDeviceLinkPollResult {
  const TvDeviceLinkPollResult._({
    required this.status,
    this.accessToken,
    this.refreshToken,
    this.error,
  });

  factory TvDeviceLinkPollResult.pending() =>
      const TvDeviceLinkPollResult._(status: TvDeviceLinkPollStatus.pending);

  factory TvDeviceLinkPollResult.approved({
    required String accessToken,
    required String refreshToken,
  }) =>
      TvDeviceLinkPollResult._(
        status: TvDeviceLinkPollStatus.approved,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

  factory TvDeviceLinkPollResult.expired() =>
      const TvDeviceLinkPollResult._(status: TvDeviceLinkPollStatus.expired);

  factory TvDeviceLinkPollResult.denied() =>
      const TvDeviceLinkPollResult._(status: TvDeviceLinkPollStatus.denied);

  factory TvDeviceLinkPollResult.error(String message) =>
      TvDeviceLinkPollResult._(
        status: TvDeviceLinkPollStatus.error,
        error: message,
      );

  final TvDeviceLinkPollStatus status;
  final String? accessToken;
  final String? refreshToken;
  final String? error;
}

/// Edge create / poll for Android TV → portal `/connect` linking.
class TvDeviceLinkAuth {
  TvDeviceLinkAuth._();

  /// Portal origin used for QR / on-screen URL (same define as desktop Web login).
  static String get webUrl => DesktopBrowserAuth.webUrl;

  static Future<TvDeviceLinkSession> create() async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }

    try {
      final response = await client.functions.invoke(
        'create-device-link',
        body: <String, dynamic>{},
      );
      return _sessionFromData(response.data);
    } on FunctionException catch (e) {
      final message = _errorFromDetails(e.details) ??
          'Could not start TV linking (${e.status}).';
      debugPrint('[TvDeviceLink] create FunctionException status=${e.status} $message');
      throw AuthException(message);
    } catch (e, st) {
      debugPrint('[TvDeviceLink] create error: $e\n$st');
      rethrow;
    }
  }

  static Future<TvDeviceLinkPollResult> poll(String deviceCode) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      return TvDeviceLinkPollResult.error(
        'Supabase is not configured for this build.',
      );
    }

    try {
      final response = await client.functions.invoke(
        'poll-device-link',
        body: <String, dynamic>{'device_code': deviceCode},
      );
      return _pollFromData(response.status, response.data);
    } on FunctionException catch (e) {
      return _pollFromData(e.status, e.details);
    } catch (e, st) {
      debugPrint('[TvDeviceLink] poll error: $e\n$st');
      return TvDeviceLinkPollResult.error(e.toString());
    }
  }

  static TvDeviceLinkSession _sessionFromData(dynamic raw) {
    final data = _asMap(raw);
    final userCode = (data['user_code'] as String?)?.trim() ?? '';
    final deviceCode = (data['device_code'] as String?)?.trim() ?? '';
    if (userCode.isEmpty || deviceCode.isEmpty) {
      throw const AuthException('TV linking did not return a usable code.');
    }

    final verificationUri = '$webUrl/connect';
    final verificationUriComplete = '$verificationUri?code=$userCode';

    return TvDeviceLinkSession(
      userCode: userCode,
      deviceCode: deviceCode,
      interval: (data['interval'] as num?)?.toInt() ?? 5,
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 600,
      verificationUri: verificationUri,
      verificationUriComplete: verificationUriComplete,
    );
  }

  static TvDeviceLinkPollResult _pollFromData(int status, dynamic raw) {
    final data = _asMap(raw);
    final linkStatus = (data['status'] as String?)?.toLowerCase() ?? '';

    if (status == 202 || linkStatus == 'pending') {
      return TvDeviceLinkPollResult.pending();
    }
    if (status == 410 || linkStatus == 'expired') {
      return TvDeviceLinkPollResult.expired();
    }
    if (status == 403 || linkStatus == 'denied') {
      return TvDeviceLinkPollResult.denied();
    }
    if (status == 409 || linkStatus == 'consumed') {
      return TvDeviceLinkPollResult.error(
        'This code was already used. Start again.',
      );
    }
    if (status >= 400) {
      return TvDeviceLinkPollResult.error(
        _errorFromDetails(raw) ?? 'TV linking failed ($status).',
      );
    }

    final access = (data['access_token'] as String?)?.trim() ?? '';
    final refresh = (data['refresh_token'] as String?)?.trim() ?? '';
    if (access.isEmpty || refresh.isEmpty) {
      return TvDeviceLinkPollResult.error(
        _errorFromDetails(raw) ?? 'TV linking did not return a session.',
      );
    }
    return TvDeviceLinkPollResult.approved(
      accessToken: access,
      refreshToken: refresh,
    );
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  static String? _errorFromDetails(dynamic data) {
    final map = _asMap(data);
    final error = map['error'];
    if (error is String && error.trim().isNotEmpty) return error.trim();
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return null;
  }
}
